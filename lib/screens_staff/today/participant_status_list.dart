import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/participant_day.dart';
import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';
import '../common/staff_widgets.dart';

/// Today's participants: current activity, next activity, schedule status.
class ParticipantStatusList extends StatelessWidget {
  const ParticipantStatusList({super.key});

  static String describe(FeedEntry entry) => switch (entry.kind) {
        FeedEntryKind.freeTime => 'Free time',
        FeedEntryKind.waiting => 'Waiting',
        FeedEntryKind.dayFinished => 'Day finished',
        _ => entry.event?.title ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final now = services.clock.now();
    final palette = context.palette;

    return SectionCard(
      title: "Today's participants",
      child: Column(
        children: [
          for (final p in services.participants.all)
            Builder(builder: (context) {
              final day = ParticipantDay.resolve(
                store: services.schedule,
                participantId: p.id,
                now: now,
              );
              final next = day.nextActivity;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ParticipantAvatar(participant: p),
                title: Text(p.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  'Now: ${describe(day.current)}'
                  '${next == null ? '' : ' · Next: ${next.event!.title} ${TimeFormat.hm(next.start)}'}',
                ),
                trailing: day.hasPendingChanges
                    ? StatusBadge(
                        label: 'Change not seen',
                        icon: Icons.mark_chat_unread_outlined,
                        color: palette.changeText,
                        fontSize: 11,
                      )
                    : StatusBadge(
                        label: 'Up to date',
                        icon: Icons.check_rounded,
                        color: palette.success,
                        fontSize: 11,
                      ),
              );
            }),
        ],
      ),
    );
  }
}
