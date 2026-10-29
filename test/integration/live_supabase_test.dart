// LIVE end-to-end test against the hackathon Supabase project and the local
// FastAPI AI backend. It drives the real app services (auth, sync, stores,
// AI generator) with two to three concurrent sessions, without widgets.
//
// Needs: supabase/.demo-credentials.local (gitignored) or
// --dart-define=DEMO_PASSWORD=..., and for the AI part a running backend
// (AI_BACKEND_URL, default http://localhost:8000) with OPENROUTER_API_KEY.
//
//   flutter test test/integration/live_supabase_test.dart
//
// Writes fictional test schedules 12–13 days ahead for Lukas and empties
// them again at the end.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:bbw_visual_routine/core/data/mock_library.dart';
import 'package:bbw_visual_routine/core/models/activity_category.dart';
import 'package:bbw_visual_routine/core/models/app_user.dart';
import 'package:bbw_visual_routine/core/models/schedule_snapshot.dart';
import 'package:bbw_visual_routine/core/models/scheduled_event.dart';
import 'package:bbw_visual_routine/core/models/support_request.dart';
import 'package:bbw_visual_routine/core/models/visual_ref.dart';
import 'package:bbw_visual_routine/core/state/library_store.dart';
import 'package:bbw_visual_routine/core/state/participant_directory.dart';
import 'package:bbw_visual_routine/core/state/schedule_store.dart';
import 'package:bbw_visual_routine/core/time/time_format.dart';
import 'package:bbw_visual_routine/services/app_config.dart';
import 'package:bbw_visual_routine/services/backend_event_draft_generator.dart';
import 'package:bbw_visual_routine/services/supabase_auth_service.dart';
import 'package:bbw_visual_routine/services/supabase_sync.dart';

const _lukasId = 'b0000000-0000-0000-0000-000000000001';
const _jonasId = 'b0000000-0000-0000-0000-000000000003';

