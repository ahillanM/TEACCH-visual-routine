import '../models/change_event.dart';
import '../models/library_items.dart';
import '../models/schedule_snapshot.dart';
import '../models/scheduled_event.dart';

/// What staff chose to happen instead of a cancelled activity.
sealed class CancellationOption {
  const CancellationOption();
  ChangeOutcome get outcome;
}

/// Case B: nothing is required – the gap becomes Free Time.
class FreeTimeInstead extends CancellationOption {
  const FreeTimeInstead();
  @override
  ChangeOutcome get outcome => ChangeOutcome.freeTime;
}

/// Case A: staff assign a replacement activity.
class ReplacementInstead extends CancellationOption {
  final ScheduledEvent replacement;
  const ReplacementInstead(this.replacement);
  @override
  ChangeOutcome get outcome => ChangeOutcome.replacement;
}

/// Case C: staff explicitly move another activity (e.g. lunch earlier).
class MoveActivityInstead extends CancellationOption {
  final String eventId;
  final DateTime newStart;
  const MoveActivityInstead({required this.eventId, required this.newStart});
  @override
  ChangeOutcome get outcome => ChangeOutcome.movedActivity;
}

/// Use the predefined Plan B activity from the library.
class PlanBInstead extends CancellationOption {
  final LibraryActivity planB;
  const PlanBInstead(this.planB);
  @override
  ChangeOutcome get outcome => ChangeOutcome.planB;
}

/// The concrete event updates that implement a cancellation decision.
class PlannedChange {
  final ScheduledEvent cancelled;
  final ChangeOutcome outcome;
  final List<ScheduledEvent> upserts;

  const PlannedChange({
    required this.cancelled,
    required this.outcome,
    required this.upserts,
  });
}

/// Translates a staff decision into event updates. Pure: nothing is
/// published here.
///
/// IMPORTANT: no other event is ever moved unless staff explicitly chose
/// [MoveActivityInstead]. The next activity keeps its own start time.
abstract final class ChangePlanner {
  static PlannedChange planCancellation({
    required ScheduleSnapshot base,
    required String eventId,
    required CancellationOption option,
    required String Function() newId,
  }) {
    final original = base[eventId];
    if (original == null) {
      throw ArgumentError('Unknown event $eventId');
    }
    final cancelled = original.copyWith(status: EventStatus.cancelled);
    final upserts = <ScheduledEvent>[cancelled];

    switch (option) {
      case FreeTimeInstead():
        break;
      case ReplacementInstead(:final replacement):
        upserts.add(replacement.copyWith(
          assignedParticipantIds: replacement.assignedParticipantIds.isEmpty
              ? original.assignedParticipantIds
              : replacement.assignedParticipantIds,
          replacesEventId: original.id,
        ));
      case MoveActivityInstead(:final eventId, :final newStart):
        final moved = base[eventId];
        if (moved == null) throw ArgumentError('Unknown event $eventId');
        upserts.add(moved.copyWith(
          start: newStart,
          end: newStart.add(moved.duration),
        ));
      case PlanBInstead(:final planB):
        upserts.add(ScheduledEvent(
          id: newId(),
          title: planB.name,
          category: planB.category,
          start: original.start,
          end: original.end,
          visual: planB.visual,
          placeId: planB.defaultPlaceId,
          contactId: planB.defaultContactId,
          whatToBring: planB.whatToBring,
          instructions: planB.instructions,
          assignedParticipantIds: original.assignedParticipantIds,
          libraryActivityId: planB.id,
          replacesEventId: original.id,
        ));
    }

    return PlannedChange(
      cancelled: cancelled,
      outcome: option.outcome,
      upserts: upserts,
    );
  }
}
