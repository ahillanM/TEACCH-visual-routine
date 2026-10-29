import '../models/routine_template.dart';
import '../models/scheduled_event.dart';
import '../time/time_format.dart';

/// Turns a routine template into concrete (draft) events on a given day.
///
/// The template itself is never modified, so staff can customise the
/// generated events afterwards without affecting other participants.
abstract final class RoutineAssigner {
  static List<ScheduledEvent> instantiate({
    required RoutineTemplate template,
    required DateTime day,
    required Set<String> participantIds,
    required String Function() newId,
  }) {
    return [
      for (final step in template.steps)
        ScheduledEvent(
          id: newId(),
          title: step.title,
          category: step.category,
          kind: step.kind,
          start: TimeFormat.atMinuteOfDay(day, step.startMinuteOfDay),
          end: TimeFormat.atMinuteOfDay(
            day,
            step.startMinuteOfDay + step.durationMin,
          ),
          visual: step.visual,
          placeId: step.placeId,
          contactId: step.contactId,
          libraryActivityId: step.libraryActivityId,
          assignedParticipantIds: participantIds,
        ),
    ];
  }
}
