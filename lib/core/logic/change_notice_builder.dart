import '../models/change_event.dart';
import '../models/schedule_snapshot.dart';
import '../models/scheduled_event.dart';

/// What the participant sees for one changed event in "Your plan has changed".
class ChangeNoticeItem {
  /// The event as the participant knew it before the change.
  final ScheduledEvent? before;

  /// The event after the change (null if it was cancelled).
  final ScheduledEvent? after;
  final Set<ChangeAspect> aspects;

  /// For cancellations: the activity that now happens instead, if any.
  final ScheduledEvent? replacement;

  /// For cancellations without replacement: free time lasts until here.
  final DateTime? freeTimeUntil;

  /// The next activity after the cancelled one, with its (unchanged or
  /// staff-moved) start time – "Lunch still starts at 11:30".
  final ScheduledEvent? nextActivity;

  /// True when staff explicitly moved [nextActivity] as part of this change.
  final bool nextActivityMoved;

  const ChangeNoticeItem({
    required this.aspects,
    this.before,
    this.after,
    this.replacement,
    this.freeTimeUntil,
    this.nextActivity,
    this.nextActivityMoved = false,
  });

  bool get isCancellation => aspects.contains(ChangeAspect.cancelled);
  bool get isAddition =>
      aspects.contains(ChangeAspect.added) && before == null;
  ScheduledEvent get event => (after ?? before)!;
}

class ChangeNoticeData {
  final List<ChangeNoticeItem> items;
  const ChangeNoticeData(this.items);
  bool get isEmpty => items.isEmpty;
}

/// Builds the participant-facing explanation of pending changes.
///
/// Replacements created as part of a cancellation are folded into the
/// cancellation item ("Instead: …") instead of being listed separately.
abstract final class ChangeNoticeBuilder {
  static ChangeNoticeData build({
    required List<ChangeEvent> changes,
    required ScheduleSnapshot after,
    required String participantId,
  }) {
    final items = <ChangeNoticeItem>[];

    for (final change in changes) {
      final relevant = change.changesFor(participantId);
      final consumed = <String>{};

      for (final ec in relevant) {
        if (!ec.aspects.contains(ChangeAspect.cancelled)) continue;
        final original = ec.before ?? ec.after!;
        final dayEvents = after.activeEventsFor(participantId, original.start);

        ScheduledEvent? replacement;
        for (final e in dayEvents) {
          if (e.replacesEventId == original.id) replacement = e;
        }
        if (replacement != null) consumed.add(replacement.id);

        final movedIds = {
          for (final m in relevant)
            if (m.aspects.contains(ChangeAspect.timeChanged)) m.eventId,
        };

        // The next activity is the one staff explicitly moved, otherwise the
        // first activity at/after the cancelled slot – at its own start time.
        final moved =
            dayEvents.where((e) => movedIds.contains(e.id)).firstOrNull;
        final next = moved ??
            dayEvents
                .where((e) =>
                    e.id != replacement?.id &&
                    !e.start.isBefore(original.start))
                .firstOrNull;
        final nextMoved = moved != null;
        if (moved != null) consumed.add(moved.id);

        items.add(ChangeNoticeItem(
          before: original,
          aspects: ec.aspects,
          replacement: replacement,
          freeTimeUntil: replacement == null ? next?.start : null,
          nextActivity: next,
          nextActivityMoved: nextMoved,
        ));
        consumed.add(original.id);
      }

      for (final ec in relevant) {
        if (consumed.contains(ec.eventId)) continue;
        // An event the participant was removed from reads like a cancellation.
        final removed = ec.before != null &&
            ec.before!.isAssignedTo(participantId) &&
            !(ec.after?.isAssignedTo(participantId) ?? false);
        items.add(ChangeNoticeItem(
          before: ec.before,
          after: removed ? null : ec.after,
          aspects: removed ? {ChangeAspect.cancelled} : ec.aspects,
        ));
      }
    }

    items.sort((a, b) => a.event.start.compareTo(b.event.start));
    return ChangeNoticeData(items);
  }
}
