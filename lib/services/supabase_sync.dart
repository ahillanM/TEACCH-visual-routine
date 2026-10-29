import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/activity_category.dart';
import '../core/models/app_user.dart';
import '../core/models/participant.dart';
import '../core/models/schedule_snapshot.dart';
import '../core/models/scheduled_event.dart';
import '../core/models/support_request.dart';
import '../core/models/visual_ref.dart';
import '../core/state/library_store.dart';
import '../core/state/participant_directory.dart';
import '../core/state/progress_store.dart';
import '../core/state/schedule_repository.dart';
import '../core/state/schedule_store.dart';
import '../core/state/support_request_store.dart';
import '../core/time/time_format.dart';

/// Bridges the planner's in-memory stores and the Supabase backend.
///
/// The UI keeps one [ScheduledEvent] per organisational event (possibly shared
/// by several participants). The database stores one schedule per participant
/// and day. This class translates between the two:
///
/// * read: schedules + activities (RLS decides what the user may see), grouped
///   back into events by `activities.meta.eventId`;
/// * write (staff publish): every changed participant/day is replaced through
///   `save_schedule(..., p_publish: true)`, after `unpublish_schedule` if it
///   was already published;
/// * Realtime: any change to schedules, activities or support requests that
///   the user may see triggers a reload.
///
/// Authorisation is enforced by Postgres; nothing here is trusted.
class SupabaseSync implements ScheduleRepository {
  final SupabaseClient db;
  final ParticipantDirectory participants;
  final SupabaseSupportStore support;
  final SupabaseProgressStore progress;
  final LibraryStore library;

  /// Last error to show to the user (null = none). Cleared by the UI.
  final ValueNotifier<String?> errors = ValueNotifier(null);

  static const _daysBack = 7;
  static const _daysAhead = 21;

  late final ScheduleStore _store;
  AppUser? _user;
  RealtimeChannel? _channel;
  Timer? _debounce;
  Future<void> _queue = Future.value();

  /// Server schedule rows by "participantId/yyyy-mm-dd".
  final Map<String, ({String id, String status})> _schedules = {};

  /// Signature of each published participant/day on the server, to detect
  /// which groups a publish actually changed.
  final Map<String, String> _serverGroups = {};

  SupabaseSync({
    required this.db,
    required this.participants,
    required this.support,
    required this.progress,
    required this.library,
  });

  void attach(ScheduleStore store) => _store = store;

  /// Completes when queued writes and reloads have finished.
  Future<void> get idle => _queue;

  /// Fetches the latest server state now (Realtime does this automatically).
  Future<void> refresh() =>
      _queue = _queue.then((_) => _reload()).then((_) => support.reload());

  bool get _isStaff => _user != null && _user!.role != Role.participant;

  // -------------------------------------------------------------- session

  Future<void> start(AppUser user) async {
    _user = user;
    support.user = user;
    progress.activityIdFor = (eventId, pid) => _activityIds['$pid/$eventId'];
    progress.onError = _report;
    support.onError = _report;
    await _loadParticipants();
    await _reload(initial: true);
    await support.reload();
    _subscribe();
  }

