import '../models/change_event.dart';
import '../models/schedule_snapshot.dart';
import '../models/scheduled_event.dart';

/// Builds [ChangeEvent]s by comparing events before and after a publish.
///
/// Pure and deterministic so it can be used for real publishes and for
/// unpublished previews alike.
abstract final class ChangeFactory {
  static ChangeEvent create({
    required String id,
    required ScheduleSnapshot base,
    required List<ScheduledEvent> upserts,
    required int version,
    required DateTime publishedAt,
    required String publishedBy,
    ChangeOutcome outcome = ChangeOutcome.none,
    String? cancelledEventId,
  }) {
    final changes = <EventChange>[];
    for (final after in upserts) {
      final before = base[after.id];
      final aspects = diff(before, after);
      if (aspects.isEmpty) continue;
      changes.add(EventChange(before: before, after: after, aspects: aspects));
    }
    return ChangeEvent(
      id: id,
      version: version,
      publishedAt: publishedAt,
      publishedBy: publishedBy,
      outcome: outcome,
      eventChanges: changes,
      cancelledEventId: cancelledEventId,
    );
  }

  /// The participant-relevant differences between two versions of an event.
  static Set<ChangeAspect> diff(ScheduledEvent? before, ScheduledEvent after) {
    if (before == null) {
      return after.isActive ? {ChangeAspect.added} : {};
    }
    if (!before.isCancelled && after.isCancelled) {
      return {ChangeAspect.cancelled};
    }
    final aspects = <ChangeAspect>{};
    if (before.isCancelled && after.isActive) aspects.add(ChangeAspect.added);
    if (before.start != after.start || before.end != after.end) {
      aspects.add(ChangeAspect.timeChanged);
    }
    if (before.placeId != after.placeId) {
      aspects.add(ChangeAspect.locationChanged);
    }
    if (before.contactId != after.contactId) {
      aspects.add(ChangeAspect.personChanged);
    }
    if (before.title != after.title ||
        before.instructions != after.instructions ||
        before.whatToBring.join('|') != after.whatToBring.join('|') ||
        before.assignedParticipantIds.length !=
            after.assignedParticipantIds.length ||
        !before.assignedParticipantIds
            .containsAll(after.assignedParticipantIds)) {
      aspects.add(ChangeAspect.detailsChanged);
    }
    return aspects;
  }
}
