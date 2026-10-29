import '../models/library_items.dart';
import '../models/scheduled_event.dart';
import '../time/time_format.dart';
import 'mock_library.dart';
import 'mock_participants.dart';

// DEMO DATA ONLY. Generates one week of fictional schedules around [today].

abstract final class MockEventKeys {
  static const breakfast = 'breakfast';
  static const busToBbw = 'bus-to-bbw';
  static const woodworkMorning = 'woodwork-am';
  static const metalMorning = 'metal-am';
  static const lunch = 'lunch';
  static const woodworkAfternoon = 'woodwork-pm';
  static const metalAfternoon = 'metal-pm';
  static const coaching = 'coaching';
  static const sports = 'sports';
  static const physio = 'physio';
  static const busHomeEarly = 'bus-home-early';
  static const busHomeLate = 'bus-home-late';
  static const study = 'study';
  static const dinner = 'dinner';
  static const evening = 'evening';
  static const groupMeeting = 'group-meeting';
  static const leisure = 'leisure';
}

String mockEventId(String key, DateTime day) =>
    'evt-$key-${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

LibraryActivity _activity(String id) =>
    mockLibraryActivities.firstWhere((a) => a.id == id);

ScheduledEvent _event(
  String key,
  DateTime day,
  String activityId, {
  required String from,
  required String to,
  required Set<String> participants,
  EventKind kind = EventKind.activity,
  String? planB,
}) {
  final a = _activity(activityId);
  DateTime at(String hm) {
    final parts = hm.split(':');
    return DateTime(
        day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  return ScheduledEvent(
    id: mockEventId(key, day),
    title: a.name,
    category: a.category,
    kind: kind,
    start: at(from),
    end: at(to),
    visual: a.visual,
    placeId: a.defaultPlaceId,
    contactId: a.defaultContactId,
    whatToBring: a.whatToBring,
    instructions: a.instructions,
    assignedParticipantIds: participants,
    libraryActivityId: a.id,
    planBActivityId: planB,
  );
}

const _lena = MockParticipantIds.lena;
const _jonas = MockParticipantIds.jonas;
const _mia = MockParticipantIds.mia;
const _elias = MockParticipantIds.elias;
const _everyone = MockParticipantIds.all;

List<ScheduledEvent> _trainingDay(DateTime day) => [
      _event(MockEventKeys.breakfast, day, MockActivityIds.breakfast,
          from: '07:30', to: '08:15', participants: _everyone),
      _event(MockEventKeys.busToBbw, day, MockActivityIds.busToBbw,
          from: '08:30',
          to: '08:50',
          participants: _everyone,
          kind: EventKind.travel),
      // Shared organisational event: one event, three participants.
      _event(MockEventKeys.woodworkMorning, day, MockActivityIds.woodwork,
          from: '09:00',
          to: '11:00',
          participants: {_lena, _jonas, _mia},
          planB: MockActivityIds.study),
      _event(MockEventKeys.metalMorning, day, MockActivityIds.metalwork,
          from: '09:00', to: '11:00', participants: {_elias}),
      _event(MockEventKeys.lunch, day, MockActivityIds.lunch,
          from: '11:30', to: '12:15', participants: _everyone),
      _event(MockEventKeys.woodworkAfternoon, day, MockActivityIds.woodwork,
          from: '13:00',
          to: '15:00',
          participants: {_lena, _mia},
          planB: MockActivityIds.study),
      _event(MockEventKeys.coaching, day, MockActivityIds.coaching,
          from: '13:00', to: '14:00', participants: {_jonas}),
      _event(MockEventKeys.metalAfternoon, day, MockActivityIds.metalwork,
          from: '13:00', to: '15:00', participants: {_elias}),
      _event(MockEventKeys.sports, day, MockActivityIds.sports,
          from: '15:00', to: '16:00', participants: {_jonas}),
      _event(MockEventKeys.busHomeEarly, day, MockActivityIds.busHome,
          from: '15:15',
          to: '15:35',
          participants: {_lena, _mia},
          kind: EventKind.travel),
      _event(MockEventKeys.physio, day, MockActivityIds.physio,
          from: '15:30', to: '16:00', participants: {_elias}),
      _event(MockEventKeys.busHomeLate, day, MockActivityIds.busHome,
          from: '16:10',
          to: '16:30',
          participants: {_jonas, _elias},
          kind: EventKind.travel),
      _event(MockEventKeys.study, day, MockActivityIds.study,
          from: '16:45', to: '17:30', participants: _everyone),
      _event(MockEventKeys.dinner, day, MockActivityIds.dinner,
          from: '18:00', to: '18:45', participants: _everyone),
      _event(MockEventKeys.evening, day, MockActivityIds.eveningRoutine,
          from: '21:00', to: '21:30', participants: _everyone),
    ];

List<ScheduledEvent> _weekendDay(DateTime day) => [
      _event(MockEventKeys.breakfast, day, MockActivityIds.breakfast,
          from: '09:00', to: '09:45', participants: _everyone),
      _event(MockEventKeys.groupMeeting, day, MockActivityIds.groupMeeting,
          from: '10:30', to: '11:15', participants: _everyone),
      _event(MockEventKeys.lunch, day, MockActivityIds.lunch,
          from: '12:30', to: '13:15', participants: _everyone),
      _event(MockEventKeys.leisure, day, MockActivityIds.boardGames,
          from: '14:00', to: '15:30', participants: _everyone),
      _event(MockEventKeys.dinner, day, MockActivityIds.dinner,
          from: '18:00', to: '18:45', participants: _everyone),
      _event(MockEventKeys.evening, day, MockActivityIds.eveningRoutine,
          from: '21:30', to: '22:00', participants: _everyone),
    ];

/// One week (Monday–Sunday) of published events around [today].
///
/// [today] always gets a training day so the demo scenario works on any
/// day of the week.
List<ScheduledEvent> buildMockWeek(DateTime today) {
  final monday = TimeFormat.startOfWeek(today);
  final events = <ScheduledEvent>[];
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final isWeekend = day.weekday >= DateTime.saturday;
    final useTrainingDay = !isWeekend || TimeFormat.sameDay(day, today);
    events.addAll(useTrainingDay ? _trainingDay(day) : _weekendDay(day));
  }
  return events;
}

/// Seeded change 1: Elias's physiotherapy moved to a new room (location
/// change, not yet acknowledged by Elias).
List<ScheduledEvent> seedLocationChange(
  Map<String, ScheduledEvent> events,
  DateTime today,
) {
  final physio = events[mockEventId(MockEventKeys.physio, today)]!;
  return [physio.copyWith(placeId: MockPlaceIds.room104)];
}

/// Seeded change 2: Jonas's sports cancelled and replaced by board games
/// (replacement case, not yet acknowledged by Jonas).
ScheduledEvent seedSportsReplacement(DateTime today) {
  final games = _activity(MockActivityIds.boardGames);
  final sports = _event(MockEventKeys.sports, today, MockActivityIds.sports,
      from: '15:00', to: '16:00', participants: {_jonas});
  return ScheduledEvent(
    id: mockEventId('board-games-replacement', today),
    title: games.name,
    category: games.category,
    start: sports.start,
    end: sports.end,
    visual: games.visual,
    placeId: games.defaultPlaceId,
    contactId: games.defaultContactId,
    assignedParticipantIds: {_jonas},
    libraryActivityId: games.id,
  );
}
