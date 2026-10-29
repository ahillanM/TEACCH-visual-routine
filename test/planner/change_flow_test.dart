import 'package:bbw_visual_routine/core/data/mock_library.dart';
import 'package:bbw_visual_routine/core/data/mock_participants.dart';
import 'package:bbw_visual_routine/core/logic/change_planner.dart';
import 'package:bbw_visual_routine/core/logic/impact_checker.dart';
import 'package:bbw_visual_routine/core/logic/participant_day.dart';
import 'package:bbw_visual_routine/core/models/change_event.dart';
import 'package:bbw_visual_routine/core/models/feed_entry.dart';
import 'package:bbw_visual_routine/core/models/scheduled_event.dart';
import 'package:bbw_visual_routine/core/state/schedule_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixtures.dart';

void main() {
  late ScheduleStore store;
  setUp(() => store = freshStore());

  PlannedChange cancelWorkshop(CancellationOption option) =>
      ChangePlanner.planCancellation(
        base: store.published,
        eventId: workshopId(),
        option: option,
        newId: () => 'evt-replacement',
      );

  void publish(PlannedChange plan) => store.publish(
        upserts: plan.upserts,
        publishedBy: 'Test staff',
        outcome: plan.outcome,
        cancelledEventId: plan.cancelled.id,
      );

  ParticipantDay dayOf(String pid, [DateTime? now]) =>
      ParticipantDay.resolve(store: store, participantId: pid, now: now ?? at(9, 40));

  group('cancellation → free time (core journey)', () {
    test('participant keeps the old plan until "I understand"', () {
      publish(cancelWorkshop(const FreeTimeInstead()));

      final before = dayOf(lena);
      expect(before.hasPendingChanges, isTrue);
      expect(before.current.event?.title, 'Woodwork Workshop',
          reason: 'cards must not rearrange before acknowledgement');

      final item = before.notice.items.single;
      expect(item.isCancellation, isTrue);
      expect(item.replacement, isNull);
      expect(item.freeTimeUntil, at(11, 30));
      expect(item.nextActivity?.title, 'Lunch');
      expect(item.nextActivityMoved, isFalse);
    });

    test('after acknowledging the feed shows Breakfast, Free time, Lunch', () {
      publish(cancelWorkshop(const FreeTimeInstead()));
      store.acknowledge(lena);

      final day = dayOf(lena);
      expect(day.hasPendingChanges, isFalse);
      expect(day.current.kind, FeedEntryKind.freeTime);
      expect(day.current.start, at(8, 50));
      expect(day.current.end, at(11, 30));

      final titles = describe(day.entries).take(5).toList();
      expect(titles, [
        'activity Breakfast 07:30',
        'waiting 08:15',
        'travelling Bus to BBW 08:30',
        'freeTime 08:50',
        'activity Lunch 11:30',
      ]);
    });

    test('the next activity is NOT pulled earlier automatically', () {
      final lunchBefore = store.published[lunchId()]!;
      publish(cancelWorkshop(const FreeTimeInstead()));
      final lunchAfter = store.published[lunchId()]!;
      expect(lunchAfter.start, lunchBefore.start);
      expect(lunchAfter.start, at(11, 30));
    });
  });

  test('cancellation → replacement activity takes the same slot', () {
    final quiet =
        mockLibraryActivities.firstWhere((a) => a.id == MockActivityIds.quietTime);
    publish(cancelWorkshop(ReplacementInstead(ScheduledEvent(
      id: 'evt-replacement',
      title: quiet.name,
      category: quiet.category,
      start: at(9),
      end: at(11),
      visual: quiet.visual,
    ))));

    final notice = dayOf(jonas).notice.items.single;
    expect(notice.replacement?.title, 'Quiet Time');
    expect(notice.nextActivity?.title, 'Lunch');

    store.acknowledge(jonas);
    final day = dayOf(jonas);
    expect(day.current.event?.title, 'Quiet Time');
    expect(day.current.event?.assignedParticipantIds,
        {lena, jonas, mia}, reason: 'replacement inherits the assignees');
    expect(store.published[lunchId()]!.start, at(11, 30));
  });

  test('moving the next activity earlier only happens when staff choose it', () {
    publish(cancelWorkshop(MoveActivityInstead(eventId: lunchId(), newStart: at(11))));
    final item = dayOf(mia).notice.items.single;
    expect(item.nextActivity?.title, 'Lunch');
    expect(item.nextActivityMoved, isTrue);
    expect(item.freeTimeUntil, at(11));
    expect(store.published[lunchId()]!.start, at(11));
  });

  test('a shared event change affects exactly its assigned participants', () {
    publish(cancelWorkshop(const FreeTimeInstead()));
    final change = store.changes.last;
    expect(change.affectedParticipantIds, {lena, jonas, mia});
    expect(change.outcome, ChangeOutcome.freeTime);

    expect(dayOf(lena).hasPendingChanges, isTrue);
    expect(dayOf(jonas).hasPendingChanges, isTrue);
    expect(dayOf(mia).hasPendingChanges, isTrue);
    expect(dayOf(elias).hasPendingChanges, isFalse,
        reason: 'Elias is in the metal workshop, not Workshop A');
  });

  test('drafts never reach the participant schedule', () {
    final workshop = store.published[workshopId()]!;
    store.saveDraft(workshop.copyWith(placeId: MockPlaceIds.room104));

    expect(store.published[workshopId()]!.placeId, MockPlaceIds.workshopA);
    expect(dayOf(lena).hasPendingChanges, isFalse);
    expect(dayOf(lena).current.event?.placeId, MockPlaceIds.workshopA);
    // Staff see the draft in their calendar.
    expect(store.staffEvent(workshopId())!.placeId, MockPlaceIds.room104);

    store.publishDrafts(publishedBy: 'Test staff');
    expect(dayOf(lena).notice.items.single.event.placeId, MockPlaceIds.room104);
  });

  test('impact check reports overlaps and unfamiliar places factually', () {
    final workshop = store.published[workshopId()]!;
    final moved = workshop.copyWith(
      start: at(11),
      end: at(12),
      placeId: MockPlaceIds.workshopB,
    );
    final report = ImpactChecker.evaluate(
      base: store.published,
      upserts: [moved],
      participants: {for (final p in mockParticipants) p.id: p},
      placeName: (id) => id ?? '',
      contactName: (id) => id ?? '',
    );
    expect(report.affectedParticipantIds, {lena, jonas, mia});
    expect(report.items.map((i) => i.kind), contains(ImpactKind.timeChanged));
    expect(report.items.map((i) => i.kind), contains(ImpactKind.locationChanged));
    expect(report.conflicts.where((i) => i.kind == ImpactKind.overlap),
        hasLength(3), reason: 'overlaps lunch for each participant');
    expect(report.items.where((i) => i.kind == ImpactKind.unfamiliarLocation),
        isNotEmpty);
  });
}
