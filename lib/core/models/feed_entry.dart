import 'scheduled_event.dart';

/// The kinds of cards the participant feed can show.
///
/// [freeTime], [waiting] and [dayFinished] are derived by `FeedBuilder` so
/// there is always a meaningful NOW and never an unexplained gap.
enum FeedEntryKind {
  activity,
  freeTime,
  waiting,
  preparing,
  travelling,
  dayFinished,
}

/// Where an entry sits relative to the current time.
enum TemporalState { done, now, next }

/// One card in the participant's daily feed.
class FeedEntry {
  final FeedEntryKind kind;
  final DateTime start;

  /// Null only for [FeedEntryKind.dayFinished], which is open-ended.
  final DateTime? end;
  final ScheduledEvent? event;
  final TemporalState state;

  /// The next scheduled (non-derived) event after this entry, for hints like
  /// "Next: Lunch at 11:30".
  final ScheduledEvent? nextEvent;

  const FeedEntry({
    required this.kind,
    required this.start,
    required this.state,
    this.end,
    this.event,
    this.nextEvent,
  });

  bool get isNow => state == TemporalState.now;
  bool get isDone => state == TemporalState.done;

  /// Stable key so the feed can keep scroll position across rebuilds.
  String get key => event?.id ?? '${kind.name}-${start.toIso8601String()}';

  /// Fraction of the entry's time that has passed, between 0 and 1.
  double progressAt(DateTime now) {
    final e = end;
    if (e == null) return 0;
    final total = e.difference(start).inSeconds;
    if (total <= 0) return 1;
    final passed = now.difference(start).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  Duration? remainingAt(DateTime now) {
    final e = end;
    if (e == null) return null;
    final left = e.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}
