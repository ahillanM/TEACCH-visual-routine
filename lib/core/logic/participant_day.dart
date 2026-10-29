import '../models/change_event.dart';
import '../models/feed_entry.dart';
import '../models/schedule_snapshot.dart';
import '../state/schedule_store.dart';
import 'change_notice_builder.dart';
import 'feed_builder.dart';

/// Everything needed to render one participant's day, resolved from the
/// schedule store. Used by the participant UI, the staff dashboard
/// (current / next activity) and "Preview as participant", so all three
/// always agree.
class ParticipantDay {
  final String participantId;
  final DateTime now;

  /// The feed the participant currently sees (last acknowledged version).
  final List<FeedEntry> entries;

  /// Changes waiting for "I understand".
  final List<ChangeEvent> pendingChanges;
  final ChangeNoticeData notice;

  /// The feed after acknowledging all pending changes.
  final List<FeedEntry> entriesAfterAcknowledging;

  const ParticipantDay._({
    required this.participantId,
    required this.now,
    required this.entries,
    required this.pendingChanges,
    required this.notice,
    required this.entriesAfterAcknowledging,
  });

  int get nowIndex => FeedBuilder.nowIndex(entries);
  FeedEntry get current => entries[nowIndex];
  bool get hasPendingChanges => notice.items.isNotEmpty;

  /// The next real (scheduled) activity after NOW, if any.
  FeedEntry? get nextActivity {
    for (var i = nowIndex + 1; i < entries.length; i++) {
      if (entries[i].event != null) return entries[i];
    }
    return null;
  }

  /// Resolves the live day for [participantId] from [store].
  factory ParticipantDay.resolve({
    required ScheduleStore store,
    required String participantId,
    required DateTime now,
  }) {
    return ParticipantDay.fromSnapshots(
      participantId: participantId,
      now: now,
      displayed: store.displayedSnapshotFor(participantId),
      latest: store.published,
      pendingChanges: store.pendingChangesFor(participantId),
    );
  }

  /// Builds a day from explicit snapshots. Used for previews of changes that
  /// are not published yet ([latest] is then a hypothetical snapshot).
  factory ParticipantDay.fromSnapshots({
    required String participantId,
    required DateTime now,
    required ScheduleSnapshot displayed,
    required ScheduleSnapshot latest,
    required List<ChangeEvent> pendingChanges,
  }) {
    final notice = ChangeNoticeBuilder.build(
      changes: pendingChanges,
      after: latest,
      participantId: participantId,
    );
    return ParticipantDay._(
      participantId: participantId,
      now: now,
      entries: FeedBuilder.build(
        events: displayed.activeEventsFor(participantId, now),
        now: now,
      ),
      pendingChanges: pendingChanges,
      notice: notice,
      entriesAfterAcknowledging: FeedBuilder.build(
        events: latest.activeEventsFor(participantId, now),
        now: now,
      ),
    );
  }
}
