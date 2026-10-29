import 'package:flutter/foundation.dart';

import '../logic/change_factory.dart';
import '../models/change_event.dart';
import '../models/schedule_snapshot.dart';
import '../models/scheduled_event.dart';
import '../models/visual_ref.dart';
import '../time/time_format.dart';
import 'schedule_repository.dart';

/// Single source of truth for schedules: published versions, staff drafts,
/// published changes and per-participant acknowledgements.
///
/// * Staff edits go into [drafts] and are invisible to participants.
/// * [publish] creates a new [ScheduleSnapshot] version and a [ChangeEvent].
/// * Participants keep seeing their last acknowledged version until they
///   confirm a change that affects them ([displayedSnapshotFor]).
class ScheduleStore extends ChangeNotifier {
  final ScheduleRepository repository;
  final List<ScheduleSnapshot> _history;
  final List<ChangeEvent> _changes;
  final Map<String, ScheduledEvent> _drafts = {};
  final Map<String, int> _acknowledgedVersion = {};
  int _idCounter = 0;

  ScheduleStore({
    required this.repository,
    required ScheduleSnapshot initial,
    List<ChangeEvent> changes = const [],
    Map<String, int> acknowledgedVersions = const {},
  })  : _history = [initial],
        _changes = [...changes] {
    _acknowledgedVersion.addAll(acknowledgedVersions);
  }

  // ---------------------------------------------------------------- reading

  ScheduleSnapshot get published => _history.last;
  int get version => published.version;
  List<ChangeEvent> get changes => List.unmodifiable(_changes);
  Map<String, ScheduledEvent> get drafts => Map.unmodifiable(_drafts);

  bool hasDraft(String eventId) => _drafts.containsKey(eventId);

  ScheduleSnapshot snapshotAt(int version) =>
      _history.firstWhere((s) => s.version == version,
          orElse: () => _history.first);

  /// Published events merged with drafts, for the staff calendar.
  List<ScheduledEvent> staffEventsOn(DateTime day) {
    return published.applying(_drafts.values).eventsOn(day);
  }

  ScheduledEvent? staffEvent(String id) => _drafts[id] ?? published[id];

  List<ChangeEvent> changesOn(DateTime day) => _changes
      .where((c) => c.eventChanges.any((ec) => ec.after?.occursOn(day) ?? false))
      .toList();

  String newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  // ---------------------------------------------------------- participants

  int acknowledgedVersionFor(String participantId) =>
      _acknowledgedVersion[participantId] ?? version;

  /// Published changes this participant has not acknowledged yet.
  List<ChangeEvent> pendingChangesFor(String participantId) {
    final acked = acknowledgedVersionFor(participantId);
    return _changes
        .where((c) => c.version > acked && c.affects(participantId))
        .toList();
  }

  /// The version a participant currently sees. If a relevant change is
  /// waiting for acknowledgement, the feed stays on the previous version so
  /// cards never rearrange unexpectedly.
  ScheduleSnapshot displayedSnapshotFor(String participantId) {
    if (pendingChangesFor(participantId).isEmpty) return published;
    return snapshotAt(acknowledgedVersionFor(participantId));
  }

  /// Changes affecting [participantId] that were published for [day].
  List<ChangeEvent> participantChangesOn(String participantId, DateTime day) =>
      changesOn(day).where((c) => c.affects(participantId)).toList();

  void acknowledge(String participantId) {
    _acknowledgedVersion[participantId] = version;
    notifyListeners();
  }

  /// Participants with at least one unacknowledged change.
  Set<String> participantsWithPendingChanges(Iterable<String> ids) =>
      {for (final id in ids) if (pendingChangesFor(id).isNotEmpty) id};

  // ----------------------------------------------------------------- staff

  void saveDraft(ScheduledEvent event) {
    _drafts[event.id] = event;
    notifyListeners();
  }

  void saveDrafts(Iterable<ScheduledEvent> events) {
    for (final e in events) {
      _drafts[e.id] = e;
    }
    notifyListeners();
  }

  void discardDraft(String eventId) {
    if (_drafts.remove(eventId) != null) notifyListeners();
  }

