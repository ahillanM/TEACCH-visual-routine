import 'activity_category.dart';
import 'task_color.dart';
import 'visual_ref.dart';

/// What kind of time block an event is. Free time is not an event kind:
/// the participant feed derives it from gaps (see `FeedBuilder`).
enum EventKind { activity, travel, preparing, waiting }

enum EventStatus { active, cancelled }

/// One organisational event. A single event can be assigned to several
/// participants; changing it once affects every assigned schedule.
///
/// Events are immutable. Edits produce a new instance via [copyWith] that is
/// stored as a draft until staff publish it.
class ScheduledEvent {
  final String id;
  final String title;
  final ActivityCategory category;
  final EventKind kind;
  final DateTime start;
  final DateTime end;
  final String? placeId;
  final String? contactId;
  final VisualRef visual;
  final List<String> whatToBring;
  final String? instructions;
  final Set<String> assignedParticipantIds;
  final EventStatus status;
  final String? libraryActivityId;

  /// Library activity used when staff choose "Use predefined Plan B".
  final String? planBActivityId;

  /// Minutes before start at which the participant gets a reminder.
  /// Null means "use the participant's profile default".
  final int? reminderMinutesBefore;

  /// Set when this event was created to replace a cancelled one.
  final String? replacesEventId;

  /// Colour chosen by staff so participants recognise the task. Optional.
  final TaskColor? color;

  /// Set when a participant added this to their own free time.
  final String? createdByParticipantId;

  const ScheduledEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.start,
    required this.end,
    required this.visual,
    this.kind = EventKind.activity,
    this.placeId,
    this.contactId,
    this.whatToBring = const [],
    this.instructions,
    this.assignedParticipantIds = const {},
    this.status = EventStatus.active,
    this.libraryActivityId,
    this.planBActivityId,
    this.reminderMinutesBefore,
    this.replacesEventId,
    this.color,
    this.createdByParticipantId,
  });

  bool get isCancelled => status == EventStatus.cancelled;
  bool get isActive => status == EventStatus.active;
  bool get isParticipantOwned => createdByParticipantId != null;
  Duration get duration => end.difference(start);

  bool isAssignedTo(String participantId) =>
      assignedParticipantIds.contains(participantId);

  bool overlaps(ScheduledEvent other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  bool occursOn(DateTime day) =>
      start.year == day.year &&
      start.month == day.month &&
      start.day == day.day;

  ScheduledEvent copyWith({
    String? id,
    String? title,
    ActivityCategory? category,
    EventKind? kind,
    DateTime? start,
    DateTime? end,
    String? placeId,
    String? contactId,
    VisualRef? visual,
    List<String>? whatToBring,
    String? instructions,
    Set<String>? assignedParticipantIds,
    EventStatus? status,
    String? libraryActivityId,
    String? planBActivityId,
    int? reminderMinutesBefore,
    String? replacesEventId,
    TaskColor? color,
    bool clearPlace = false,
    bool clearContact = false,
    bool clearColor = false,
  }) {
    return ScheduledEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      kind: kind ?? this.kind,
      start: start ?? this.start,
      end: end ?? this.end,
      placeId: clearPlace ? null : (placeId ?? this.placeId),
      contactId: clearContact ? null : (contactId ?? this.contactId),
      visual: visual ?? this.visual,
      whatToBring: whatToBring ?? this.whatToBring,
      instructions: instructions ?? this.instructions,
      assignedParticipantIds:
          assignedParticipantIds ?? this.assignedParticipantIds,
      status: status ?? this.status,
      libraryActivityId: libraryActivityId ?? this.libraryActivityId,
      planBActivityId: planBActivityId ?? this.planBActivityId,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      replacesEventId: replacesEventId ?? this.replacesEventId,
      color: clearColor ? null : (color ?? this.color),
      createdByParticipantId: createdByParticipantId,
    );
  }
}
