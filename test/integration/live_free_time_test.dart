// LIVE tests for participant free-time planning against the hackathon
// Supabase project and the local FastAPI AI backend (real OpenRouter call).
//
//   flutter test test/integration/live_free_time_test.dart
//
// Needs supabase/.demo-credentials.local and a running backend. Uses Lukas on
// the next Saturday/Sunday (empty in the demo data) plus days 20+ ahead, and
// removes everything again. Speech is simulated by text (no microphone here).
import 'dart:io';

import 'package:bbw_visual_routine/core/data/mock_library.dart';
import 'package:bbw_visual_routine/core/logic/free_time.dart';
import 'package:bbw_visual_routine/core/models/schedule_snapshot.dart';
import 'package:bbw_visual_routine/core/models/scheduled_event.dart';
import 'package:bbw_visual_routine/core/planning/free_time_planner.dart';
import 'package:bbw_visual_routine/core/state/library_store.dart';
import 'package:bbw_visual_routine/core/state/participant_directory.dart';
import 'package:bbw_visual_routine/core/state/schedule_store.dart';
import 'package:bbw_visual_routine/core/time/time_format.dart';
import 'package:bbw_visual_routine/services/app_config.dart';
import 'package:bbw_visual_routine/services/backend_event_draft_generator.dart';
import 'package:bbw_visual_routine/services/supabase_auth_service.dart';
import 'package:bbw_visual_routine/services/supabase_free_time_planner.dart';
import 'package:bbw_visual_routine/services/supabase_sync.dart';
import 'package:bbw_visual_routine/services/task_image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

const _lukas = 'b0000000-0000-0000-0000-000000000001';

