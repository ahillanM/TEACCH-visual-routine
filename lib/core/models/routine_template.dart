import 'activity_category.dart';
import 'scheduled_event.dart';
import 'visual_ref.dart';

/// One step of a routine template, defined relative to the day (not a date).
class RoutineStep {
  final String title;
  final ActivityCategory category;
  final EventKind kind;
  final int startMinuteOfDay;
  final int durationMin;
  final VisualRef visual;
  final String? libraryActivityId;
  final String? placeId;
  final String? contactId;

  const RoutineStep({
    required this.title,
    required this.category,
    required this.startMinuteOfDay,
    required this.durationMin,
    required this.visual,
    this.kind = EventKind.activity,
    this.libraryActivityId,
    this.placeId,
    this.contactId,
  });

  RoutineStep copyWith({
    String? title,
    int? startMinuteOfDay,
    int? durationMin,
  }) {
    return RoutineStep(
      title: title ?? this.title,
      category: category,
      kind: kind,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      durationMin: durationMin ?? this.durationMin,
      visual: visual,
      libraryActivityId: libraryActivityId,
      placeId: placeId,
      contactId: contactId,
    );
  }
}

/// A reusable routine module (e.g. "Standard training day").
///
/// Templates are kept separate from schedule instances: assigning a template
/// creates new draft [ScheduledEvent]s that can be customised afterwards
/// without changing the template.
class RoutineTemplate {
  final String id;
  final String name;
  final String description;
  final List<RoutineStep> steps;

  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
  });

  RoutineTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<RoutineStep>? steps,
  }) {
    return RoutineTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
    );
  }
}
