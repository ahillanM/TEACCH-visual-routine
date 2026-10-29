import 'package:flutter/material.dart';

import '../../core/logic/presentation_rules.dart';
import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/calm_progress_bar.dart';

/// Calm "time through the activity" indicator for the NOW card.
///
/// Shows a gentle bar and/or a rounded phrase ("About 20 min left") – never
/// a ticking countdown. Replace this widget to change timer behaviour.
class TimeProgress extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final Color color;
  final CardPresentation presentation;

  const TimeProgress({
    super.key,
    required this.entry,
    required this.now,
    required this.color,
    required this.presentation,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingAt(now);
    if (remaining == null) return const SizedBox.shrink();
    final phrase = TimeFormat.calmRemaining(remaining);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentation.showProgressBar)
          CalmProgressBar(
            value: entry.progressAt(now),
            color: color,
            semanticLabel: 'Time through this activity',
          ),
        if (presentation.showClockText) ...[
          if (presentation.showProgressBar) const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: palette.textSecondary),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  '$phrase · until ${TimeFormat.hm(entry.end!)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
