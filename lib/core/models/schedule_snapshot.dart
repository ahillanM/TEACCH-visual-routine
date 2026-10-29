import 'scheduled_event.dart';

/// Publication state of schedule information.
///
/// Participants only ever receive [published] information. Drafts live
/// separately in `ScheduleStore` until staff publish them.
enum ScheduleStatus { draft, published }

/// An immutable, versioned view of all published events.
///
/// Every publish creates a new snapshot. Keeping old versions lets the
/// participant keep seeing the version they last acknowledged until they
/// confirm a change ("changes are explained, not silently applied").
class ScheduleSnapshot {
  final int version;
  final DateTime publishedAt;
  final Map<String, ScheduledEvent> events;

  const ScheduleSnapshot({
    required this.version,
    required this.publishedAt,
    required this.events,
  });

  ScheduledEvent? operator [](String id) => events[id];

  /// Returns a new snapshot with [upserts] replacing or adding events.
  /// Used both for real publishes and for "what if" previews.
  ScheduleSnapshot applying(
    Iterable<ScheduledEvent> upserts, {
    int? version,
    DateTime? publishedAt,
  }) {
    final next = Map<String, ScheduledEvent>.of(events);
    for (final e in upserts) {
      next[e.id] = e;
    }
    return ScheduleSnapshot(
      version: version ?? this.version,
      publishedAt: publishedAt ?? this.publishedAt,
      events: Map.unmodifiable(next),
    );
  }

  /// Active (not cancelled) events for one participant on one day, sorted.
  List<ScheduledEvent> activeEventsFor(String participantId, DateTime day) {
    return eventsOn(day)
        .where((e) => e.isActive && e.isAssignedTo(participantId))
        .toList();
  }

  /// All events (including cancelled) on [day], sorted by start time.
  List<ScheduledEvent> eventsOn(DateTime day) {
    final list = events.values.where((e) => e.occursOn(day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }
}