String _password() {
  const d = String.fromEnvironment('DEMO_PASSWORD');
  if (d.isNotEmpty) return d;
  final f = File('supabase/.demo-credentials.local');
  return f.existsSync() ? f.readAsStringSync().trim() : '';
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One app instance (phone) with the real services.
class _App {
  final SupabaseClient db = SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabasePublishableKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  late final SupabaseSync sync;
  late final ScheduleStore store;
  late final SupabaseFreeTimePlanner planner;

  _App() {
    sync = SupabaseSync(
      db: db,
      participants: ParticipantDirectory(const []),
      support: SupabaseSupportStore(db),
      progress: SupabaseProgressStore(db),
      library: LibraryStore(
          activities: mockLibraryActivities, places: mockPlaces, contacts: mockContacts),
      images: TaskImageService(db),
    );
    store = ScheduleStore(
      repository: sync,
      initial: ScheduleSnapshot(version: 1, publishedAt: DateTime.now(), events: const {}),
    );
    sync.attach(store);
    planner = SupabaseFreeTimePlanner(
      db: db,
      ai: BackendEventDraftGenerator(baseUrl: Uri.parse(AppConfig.aiBackendUrl)),
      onSaved: sync.refresh,
    );
  }

  Future<_App> signIn(String email, String pw) async {
    await SupabaseAuthService(db: db, onSignedIn: sync.start, onSignedOut: sync.stop)
        .signIn(username: email, password: pw);
    return this;
  }

  List<ScheduledEvent> personalOn(DateTime day) =>
      store.published.activeEventsFor(_lukas, day).where((e) => e.isPersonal).toList();

  Future<void> close() async {
    await sync.stop();
    await db.auth.signOut();
    await db.dispose();
  }
}

DraftActivity _d(String title, String start, String end) =>
    DraftActivity(title: title, start: parseHm(start), end: parseHm(end));

Matcher _pgError(String message) =>
    throwsA(isA<PlanSaveException>().having((e) => e.message, 'message', contains(message)));

void main() {
  final pw = _password();
  final today = TimeFormat.dateOnly(DateTime.now());
  final saturday = today.add(Duration(days: (DateTime.saturday - today.weekday) % 7 == 0
      ? 7
      : (DateTime.saturday - today.weekday) % 7));
  final sunday = saturday.add(const Duration(days: 1));
  final monday = today.add(const Duration(days: 20)); // official 09–15
  final untimedDay = today.add(const Duration(days: 21));
  final raceDay = today.add(const Duration(days: 22));
  final closedDay = today.add(const Duration(days: 23));
  final testDays = [saturday, sunday, monday, untimedDay, raceDay, closedDay];

  group('live free-time planning', skip: pw.isEmpty ? 'No demo password' : null, () {
    late _App lukas, anna, mia, ben;

    Future<void> staffDay(DateTime day, List<Map<String, dynamic>> items) => anna.db.rpc('save_schedule',
        params: {'p_participant_id': _lukas, 'p_schedule_date': _iso(day), 'p_activities': items, 'p_publish': true});

    Future<int> personalCount(DateTime day) async => (await anna.db
            .from('personal_activities')
            .select('id')
            .eq('participant_id', _lukas)
            .eq('activity_date', _iso(day)))
        .length;

    setUpAll(() async {
      anna = await _App().signIn('anna.weber.demo@example.com', pw);
      for (final d in testDays) {
        final existing = await anna.db.from('schedules').select('activities(id)')
            .eq('participant_id', _lukas).eq('schedule_date', _iso(d));
        expect(existing.expand((r) => r['activities'] as List), isEmpty,
            reason: 'test day ${_iso(d)} must have no activities');
      }
      lukas = await _App().signIn('lukas.demo@example.com', pw);
      mia = await _App().signIn('mia.demo@example.com', pw);
      ben = await _App().signIn('ben.schmidt.demo@example.com', pw);
    });

    tearDownAll(() async {
      final dates = testDays.map(_iso).toList();
      await anna.db.from('personal_activities').delete().eq('participant_id', _lukas).inFilter('activity_date', dates);
      await anna.db.from('unavailable_periods').delete().eq('participant_id', _lukas).inFilter('period_date', dates);
      for (final d in testDays) {
        await staffDay(d, []);
      }
      for (final a in [lukas, anna, mia, ben]) {
        await a.close();
      }
    });

    test('1–6 empty Saturday → AI draft from the spoken/typed text, no invented times', () async {
      final day = await lukas.planner.loadDay(saturday);
      expect(day.blocked, isFalse);
      expect(day.freeSlots.map((s) => s.toString()), ['07:00–22:00']);

      final drafts = await lukas.planner.suggest(
          'On Saturday, I want breakfast at 8 AM, shopping at 10 AM, football at 2 PM, and a movie at 8 PM.',
          day);
      expect(drafts.map((d) => formatHm(d.start!)), ['08:00', '10:00', '14:00', '20:00']);
      expect(drafts.every((d) => d.otherDay == null), isTrue, reason: '"Saturday" = the planned day');
      expect(drafts.where((d) => d.end != null), isEmpty, reason: 'no durations were said');
      expect(FreeTimeRules.canSave(day, drafts), isFalse, reason: 'lengths must be chosen first');
      expect(drafts.every((d) => RegExp(r'^[a-z_]+$').hasMatch(d.iconKey)), isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('7–9 save, appears on the correct date, persists after restart, can be completed', () async {
      final day = await lukas.planner.loadDay(saturday);
      await lukas.planner.save(day, [
        _d('Breakfast', '08:00', '08:30'),
        _d('Shopping', '10:00', '11:00'),
        _d('Football', '14:00', '15:30'),
        _d('Movie', '20:00', '22:00'),
      ]);
      expect(lukas.personalOn(saturday).map((e) => e.title), ['Breakfast', 'Shopping', 'Football', 'Movie']);
      expect(lukas.personalOn(sunday), isEmpty);

      // "Restart": a brand-new app instance signs in.
      final again = await _App().signIn('lukas.demo@example.com', pw);
      final events = again.personalOn(saturday);
      expect(events.length, 4);
      expect(events.every((e) => e.isPersonal), isTrue);
      await again.sync.progress.setDone(events.first.id, _lukas, true);
      final row = await again.db.from('personal_activities').select('status')
          .eq('id', events.first.id.substring('personal-'.length)).single();
      expect(row['status'], 'completed');
      await again.close();
    });

    test('10–13 participant cannot edit/delete/move official or saved personal activities', () async {
      final official = await lukas.db.from('activities').select('id, title, start_time').limit(1).single();
      final id = official['id'] as String;
      final r1 = await lukas.db.from('activities').update({'title': 'hacked', 'start_time': '05:00'}).eq('id', id).select();
      expect(r1, isEmpty);
      final r2 = await lukas.db.from('activities').delete().eq('id', id).select();
      expect(r2, isEmpty);
      final still = await anna.db.from('activities').select('title, start_time').eq('id', id).single();
      expect(still['title'], official['title']);
      expect(still['start_time'], official['start_time']);
      await expectLater(lukas.db.from('activities').insert({'schedule_id': id, 'title': 'x'}),
          throwsA(isA<PostgrestException>()));

      final mine = (await lukas.db.from('personal_activities').select('id').eq('activity_date', _iso(saturday))).first['id'];
      await expectLater(lukas.db.from('personal_activities').update({'start_time': '09:00'}).eq('id', mine),
          throwsA(isA<PostgrestException>()), reason: 'no update grant');
      expect(await lukas.db.from('personal_activities').delete().eq('id', mine).select(), isEmpty);
      await expectLater(
          lukas.db.from('personal_activities').insert({
            'participant_id': _lukas, 'activity_date': _iso(saturday), 'title': 'x',
            'start_time': '05:00', 'end_time': '06:00'}),
          throwsA(isA<PostgrestException>()), reason: 'only through the RPC');
      expect(await personalCount(saturday), 4);
      await expectLater(
          lukas.db.rpc('save_schedule', params: {'p_participant_id': _lukas, 'p_schedule_date': _iso(saturday), 'p_activities': []}),
          throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
    });

    test('15 cannot plan over existing personal activities; batches are all-or-nothing', () async {
      final day = await lukas.planner.loadDay(saturday);
      expect(day.freeSlots.map((s) => s.toString()),
          ['07:00–08:00', '08:30–10:00', '11:00–14:00', '15:30–20:00']);
      // Bypass the client check on purpose: the server must refuse.
      await expectLater(
          lukas.db.rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(saturday),
            'p_activities': [
              {'title': 'Reading', 'startTime': '12:00', 'endTime': '13:00'},
              {'title': 'More football', 'startTime': '14:30', 'endTime': '15:00'},
            ],
          }),
          throwsA(isA<PostgrestException>().having((e) => e.details.toString(), 'details', contains('Football'))));
      expect(await personalCount(saturday), 4, reason: 'Reading was not saved either');
    });

    test('14 + 17 a weekend with an official activity is not fully free', () async {
      await staffDay(sunday, [
        {'title': 'Sports club', 'startTime': '11:00', 'endTime': '12:00', 'category': 'PERSONAL'},
      ]);
      final day = await lukas.planner.loadDay(sunday);
      expect(day.freeSlots.map((s) => s.toString()), ['07:00–11:00', '12:00–22:00']);
      await expectLater(
          lukas.db.rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(sunday),
            'p_activities': [{'title': 'Football', 'startTime': '11:30', 'endTime': '12:30'}],
          }),
          throwsA(isA<PostgrestException>().having((e) => e.details.toString(), 'details', contains('Sports club'))));
      await lukas.planner.save(day, [_d('Football', '12:00', '13:00')]); // touching is fine
      expect(await personalCount(sunday), 1);
    });

    test('weekday with official 09:00–15:00: only outside it', () async {
      await staffDay(monday, [
        {'title': 'Workshop', 'startTime': '09:00', 'endTime': '15:00', 'category': 'BBW_TRAINING'},
      ]);
      final day = await lukas.planner.loadDay(monday);
      expect(day.freeSlots.map((s) => s.toString()), ['07:00–09:00', '15:00–22:00']);
      expect(FreeTimeRules.canSave(day, [_d('Gym', '14:00', '16:00')]), isFalse);
      await expectLater(
          lukas.db.rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(monday),
            'p_activities': [{'title': 'Gym', 'startTime': '14:00', 'endTime': '16:00'}],
          }),
          throwsA(isA<PostgrestException>()));
      await lukas.planner.save(day, [_d('Gym', '15:00', '16:00')]);
    });

    test('official activity without a time → day needs staff; staff restrictions apply', () async {
      await staffDay(untimedDay, [{'title': 'Trip'}]);
      final day = await lukas.planner.loadDay(untimedDay);
      expect(day.blocked, isTrue);
      expect(day.blockedReason, contains('Trip'));
      await expectLater(
          lukas.db.rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(untimedDay),
            'p_activities': [{'title': 'Walk', 'startTime': '18:00', 'endTime': '19:00'}],
          }),
          throwsA(isA<PostgrestException>().having((e) => e.message, 'message', 'day_not_plannable')));

      await anna.db.from('unavailable_periods').insert({
        'participant_id': _lukas, 'period_date': _iso(saturday),
        'start_time': '16:00', 'end_time': '18:00', 'reason': 'Room cleaning'});
      await anna.db.from('unavailable_periods').insert(
          {'participant_id': _lukas, 'period_date': _iso(closedDay), 'reason': 'Family visit day'});
      final sat = await lukas.planner.loadDay(saturday);
      await expectLater(lukas.planner.save(sat, [_d('Walk', '17:00', '17:30')]),
          throwsA(isA<PlanSaveException>()), reason: 'client already refuses');
      await expectLater(
          lukas.db.rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(saturday),
            'p_activities': [{'title': 'Walk', 'startTime': '17:00', 'endTime': '17:30'}],
          }),
          throwsA(isA<PostgrestException>().having((e) => e.details.toString(), 'details', contains('unavailable'))));
      expect((await lukas.planner.loadDay(closedDay)).blockedReason, 'Family visit day');
      // Participants cannot add or remove restrictions.
      await expectLater(
          lukas.db.from('unavailable_periods').insert({'participant_id': _lukas, 'period_date': _iso(saturday)}),
          throwsA(isA<PostgrestException>()));
      expect(await lukas.db.from('unavailable_periods').delete().eq('participant_id', _lukas).select(), isEmpty);
    });

    test('18 concurrent overlapping saves: exactly one wins', () async {
      final second = await _App().signIn('lukas.demo@example.com', pw);
      Future<String> attempt(SupabaseClient db, String start, String end) => db
          .rpc('save_personal_free_time_plan', params: {
            'p_date': _iso(raceDay),
            'p_activities': [{'title': 'Race $start', 'startTime': start, 'endTime': end}],
          })
          .then((_) => 'ok')
          .catchError((Object e) => e is PostgrestException ? e.message : 'other');
      final results = await Future.wait([
        attempt(lukas.db, '10:00', '11:00'),
        attempt(second.db, '10:30', '11:30'),
        attempt(lukas.db, '10:15', '10:45'),
      ]);
      expect(results.where((r) => r == 'ok').length, 1, reason: results.join(', '));
      expect(results.where((r) => r == 'plan_conflict').length, 2);
      expect(await personalCount(raceDay), 1);
      await second.close();
    });

    test('16 other participants and unassigned staff see nothing', () async {
      expect(await mia.db.from('personal_activities').select('id').eq('participant_id', _lukas), isEmpty);
      expect(await ben.db.from('personal_activities').select('id').eq('participant_id', _lukas), isEmpty);
      for (final app in [mia, ben]) {
        await expectLater(app.db.rpc('get_planning_day', params: {'p_date': _iso(saturday), 'p_participant_id': _lukas}),
            throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
      }
      await expectLater(ben.db.rpc('save_personal_free_time_plan', params: {
        'p_date': _iso(saturday), 'p_activities': [{'title': 'x', 'startTime': '07:00', 'endTime': '07:30'}]}),
          throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')), reason: 'staff cannot use it');
      await expectLater(lukas.planner.loadDay(today.subtract(const Duration(days: 1))), _pgError('30 days'));
      await expectLater(lukas.planner.loadDay(today.add(const Duration(days: 40))), _pgError('30 days'));
    });

    test('19 staff still manage official schedules; may remove but not edit personal plans', () async {
      await anna.sync.refresh();
      final personal = anna.store.published.activeEventsFor(_lukas, saturday).where((e) => e.isPersonal).toList();
      expect(personal.length, 4, reason: 'staff see the participant plan');

      // Staff edit official Sunday: works, personal plan untouched.
      final sportsClub = anna.store.published.activeEventsFor(_lukas, sunday).firstWhere((e) => !e.isPersonal);
      anna.store.publish(upserts: [sportsClub.copyWith(end: sportsClub.end.add(const Duration(minutes: -15)))],
          publishedBy: 'Anna');
      await anna.sync.idle;
      final row = await anna.db.from('activities').select('end_time').eq('title', 'Sports club').single();
      expect(row['end_time'], '11:45:00');
      expect(await personalCount(sunday), 1);

      // Editing a participant plan is refused (nothing written).
      final football = personal.firstWhere((e) => e.title == 'Football');
      anna.store.publish(upserts: [football.copyWith(start: football.start.add(const Duration(hours: 1)))],
          publishedBy: 'Anna');
      expect(anna.sync.errors.value, contains('removed, not edited'));
      await anna.sync.idle;
      final fb = await anna.db.from('personal_activities').select('start_time')
          .eq('id', football.id.substring('personal-'.length)).single();
      expect(fb['start_time'], '14:00:00');

      // Removing one is allowed.
      final movie = personal.firstWhere((e) => e.title == 'Movie');
      anna.store.publish(upserts: [movie.copyWith(status: EventStatus.cancelled)], publishedBy: 'Anna');
      await anna.sync.idle;
      expect(await personalCount(saturday), 3);
      await lukas.sync.refresh();
      expect(lukas.personalOn(saturday).map((e) => e.title), isNot(contains('Movie')));
    });
  });
}
