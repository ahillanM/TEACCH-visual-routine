import 'package:flutter/material.dart';

import '../../core/models/feed_entry.dart';
import '../../theme.dart';
import 'card_frame.dart';

/// The clear end of the day. The feed is finite – nothing comes after this.
class DayFinishedCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onShowChanges;

  /// Opens "Plan my free time" for the rest of the day.
  final VoidCallback? onPlan;

  const DayFinishedCard(
      {super.key, required this.entry, this.onShowChanges, this.onPlan});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CardFrame(
      entry: entry,
      accent: palette.textSecondary,
      categoryIcon: Icons.nights_stay_outlined,
      categoryLabel: 'End of Day',
      semanticSummary: "That's everything planned for today.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.nights_stay_outlined,
            size: 56,
            color: palette.textSecondary,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            "That's everything planned for today.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Nothing else is planned. You can rest.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: palette.textSecondary),
          ),
          if (onPlan != null) ...[
            const SizedBox(height: AppSpace.md),
            FilledButton.tonalIcon(
              onPressed: onPlan,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Plan my free time'),
            ),
          ],
          if (onShowChanges != null) ...[
            const SizedBox(height: AppSpace.md),
            TextButton.icon(
              onPressed: onShowChanges,
              icon: const Icon(Icons.history_rounded),
              label: const Text("Today's plan changes"),
            ),
          ],
        ],
      ),
    );
  }
}
