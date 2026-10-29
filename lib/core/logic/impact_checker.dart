import '../models/change_event.dart';
import '../models/participant.dart';
import '../models/schedule_snapshot.dart';
import '../models/scheduled_event.dart';
import '../time/time_format.dart';
import 'change_factory.dart';

enum ImpactKind {
  cancelled,
  added,
  timeChanged,
  locationChanged,
  personChanged,
  overlap,
  unfamiliarLocation,
  noParticipants,
}

/// One factual consequence of a planned change.
///
/// Messages are deliberately descriptive ("This creates an overlap"), never
/// predictive or clinical ("this will upset …"). Decisions belong to staff.
class ImpactItem {
  final ImpactKind kind;
  final String message;
  final String? participantId;

  const ImpactItem(this.kind, this.message, {this.participantId});

  bool get isConflict =>
      kind == ImpactKind.overlap || kind == ImpactKind.noParticipants;
}

class ImpactReport {
  final List<ImpactItem> items;
  final Set<String> affectedParticipantIds;

  const ImpactReport({
    required this.items,
    required this.affectedParticipantIds,
  });

  List<ImpactItem> get conflicts => items.where((i) => i.isConflict).toList();
  bool get hasConflicts => items.any((i) => i.isConflict);
}

/// Deterministic checks for planned schedule changes.
abstract final class ImpactChecker {
  static ImpactReport evaluate({
    required ScheduleSnapshot base,
    required List<ScheduledEvent> upserts,
    required Map<String, Participant> participants,
    required String Function(String? placeId) placeName,
    required String Function(String? contactId) contactName,
  }) {
    final items = <ImpactItem>[];
    final after = base.applying(upserts);
    final affected = <String>{};

    String nameOf(String id) => participants[id]?.displayName ?? 'Unknown';

    for (final event in upserts) {
      final before = base[event.id];
      affected
        ..addAll(event.assignedParticipantIds)
        ..addAll(before?.assignedParticipantIds ?? const {});

      final aspects = ChangeFactory.diff(before, event);
      final label = '${event.title} (${TimeFormat.range(event.start, event.end)})';

      if (aspects.contains(ChangeAspect.cancelled)) {
        items.add(ImpactItem(ImpactKind.cancelled, '$label is cancelled.'));
      }
      if (aspects.contains(ChangeAspect.added)) {
        items.add(ImpactItem(ImpactKind.added, '$label is added.'));
      }
      if (aspects.contains(ChangeAspect.timeChanged) && before != null) {
        items.add(ImpactItem(
          ImpactKind.timeChanged,
          'Schedule time changed: ${event.title} moves from '
          '${TimeFormat.range(before.start, before.end)} to '
          '${TimeFormat.range(event.start, event.end)}.',
        ));
      }
      if (aspects.contains(ChangeAspect.locationChanged)) {
        items.add(ImpactItem(
          ImpactKind.locationChanged,
          'Location changed: ${event.title} is now in ${placeName(event.placeId)}.',
        ));
      }
      if (aspects.contains(ChangeAspect.personChanged)) {
        items.add(ImpactItem(
          ImpactKind.personChanged,
          'Person changed: ${event.title} is now with ${contactName(event.contactId)}.',
        ));
      }

      if (!event.isActive) continue;

      if (event.assignedParticipantIds.isEmpty) {
        items.add(ImpactItem(
          ImpactKind.noParticipants,
          'No participants are assigned to ${event.title}.',
        ));
      }

      final placeIsNew = before == null || before.placeId != event.placeId;
      for (final pid in event.assignedParticipantIds) {
        for (final other in after.activeEventsFor(pid, event.start)) {
          if (other.id == event.id || !other.overlaps(event)) continue;
          items.add(ImpactItem(
            ImpactKind.overlap,
            'This creates an overlap for ${nameOf(pid)}: ${event.title} and '
            '${other.title} (${TimeFormat.range(other.start, other.end)}).',
            participantId: pid,
          ));
        }
        final p = participants[pid];
        if (placeIsNew &&
            event.placeId != null &&
            p != null &&
            !p.familiarPlaceIds.contains(event.placeId)) {
          items.add(ImpactItem(
            ImpactKind.unfamiliarLocation,
            '${p.displayName} has not used ${placeName(event.placeId)} '
            'in the mock familiarity data.',
            participantId: pid,
          ));
        }
      }
    }

    return ImpactReport(items: items, affectedParticipantIds: affected);
  }

  /// All overlaps within a published snapshot on [day] (for the dashboard).
  static List<ImpactItem> conflictsOn({
    required ScheduleSnapshot snapshot,
    required DateTime day,
    required Map<String, Participant> participants,
  }) {
    final items = <ImpactItem>[];
    for (final p in participants.values) {
      final events = snapshot.activeEventsFor(p.id, day);
      for (var i = 0; i < events.length; i++) {
        for (var j = i + 1; j < events.length; j++) {
          if (events[i].overlaps(events[j])) {
            items.add(ImpactItem(
              ImpactKind.overlap,
              '${p.displayName}: ${events[i].title} overlaps ${events[j].title}.',
              participantId: p.id,
            ));
          }
        }
      }
    }
    return items;
  }
}
