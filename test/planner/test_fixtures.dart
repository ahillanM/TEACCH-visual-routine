import 'package:bbw_visual_routine/core/data/mock_participants.dart';
import 'package:bbw_visual_routine/core/data/mock_schedules.dart';
import 'package:bbw_visual_routine/core/models/feed_entry.dart';
import 'package:bbw_visual_routine/core/models/schedule_snapshot.dart';
import 'package:bbw_visual_routine/core/state/schedule_repository.dart';
import 'package:bbw_visual_routine/core/state/schedule_store.dart';

/// A fixed Thursday so tests never depend on the real date.
final testDay = DateTime(2026, 10, 29);

DateTime at(int hour, [int minute = 0]) =>
    DateTime(testDay.year, testDay.month, testDay.day, hour, minute);

ScheduleStore freshStore() {
  final events = buildMockWeek(testDay);
  return ScheduleStore(
    repository: InMemoryScheduleRepository(),
    initial: ScheduleSnapshot(
      version: 1,
      publishedAt: testDay,
      events: {for (final e in events) e.id: e},
    ),
  );
}

String workshopId() => mockEventId(MockEventKeys.woodworkMorning, testDay);
String lunchId() => mockEventId(MockEventKeys.lunch, testDay);

const lena = MockParticipantIds.lena;
const jonas = MockParticipantIds.jonas;
const mia = MockParticipantIds.mia;
const elias = MockParticipantIds.elias;

/// Compact "kind title HH:MM" description of a feed for readable asserts.
List<String> describe(List<FeedEntry> entries) => [
      for (final e in entries)
        '${e.kind.name} ${e.event?.title ?? ''} '
                '${e.start.hour.toString().padLeft(2, '0')}:'
                '${e.start.minute.toString().padLeft(2, '0')}'
            .replaceAll('  ', ' '),
    ];