  Future<void> stop() async {
    _debounce?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) await db.removeChannel(channel);
    _user = null;
    support.user = null;
    _schedules.clear();
    _serverGroups.clear();
    _activityIds.clear();
    _store.replaceAll(const []);
    participants.replaceAll(const []);
    support.replaceAll(const []);
    progress.replaceAll(const []);
  }

  void _subscribe() {
    void onChange(PostgresChangePayload _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        refresh();
      });
    }

    var channel = db.channel('planner-${_user!.id}');
    for (final table in ['schedules', 'activities', 'support_requests']) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: onChange,
      );
    }
    _channel = channel.subscribe();
  }

  Future<void> _loadParticipants() async {
    final user = _user!;
    final List<Map<String, dynamic>> rows;
    if (_isStaff) {
      final links = await db
          .from('staff_participants')
          .select('participant:profiles!participant_id(id, display_name)');
      rows = [for (final l in links) l['participant'] as Map<String, dynamic>];
    } else {
      rows = await db
          .from('profiles')
          .select('id, display_name')
          .eq('id', user.id);
    }
    participants.replaceAll([
      for (final r in rows)
        Participant(
          id: r['id'] as String,
          displayName: shortName(r['display_name'] as String),
          livingGroup: '',
        ),
    ]);
  }

  /// "Lukas (demo participant)" → "Lukas".
  static String shortName(String name) {
    final i = name.indexOf(' (');
    return i > 0 ? name.substring(0, i) : name;
  }

  // ----------------------------------------------------------------- read

  final Map<String, String> _activityIds = {};

  bool _inWindow(DateTime day) {
    final today = TimeFormat.dateOnly(DateTime.now());
    final d = TimeFormat.dateOnly(day);
    return !d.isBefore(today.subtract(const Duration(days: _daysBack))) &&
        !d.isAfter(today.add(const Duration(days: _daysAhead)));
  }

  Future<void> _reload({bool initial = false}) async {
    if (_user == null) return;
    final today = TimeFormat.dateOnly(DateTime.now());
    final List<Map<String, dynamic>> rows;
    try {
      rows = await db
          .from('schedules')
          .select(
            'id, participant_id, schedule_date, status, '
            'activities(id, title, description, start_time, end_time, status, '
            'icon_key, category, pictogram_url, location, staff_name, meta)',
          )
          .gte(
            'schedule_date',
            _date(today.subtract(const Duration(days: _daysBack))),
          )
          .lte(
            'schedule_date',
            _date(today.add(const Duration(days: _daysAhead))),
          );
    } catch (e) {
      _report(e);
      return;
    }

    final known = participants.byId.keys.toSet();
    final published = <String, ScheduledEvent>{};
    final drafts = <String, ScheduledEvent>{};
    final done = <(String, String)>[];
    _schedules.clear();
    _serverGroups.clear();
    _activityIds.clear();

    for (final row in rows) {
      final pid = row['participant_id'] as String;
      if (!known.contains(pid)) continue;
      final dateStr = row['schedule_date'] as String;
      final day = DateTime.parse(dateStr);
      final status = row['status'] as String;
      final key = '$pid/$dateStr';
      _schedules[key] = (id: row['id'] as String, status: status);
      final target = status == 'published' ? published : drafts;
      final groupEvents = <ScheduledEvent>[];

      final acts = (row['activities'] as List).cast<Map<String, dynamic>>();
      for (final a in acts) {
        final event = _fromRow(a, day, pid);
        if (event == null) continue;
        final id = _merge(target, event, pid);
        groupEvents.add(target[id]!);
        if (status == 'published') {
          _activityIds['$pid/$id'] = a['id'] as String;
          if (a['status'] == 'completed') done.add((id, pid));
        }
      }
      if (status == 'published') _serverGroups[key] = _signature(groupEvents);
    }

    progress.replaceAll(done);
    if (initial) {
      _store.replaceAll(published.values, drafts: drafts.values);
    } else {
      _store.applyRemote(published.values, window: (e) => _inWindow(e.start));
    }
  }

  /// Adds [event] to [target], merging copies of a shared event. Returns the
  /// id it was stored under.
  static String _merge(
    Map<String, ScheduledEvent> target,
    ScheduledEvent event,
    String pid,
  ) {
    final existing = target[event.id];
    if (existing == null) {
      target[event.id] = event;
      return event.id;
    }
    if (existing.start == event.start &&
        existing.end == event.end &&
        existing.title == event.title) {
      target[event.id] = existing.copyWith(
        assignedParticipantIds: {...existing.assignedParticipantIds, pid},
      );
      return event.id;
    }
    // Same event edited differently per participant: keep them apart.
    final id = '${event.id}~$pid';
    target[id] = event.copyWith(id: id);
    return id;
  }

  ScheduledEvent? _fromRow(Map<String, dynamic> a, DateTime day, String pid) {
    final startStr = a['start_time'] as String?;
    if (startStr == null) return null; // the timeline needs a start time
    final meta = (a['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final start = _at(day, startStr);
    final endStr = a['end_time'] as String?;
    final end = endStr == null
        ? start.add(Duration(minutes: (meta['durationMin'] as int?) ?? 30))
        : _at(day, endStr);
    final location = a['location'] as String?;
    final staffName = a['staff_name'] as String?;
    return ScheduledEvent(
      id: (meta['eventId'] as String?) ?? 'db-${a['id']}',
      title: a['title'] as String,
      category:
          _byName(ActivityCategory.values, meta['category']) ??
          ActivityCategory.fromLegacyCode((a['category'] as String?) ?? ''),
      kind: _byName(EventKind.values, meta['kind']) ?? EventKind.activity,
      start: start,
      end: end,
      visual: VisualRef(
        symbol: (a['icon_key'] as String?) ?? 'event',
        pictogramUrl: a['pictogram_url'] as String?,
        photoUrl: meta['photoUrl'] as String?,
      ),
      placeId:
          (meta['placeId'] as String?) ??
          library.places.where((p) => p.name == location).firstOrNull?.id,
      contactId:
          (meta['contactId'] as String?) ??
          library.contacts.where((c) => c.name == staffName).firstOrNull?.id,
      whatToBring: ((meta['whatToBring'] as List?) ?? const [])
          .cast<String>()
          .toList(),
      instructions: a['description'] as String?,
      assignedParticipantIds: {pid},
      libraryActivityId: meta['libraryActivityId'] as String?,
      planBActivityId: meta['planBActivityId'] as String?,
      reminderMinutesBefore: meta['reminderMinutesBefore'] as int?,
      replacesEventId: meta['replacesEventId'] as String?,
    );
  }

  // ---------------------------------------------------------------- write

  @override
  Future<ScheduleSnapshot?> loadPublished() async => null;

  /// Called by [ScheduleStore.publish]. Writes every participant/day whose
  /// active events differ from the server, then reloads.
  @override
  Future<void> savePublished(ScheduleSnapshot snapshot) {
    if (!_isStaff) return Future.value();
    final groups = <String, List<ScheduledEvent>>{};
    final known = participants.byId.keys.toSet();
    for (final e in snapshot.events.values) {
      if (!e.isActive) continue;
      for (final pid in e.assignedParticipantIds.intersection(known)) {
        groups.putIfAbsent('$pid/${_date(e.start)}', () => []).add(e);
      }
    }
    // Days that had published activities and now have none.
    for (final key in _serverGroups.keys) {
      groups.putIfAbsent(key, () => []);
    }

    final changed = <String, List<ScheduledEvent>>{
      for (final entry in groups.entries)
        if (_signature(entry.value) !=
            (_serverGroups[entry.key] ?? _signature(const [])))
          entry.key: entry.value,
    };
    if (changed.isEmpty) return _queue;

    _queue = _queue.then((_) async {
      for (final entry in changed.entries) {
        await _writeGroup(entry.key, entry.value);
      }
      await _reload();
    });
    return _queue;
  }

  Future<void> _writeGroup(String key, List<ScheduledEvent> events) async {
    final slash = key.indexOf('/');
    final pid = key.substring(0, slash);
    final dateStr = key.substring(slash + 1);
    final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i + 1 < sorted.length; i++) {
      if (sorted[i].end.isAfter(sorted[i + 1].start)) {
        errors.value =
            'Not published for ${participants.nameOf(pid)} on $dateStr: '
            '"${sorted[i].title}" overlaps "${sorted[i + 1].title}".';
        return;
      }
    }
    try {
      final existing = _schedules[key];
      if (existing?.status == 'published') {
        await db.rpc(
          'unpublish_schedule',
          params: {'p_schedule_id': existing!.id},
        );
      }
      await db.rpc(
        'save_schedule',
        params: {
          'p_participant_id': pid,
          'p_schedule_date': dateStr,
          'p_activities': [for (final e in sorted) _toItem(e)],
          'p_publish': sorted.isNotEmpty,
        },
      );
    } catch (e) {
      _report(e);
    }
  }

  Map<String, dynamic> _toItem(ScheduledEvent e) {
    final symbol = e.visual.symbol;
    return {
      'title': e.title,
      'description': e.instructions,
      'startTime': _hm(e.start),
      'endTime': _hm(e.end),
      'category': e.category.legacyCode,
      'iconKey': symbol.length > 40 ? symbol.substring(0, 40) : symbol,
      'pictogramUrl': e.visual.pictogramUrl ?? '',
      'location': library.place(e.placeId)?.name ?? '',
      'staffName': library.contact(e.contactId)?.name ?? '',
      'meta': {
        'eventId': e.id,
        'kind': e.kind.name,
        'category': e.category.name,
        if (e.placeId != null) 'placeId': e.placeId,
        if (e.contactId != null) 'contactId': e.contactId,
        if (e.libraryActivityId != null)
          'libraryActivityId': e.libraryActivityId,
        if (e.planBActivityId != null) 'planBActivityId': e.planBActivityId,
        if (e.replacesEventId != null) 'replacesEventId': e.replacesEventId,
        if (e.reminderMinutesBefore != null)
          'reminderMinutesBefore': e.reminderMinutesBefore,
        if (e.visual.photoUrl != null) 'photoUrl': e.visual.photoUrl,
        if (e.whatToBring.isNotEmpty) 'whatToBring': e.whatToBring,
      },
    };
  }

  String _signature(List<ScheduledEvent> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return jsonEncode([for (final e in sorted) _toItem(e)]);
  }

  void _report(Object e) {
    debugPrint('Supabase sync error: ${e.runtimeType}');
    errors.value = describeError(e);
  }

  static String describeError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501') return 'You are not allowed to do that.';
      if (e.code == 'PT404') return 'That item no longer exists.';
      if (e.message.contains('overlapping')) {
        return 'Activities overlap. Please fix the times and publish again.';
      }
      if (e.message.contains('empty_schedule')) return 'The schedule is empty.';
      return 'The server rejected the change (${e.code}).';
    }
    return 'No connection to the server. Please try again.';
  }

  // -------------------------------------------------------------- helpers

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  static DateTime _at(DateTime day, String hhmmss) {
    final parts = hhmmss.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) =>
      name is String ? values.where((v) => v.name == name).firstOrNull : null;
}

