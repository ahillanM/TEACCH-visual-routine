import '../models/feed_entry.dart';
import '../models/scheduled_event.dart';

/// Turns a participant's published events for one day into a finite feed
/// with a guaranteed NOW.
///
/// Rules:
/// * Cancelled events are never shown as normal cards (change notices
///   explain them instead).
/// * Gaps are filled: short gaps become "Waiting", longer gaps "Free time".
/// * Events are never moved. A gap left by a cancellation stays a gap until
///   the next activity's own start time.
/// * The feed always ends with a "day finished" entry.
abstract final class FeedBuilder {
  /// Gaps up to this length are shown as "Waiting" rather than "Free time".
  static const Duration maxWaitingGap = Duration(minutes: 15);

  static List<FeedEntry> build({
    required Iterable<ScheduledEvent> events,
    required DateTime now,
  }) {
    final sorted = events.where((e) => e.isActive).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final drafts = <_Draft>[];

    // Before the first activity the participant is "waiting for the day".
    if (sorted.isNotEmpty && now.isBefore(sorted.first.start)) {
      final startOfDay = DateTime(now.year, now.month, now.day);
      drafts.add(_Draft(FeedEntryKind.waiting, startOfDay, sorted.first.start));
    }

    DateTime? cursor;
    for (final event in sorted) {
      if (cursor != null && event.start.isAfter(cursor)) {
        final gap = event.start.difference(cursor);
        drafts.add(_Draft(
          gap <= maxWaitingGap ? FeedEntryKind.waiting : FeedEntryKind.freeTime,
          cursor,
          event.start,
        ));
      }
      drafts.add(_Draft(_kindFor(event), event.start, event.end, event));
      if (cursor == null || event.end.isAfter(cursor)) cursor = event.end;
    }

    drafts.add(_Draft(FeedEntryKind.dayFinished, cursor ?? now, null));

    // Assign temporal state; guarantee exactly one NOW.
    final entries = <FeedEntry>[];
    var nowAssigned = false;
    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      var state = _stateFor(d, now);
      if (state == TemporalState.now) {
        if (nowAssigned) state = TemporalState.next;
        nowAssigned = true;
      }
      entries.add(FeedEntry(
        kind: d.kind,
        start: d.start,
        end: d.end,
        event: d.event,
        state: state,
        nextEvent: _nextEventAfter(drafts, i),
      ));
    }
    return entries;
  }

  /// Index of the NOW entry. Always valid because the feed ends with an
  /// open-ended "day finished" entry.
  static int nowIndex(List<FeedEntry> entries) {
    final i = entries.indexWhere((e) => e.isNow);
    return i < 0 ? entries.length - 1 : i;
  }

  static FeedEntryKind _kindFor(ScheduledEvent e) => switch (e.kind) {
        EventKind.activity => FeedEntryKind.activity,
        EventKind.travel => FeedEntryKind.travelling,
        EventKind.preparing => FeedEntryKind.preparing,
        EventKind.waiting => FeedEntryKind.waiting,
      };

  static TemporalState _stateFor(_Draft d, DateTime now) {
    if (now.isBefore(d.start)) return TemporalState.next;
    final end = d.end;
    if (end == null || now.isBefore(end)) return TemporalState.now;
    return TemporalState.done;
  }

  static ScheduledEvent? _nextEventAfter(List<_Draft> drafts, int index) {
    for (var j = index + 1; j < drafts.length; j++) {
      final e = drafts[j].event;
      if (e != null) return e;
    }
    return null;
  }
}

class _Draft {
  final FeedEntryKind kind;
  final DateTime start;
  final DateTime? end;
  final ScheduledEvent? event;
  _Draft(this.kind, this.start, this.end, [this.event]);
}