  /// Publishes [upserts] as one change. Returns the recorded change, or null
  /// if nothing actually changed.
  ChangeEvent? publish({
    required List<ScheduledEvent> upserts,
    required String publishedBy,
    ChangeOutcome outcome = ChangeOutcome.none,
    String? cancelledEventId,
    bool persist = true,
  }) {
    final base = published;
    final now = DateTime.now();
    final change = ChangeFactory.create(
      id: newId('change'),
      base: base,
      upserts: upserts,
      version: base.version + 1,
      publishedAt: now,
      publishedBy: publishedBy,
      outcome: outcome,
      cancelledEventId: cancelledEventId,
    );
    for (final e in upserts) {
      _drafts.remove(e.id);
    }
    if (change.eventChanges.isEmpty) {
      notifyListeners();
      return null;
    }

    // Participants not affected by this change move to the new version
    // silently; affected participants keep their acknowledged version.
    for (final pid in _acknowledgedVersion.keys.toList()) {
      if (!change.affects(pid) && pendingChangesFor(pid).isEmpty) {
        _acknowledgedVersion[pid] = change.version;
      }
    }
    // Anyone without an explicit acknowledgement so far is pinned to the
    // base version so they see the change notice too.
    for (final pid in change.affectedParticipantIds) {
      _acknowledgedVersion.putIfAbsent(pid, () => base.version);
    }

    final next = base.applying(
      upserts,
      version: change.version,
      publishedAt: now,
    );
    _history.add(next);
    _changes.add(change);
    if (persist) repository.savePublished(next);
    notifyListeners();
    return change;
  }

  /// Publishes activities a participant added to their own free time.
  ///
  /// The participant made this change themselves, so it never triggers a
  /// "Your plan has changed" notice for them (unless staff changes are
  /// already waiting, which they still need to see first).
  ChangeEvent? addParticipantEvents({
    required String participantId,
    required String participantName,
    required List<ScheduledEvent> events,
  }) {
    final wasUpToDate = pendingChangesFor(participantId).isEmpty;
    final change = publish(
      upserts: [
        for (final e in events)
          e.copyWith(assignedParticipantIds: {participantId}),
      ],
      publishedBy: '$participantName (self)',
    );
    if (change != null && wasUpToDate) acknowledge(participantId);
    return change;
  }

  // ---------------------------------------------------------------- remote

  /// Replaces everything with server state (after login / logout). Nothing
  /// is shown as a change; drafts are those stored on the server.
  void replaceAll(
    Iterable<ScheduledEvent> published, {
    Iterable<ScheduledEvent> drafts = const [],
  }) {
    final next = ScheduleSnapshot(
      version: version + 1,
      publishedAt: DateTime.now(),
      events: Map.unmodifiable({for (final e in published) e.id: e}),
    );
    _history
      ..clear()
      ..add(next);
    _changes.clear();
    _acknowledgedVersion.clear();
    _drafts
      ..clear()
      ..addAll({for (final e in drafts) e.id: e});
    notifyListeners();
  }

  /// Applies a newer server state as a regular published change, so
  /// participants get the same "plan changed" flow as for local publishes.
  /// [window] limits which local events are compared (the loaded date range);
  /// active events missing from [remote] count as cancelled.
  ChangeEvent? applyRemote(
    Iterable<ScheduledEvent> remote, {
    required bool Function(ScheduledEvent) window,
    String publishedBy = 'Staff',
  }) {
    final byId = {for (final e in remote) e.id: e};
    final upserts = <ScheduledEvent>[
      for (final e in byId.values)
        if (ChangeFactory.diff(published[e.id], e).isNotEmpty) e,
      for (final e in published.events.values)
        if (e.isActive && window(e) && !byId.containsKey(e.id))
          e.copyWith(status: EventStatus.cancelled),
    ];
    // Picture-only updates (new photo, refreshed photo link) are applied
    // silently: they are not a schedule change for the participant.
    final visualOnly = [
      for (final e in byId.values)
        if (published[e.id] case final before?)
          if (ChangeFactory.diff(before, e).isEmpty &&
              !_sameVisual(before.visual, e.visual))
            before.copyWith(visual: e.visual),
    ];
    if (visualOnly.isNotEmpty) {
      _history.add(published.applying(visualOnly, version: version + 1));
      if (upserts.isEmpty) notifyListeners();
    }
    if (upserts.isEmpty) return null;
    return publish(upserts: upserts, publishedBy: publishedBy, persist: false);
  }

  static bool _sameVisual(VisualRef a, VisualRef b) =>
      a.symbol == b.symbol &&
      a.pictogramUrl == b.pictogramUrl &&
      a.photoUrl == b.photoUrl &&
      identical(a.photoBytes, b.photoBytes);

  /// Replaces only the visual of a published event (e.g. a new photo).
  /// Not a schedule change: participants get no notice and nothing moves.
  void setPublishedVisual(String eventId, VisualRef visual) {
    final before = published[eventId];
    if (before == null) return;
    _history.add(published.applying(
      [before.copyWith(visual: visual)],
      version: version + 1,
    ));
    notifyListeners();
  }

  /// Publishes all current drafts on [day] (or every draft if null).
  ChangeEvent? publishDrafts({required String publishedBy, DateTime? day}) {
    final selected = _drafts.values
        .where((e) => day == null || TimeFormat.sameDay(e.start, day))
        .toList();
    if (selected.isEmpty) return null;
    return publish(upserts: selected, publishedBy: publishedBy);
  }
}