/// Activity completion through the `complete_activity` RPC (participants only).
class SupabaseProgressStore extends ProgressStore {
  final SupabaseClient db;
  String? Function(String eventId, String participantId)? activityIdFor;
  void Function(Object error)? onError;

  SupabaseProgressStore(this.db);

  @override
  Future<void> setDone(String eventId, String participantId, bool done) async {
    final activityId = activityIdFor?.call(eventId, participantId);
    if (activityId == null) return;
    await super.setDone(eventId, participantId, done);
    try {
      await db.rpc(
        'complete_activity',
        params: {'p_activity_id': activityId, 'p_done': done},
      );
    } catch (e) {
      await super.setDone(eventId, participantId, !done);
      onError?.call(e);
    }
  }
}

/// Support requests stored in `support_requests`. Participants insert their
/// own (the server sets participant_id); staff resolve via RPC.
class SupabaseSupportStore extends SupportRequestStore {
  final SupabaseClient db;
  AppUser? user;
  void Function(Object error)? onError;

  /// "Acknowledged" has no server column; it is kept on this device only.
  final Set<String> _acknowledged = {};

  SupabaseSupportStore(this.db);

  static const _types = {
    SupportReason.dontKnowWhereToGo: 'help',
    SupportReason.dontUnderstand: 'help',
    SupportReason.scheduleWrong: 'change',
    SupportReason.needSupport: 'help',
  };

