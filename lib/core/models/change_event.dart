import 'scheduled_event.dart';

/// Which aspect of an event changed between two published versions.
enum ChangeAspect {
  added,
  cancelled,
  timeChanged,
  locationChanged,
  personChanged,
  detailsChanged,
}

/// What staff decided should happen instead of a cancelled activity.
///
/// The app never decides this automatically – in particular it never pulls
/// the next activity earlier unless staff chose [movedActivity].
enum ChangeOutcome { none, freeTime, replacement, movedActivity, planB }

/// The before/after pair for one event in a published change.
class EventChange {
  final ScheduledEvent? before;
  final ScheduledEvent? after;
  final Set<ChangeAspect> aspects;

  const EventChange({this.before, this.after, required this.aspects});

  String get eventId => (after ?? before)!.id;

  /// Participants who had or now have this event.
  Set<String> get participantIds => {
        ...?before?.assignedParticipantIds,
        ...?after?.assignedParticipantIds,
      };

  bool affects(String participantId) => participantIds.contains(participantId);
}

/// A published change: one decision by staff, possibly touching several
/// events (e.g. cancel the workshop + move lunch earlier) and several
/// participants. Each participant acknowledges it individually.
class ChangeEvent {
  final String id;

  /// Snapshot version this change produced.
  final int version;
  final DateTime publishedAt;
  final String publishedBy;
  final ChangeOutcome outcome;
  final List<EventChange> eventChanges;

  /// Id of the cancelled event this change was about, if any.
  final String? cancelledEventId;

  const ChangeEvent({
    required this.id,
    required this.version,
    required this.publishedAt,
    required this.publishedBy,
    required this.outcome,
    required this.eventChanges,
    this.cancelledEventId,
  });

  Set<String> get affectedParticipantIds =>
      {for (final c in eventChanges) ...c.participantIds};

  bool affects(String participantId) =>
      eventChanges.any((c) => c.affects(participantId));

  List<EventChange> changesFor(String participantId) =>
      eventChanges.where((c) => c.affects(participantId)).toList();
}
