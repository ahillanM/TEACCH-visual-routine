import 'package:bbw_visual_routine/core/logic/feed_builder.dart';
import 'package:bbw_visual_routine/core/models/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixtures.dart';

void main() {
  final store = freshStore();
  List<FeedEntry> feedAt(DateTime now) => FeedBuilder.build(
        events: store.published.activeEventsFor(lena, now),
        now: now,
      );

  test('identifies the activity happening NOW', () {
    final feed = feedAt(at(9, 40));
    final now = feed[FeedBuilder.nowIndex(feed)];
    expect(now.event?.title, 'Woodwork Workshop');
    expect(feed.where((e) => e.isNow), hasLength(1));
    expect(feed.first.state, TemporalState.done); // breakfast
    expect(feed.last.kind, FeedEntryKind.dayFinished);
  });

  test('gaps become meaningful states, so there is always a NOW', () {
    // 11:00–11:30 has no activity → free time; 08:15–08:30 → waiting.
    final feed = feedAt(at(11, 10));
    final now = feed[FeedBuilder.nowIndex(feed)];
    expect(now.kind, FeedEntryKind.freeTime);
    expect(now.end, at(11, 30));
    expect(now.nextEvent?.title, 'Lunch');

    final early = feedAt(at(8, 20));
    expect(early[FeedBuilder.nowIndex(early)].kind, FeedEntryKind.waiting);
  });

  test('before the first activity the participant is waiting for the day', () {
    final feed = feedAt(at(6, 30));
    expect(feed.first.kind, FeedEntryKind.waiting);
    expect(feed.first.isNow, isTrue);
    expect(feed.first.nextEvent?.title, 'Breakfast');
  });

  test('after the last activity NOW is the day-finished entry', () {
    final feed = feedAt(at(23, 0));
    final now = feed[FeedBuilder.nowIndex(feed)];
    expect(now.kind, FeedEntryKind.dayFinished);
    expect(feed.where((e) => e.isDone), hasLength(feed.length - 1));
  });
}