  Future<void> reload() async {
    if (user == null) return;
    try {
      final rows = await db
          .from('support_requests')
          .select('id, participant_id, request_type, note, status, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      replaceAll([
        for (final r in rows)
          SupportRequest(
            id: r['id'] as String,
            participantId: r['participant_id'] as String,
            reason: _reasonOf(r),
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            currentActivityTitle: _titleOf(r['note'] as String?),
            status: r['status'] == 'resolved'
                ? SupportStatus.resolved
                : _acknowledged.contains(r['id'])
                ? SupportStatus.acknowledged
                : SupportStatus.open,
          ),
      ]);
    } catch (e) {
      onError?.call(e);
    }
  }

  /// Note format: `reasonName|currentActivityTitle`.
  static SupportReason _reasonOf(Map<String, dynamic> r) {
    final note = (r['note'] as String?) ?? '';
    final name = note.split('|').first;
    return SupportReason.values.where((v) => v.name == name).firstOrNull ??
        (r['request_type'] == 'change'
            ? SupportReason.scheduleWrong
            : SupportReason.needSupport);
  }

  static String? _titleOf(String? note) {
    if (note == null || !note.contains('|')) return null;
    final title = note.substring(note.indexOf('|') + 1);
    return title.isEmpty ? null : title;
  }

  @override
  SupportRequest create({
    required String participantId,
    required SupportReason reason,
    required DateTime at,
    String? currentActivityTitle,
  }) {
    final local = super.create(
      participantId: participantId,
      reason: reason,
      at: at,
      currentActivityTitle: currentActivityTitle,
    );
    final note = '${reason.name}|${currentActivityTitle ?? ''}';
    db
        .from('support_requests')
        .insert({
          'request_type': _types[reason],
          'note': note.length > 500 ? note.substring(0, 500) : note,
        })
        .then((_) => reload())
        .catchError((Object e) => onError?.call(e));
    return local;
  }

  @override
  void setStatus(String id, SupportStatus status) {
    super.setStatus(id, status);
    if (status == SupportStatus.acknowledged) _acknowledged.add(id);
    if (status != SupportStatus.resolved) return;
    db
        .rpc('resolve_support_request', params: {'p_request_id': id})
        .then((_) => reload())
        .catchError((Object e) {
          onError?.call(e);
          reload();
        });
  }
}
