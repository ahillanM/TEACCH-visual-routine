import 'package:flutter/material.dart';

import '../../core/logic/participant_day.dart';
import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../changes/plan_changed_banner.dart';
import 'participant_feed.dart';

/// Pure view of the participant's TODAY screen (header, change banner,
/// feed). Takes resolved data only, so staff preview renders exactly the
/// same widget with hypothetical data.
class ParticipantTodayView extends StatelessWidget {
  final ParticipantDay day;
  final GlobalKey<ParticipantFeedState>? feedKey;
  final VoidCallback? onOpenChanges;
  final void Function(FeedEntry entry)? onOpenDetails;
  final VoidCallback? onShowChanges;

  const ParticipantTodayView({
    super.key,
    required this.day,
    this.feedKey,
    this.onOpenChanges,
    this.onOpenDetails,
    this.onShowChanges,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayHeader(
          date: day.now,
          onNow: () => feedKey?.currentState?.scrollToNow(),
        ),
        if (day.hasPendingChanges)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
            child: PlanChangedBanner(onOpen: onOpenChanges),
          ),
        Expanded(
          child: ParticipantFeed(
            key: feedKey,
            entries: day.entries,
            now: day.now,
            onOpenDetails: onOpenDetails,
            onShowChanges: onShowChanges,
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback onNow;

  const _DayHeader({required this.date, required this.onNow});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.sm, AppSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Today',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                Text(
                  '${TimeFormat.longDate(date)} · ${TimeFormat.hm(date)}',
                  style: TextStyle(fontSize: 16, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onNow,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Now'),
          ),
        ],
      ),
    );
  }
}