String _password() {
  const fromDefine = String.fromEnvironment('DEMO_PASSWORD');
  if (fromDefine.isNotEmpty) return fromDefine;
  final f = File('supabase/.demo-credentials.local');
  return f.existsSync() ? f.readAsStringSync().trim() : '';
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One signed-in app instance (what one phone/browser would hold).
class _Session {
  final SupabaseClient db;
  late final SupabaseSync sync;
  late final ScheduleStore store;
  late final SupabaseAuthService auth;
  AppUser? user;

  _Session()
      : db = SupabaseClient(
          AppConfig.supabaseUrl,
          AppConfig.supabasePublishableKey,
          authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        ) {
    sync = SupabaseSync(
      db: db,
      participants: ParticipantDirectory(const []),
      support: SupabaseSupportStore(db),
      progress: SupabaseProgressStore(db),
      library: LibraryStore(
          activities: mockLibraryActivities,
          places: mockPlaces,
          contacts: mockContacts),
    );
    store = ScheduleStore(
      repository: sync,
      initial: ScheduleSnapshot(
          version: 1, publishedAt: DateTime.now(), events: const {}),
    );
    sync.attach(store);
    auth = SupabaseAuthService(
        db: db, onSignedIn: sync.start, onSignedOut: sync.stop);
  }

  Future<_Session> signIn(String email, String password) async {
    user = await auth.signIn(username: email, password: password);
    return this;
  }

  List<ScheduledEvent> eventsFor(String pid, DateTime day) =>
      store.published.activeEventsFor(pid, day);

  Future<void> close() async {
    await auth.signOut();
    await db.dispose();
  }
}

/// Polls until [check] is true (Realtime delivery is asynchronous).
Future<void> eventually(String what, bool Function() check,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (!check()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for: $what');
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

void main() {
  final password = _password();
  final skip = password.isEmpty ? 'No demo password available' : null;
  final today = TimeFormat.dateOnly(DateTime.now());
  final dayA = today.add(const Duration(days: 12));
  final dayB = today.add(const Duration(days: 13));
  final dayC = today.add(const Duration(days: 14));
  DateTime at(DateTime d, int h, [int m = 0]) =>
      DateTime(d.year, d.month, d.day, h, m);

  late _Session anna, lukas, jonas;

  setUpAll(() async {
    if (skip != null) return;
    anna = await _Session().signIn('anna.weber.demo@example.com', password);
    lukas = await _Session().signIn('lukas.demo@example.com', password);
    jonas = await _Session().signIn('jonas.demo@example.com', password);
    // Give the Realtime channels a moment to join.
    await Future<void>.delayed(const Duration(seconds: 3));
  });

  tearDownAll(() async {
    if (skip != null) return;
    // Empty the test days again (leaves empty drafts, invisible to Lukas).
    await anna.sync.idle;
    for (final d in [dayA, dayB, dayC]) {
      await anna.db.rpc('save_schedule', params: {
        'p_participant_id': _lukasId,
        'p_schedule_date': _iso(d),
        'p_activities': [],
        'p_publish': true,
      });
    }
    await anna.close();
    await lukas.close();
    await jonas.close();
  });

  group('live Supabase + AI', skip: skip, () {
    test('1-2 staff signs in and sees only assigned participants', () {
      expect(anna.user!.role, Role.staff);
      final names = anna.sync.participants.all.map((p) => p.displayName).toSet();
      expect(names, {'Lukas', 'Mia'});
      expect(anna.sync.participants[_jonasId], isNull);
      expect(lukas.user!.role, Role.participant);
      expect(lukas.user!.participantId, _lukasId);
    });

    test('3-5 staff creates + publishes a day; participant sees it live', () async {
      final store = anna.store;
      store.saveDrafts([
        ScheduledEvent(
          id: store.newId('evt'),
          title: 'Woodworking (test)',
          category: ActivityCategory.work,
          start: at(dayA, 9),
          end: at(dayA, 11),
          visual: const VisualRef(symbol: 'work'),
          placeId: mockPlaces.first.id,
          whatToBring: const ['Safety glasses'],
          assignedParticipantIds: {_lukasId},
        ),
        ScheduledEvent(
          id: store.newId('evt'),
          title: 'Lunch (test)',
          category: ActivityCategory.meal,
          start: at(dayA, 12),
          end: at(dayA, 12, 45),
          visual: const VisualRef(symbol: 'meal'),
          assignedParticipantIds: {_lukasId},
        ),
      ]);
      // Drafts are local: nothing on the server yet.
      expect(lukas.eventsFor(_lukasId, dayA), isEmpty);

      store.publishDrafts(publishedBy: 'Anna', day: dayA);
      await anna.sync.idle;

      await eventually('Lukas receives the published day via Realtime',
          () => lukas.eventsFor(_lukasId, dayA).length == 2);
      final wood = lukas.eventsFor(_lukasId, dayA).first;
      expect(wood.title, 'Woodworking (test)');
      expect(wood.whatToBring, ['Safety glasses']);
      expect(wood.placeId, mockPlaces.first.id);
      expect(wood.start, at(dayA, 9));
      // Jonas (not assigned to this event) never sees it.
      expect(jonas.store.published.eventsOn(dayA), isEmpty);
    });

    test('6-7 participant completes an activity; staff sees progress', () async {
      final wood = lukas.eventsFor(_lukasId, dayA).first;
      await lukas.sync.progress.setDone(wood.id, _lukasId, true);
      final row = await lukas.db
          .from('activities')
          .select('status')
          .eq('meta->>eventId', wood.id)
          .single();
      expect(row['status'], 'completed');
      await eventually('Anna sees the completion via Realtime',
          () => anna.sync.progress.isDone(wood.id, _lukasId));
    });

    test('staff edit keeps the completion; participant gets a change notice', () async {
      final wood = anna.eventsFor(_lukasId, dayA).first;
      anna.store.publish(
        upserts: [wood.copyWith(end: at(dayA, 11, 30))],
        publishedBy: 'Anna',
      );
      await anna.sync.idle;
      await eventually('Lukas gets the new end time',
          () => lukas.eventsFor(_lukasId, dayA).first.end == at(dayA, 11, 30));
      expect(lukas.store.pendingChangesFor(_lukasId), isNotEmpty);
      await eventually('completion survives the edit',
          () => lukas.sync.progress.isDone(wood.id, _lukasId));
    });

    test('8-9 participant asks for help; staff sees and resolves it', () async {
      final request = lukas.sync.support.create(
        participantId: _lukasId,
        reason: SupportReason.dontKnowWhereToGo,
        at: DateTime.now(),
        currentActivityTitle: 'Woodworking (test)',
      );
      expect(request.status, SupportStatus.open);
      late SupportRequest seen;
      await eventually('Anna receives the request via Realtime', () {
        final open = anna.sync.support.unresolved.where((r) =>
            r.participantId == _lukasId &&
            r.currentActivityTitle == 'Woodworking (test)' &&
            r.reason == SupportReason.dontKnowWhereToGo);
        if (open.isEmpty) return false;
        seen = open.first;
        return true;
      });
      anna.sync.support.setStatus(seen.id, SupportStatus.resolved);
      await eventually('Lukas sees it resolved', () => lukas.sync.support.all
          .any((r) => r.id == seen.id && r.status == SupportStatus.resolved));
      // Jonas cannot see Lukas's requests.
      await jonas.sync.support.reload();
      expect(jonas.sync.support.all.where((r) => r.participantId == _lukasId),
          isEmpty);
    });

    test('10-12 AI draft → staff approves → participant sees it', () async {
      final ai = BackendEventDraftGenerator(baseUrl: Uri.parse(AppConfig.aiBackendUrl));
      final proposals = await ai.propose(
        'Workshop from 9 to 11, lunch at 12:00 until 12:45, gardening at 14:00 until 15:30.',
        today: dayB,
        library: mockLibraryActivities,
      );
      expect(proposals.length, greaterThanOrEqualTo(3));
      expect(proposals.every((p) => TimeFormat.sameDay(p.start, dayB)), isTrue);

      // Same as the "Build with AI" dialog: proposals become local drafts.
      final store = anna.store;
      store.saveDrafts([
        for (final p in proposals)
          ScheduledEvent(
            id: store.newId('evt'),
            title: p.title,
            category: p.libraryMatch?.category ?? ActivityCategory.work,
            start: p.start,
            end: p.end,
            visual: p.libraryMatch?.visual ?? const VisualRef(symbol: 'event'),
            assignedParticipantIds: {_lukasId},
          ),
      ]);
      // Not published by the AI: Lukas sees nothing yet.
      await lukas.sync.refresh();
      expect(lukas.eventsFor(_lukasId, dayB), isEmpty);

      store.publishDrafts(publishedBy: 'Anna', day: dayB);
      await anna.sync.idle;
      await eventually('Lukas sees the approved AI routine',
          () => lukas.eventsFor(_lukasId, dayB).length == proposals.length);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('staff edit keeps sub-steps, untimed items, completion; is audited', () async {
      final date = _iso(dayC);
      // A day created outside the planner UI (like the seed / AI proposal).
      await anna.db.rpc('save_schedule', params: {
        'p_participant_id': _lukasId,
        'p_schedule_date': date,
        'p_activities': [
          {
            'title': 'Morning routine (test)',
            'startTime': '07:00',
            'endTime': '07:30',
            'subSteps': [
              {'title': 'Wash face'},
              {'title': 'Brush teeth'},
            ],
          },
          {'title': 'Untimed lunch (test)'},
        ],
        'p_publish': true,
      });
      await anna.sync.refresh();
      await lukas.sync.refresh();
      final morning = lukas.eventsFor(_lukasId, dayC).single;
      await lukas.sync.progress.setDone(morning.id, _lukasId, true);
      await anna.sync.refresh();
      final before = DateTime.now().toUtc();

      anna.store.publish(
        upserts: [anna.eventsFor(_lukasId, dayC).single.copyWith(end: at(dayC, 7, 45))],
        publishedBy: 'Anna',
      );
      await anna.sync.idle;

      final rows = await anna.db
          .from('schedules')
          .select('id, status, activities(title, end_time, status, activity_steps(title))')
          .eq('participant_id', _lukasId)
          .eq('schedule_date', date)
          .single();
      expect(rows['status'], 'published');
      final acts = (rows['activities'] as List).cast<Map<String, dynamic>>();
      final m = acts.firstWhere((a) => a['title'] == 'Morning routine (test)');
      expect(m['end_time'], '07:45:00');
      expect(m['status'], 'completed');
      expect((m['activity_steps'] as List).length, 2);
      expect(acts.any((a) => a['title'] == 'Untimed lunch (test)'), isTrue);

      final log = await anna.db
          .from('schedule_changes')
          .select('activity_id, new_values')
          .eq('schedule_id', rows['id'] as String)
          .gte('created_at', before.toIso8601String());
      expect(log.where((r) => r['activity_id'] != null), isNotEmpty,
          reason: 'the edited activity is in the audit log');
      expect(
          log.where((r) =>
              r['activity_id'] == null &&
              (r['new_values'] as Map?)?['status'] == 'draft'),
          isEmpty,
          reason: 'the day was never unpublished');
    });

    test('13 unauthenticated and unauthorized access is blocked', () async {
      final anon = SupabaseClient(
          AppConfig.supabaseUrl, AppConfig.supabasePublishableKey);
      for (final table in ['schedules', 'activities', 'profiles', 'support_requests']) {
        // anon has no table grants at all: the read is refused outright.
        await expectLater(anon.from(table).select('id'),
            throwsA(isA<PostgrestException>()
                .having((e) => e.code, 'code', '42501')),
            reason: table);
      }
      await expectLater(
          anon.rpc('save_schedule', params: {
            'p_participant_id': _lukasId,
            'p_schedule_date': '2030-01-01',
            'p_activities': [],
          }),
          throwsA(isA<PostgrestException>()));
      await anon.dispose();

      // Jonas reads only his own schedules.
      final rows = await jonas.db.from('schedules').select('participant_id');
      expect(rows.every((r) => r['participant_id'] == _jonasId), isTrue);
      // Participants cannot write schedules; staff cannot write for others.
      await expectLater(
          lukas.db.rpc('save_schedule', params: {
            'p_participant_id': _lukasId,
            'p_schedule_date': '2030-01-01',
            'p_activities': [],
          }),
          throwsA(isA<PostgrestException>()
              .having((e) => e.code, 'code', '42501')));
      await expectLater(
          anna.db.rpc('save_schedule', params: {
            'p_participant_id': _jonasId,
            'p_schedule_date': '2030-01-01',
            'p_activities': [],
          }),
          throwsA(isA<PostgrestException>()
              .having((e) => e.code, 'code', '42501')));
      // Completion cannot be written directly, only via the RPC.
      final wood = lukas.eventsFor(_lukasId, dayA).first;
      final updated = await lukas.db
          .from('activities')
          .update({'title': 'hacked'})
          .eq('meta->>eventId', wood.id)
          .select();
      expect(updated, isEmpty);
    });
  });
}
