import 'package:flutter/material.dart';

import '../../core/models/activity_category.dart';
import '../../core/models/feed_entry.dart';
import '../../core/models/visual_ref.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../participant_presentation_scope.dart';
import 'card_frame.dart';
import 'next_hint.dart';
import 'time_progress.dart';

/// "Nothing is required right now." Staff never fill free time with tasks;
/// participants may add their own activities with [onAdd].
class FreeTimeCard extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final bool isImmediateNext;

  /// Opens "Add to my free time". Null hides the button (e.g. staff preview).
  final VoidCallback? onAdd;

  const FreeTimeCard({
    super.key,
    required this.entry,
    required this.now,
    this.isImmediateNext = false,
    this.onAdd,
  });

  static const _visual = VisualRef.arasaac('free', 11653);

  @override
  Widget build(BuildContext context) {
    final presentation = ParticipantPresentationScope.of(context);
    final style = CategoryStyle.of(ActivityCategory.freeTime, context.palette);
    final until = entry.end;
    final timeText = until == null ? '' : 'Until ${TimeFormat.hm(until)}';

    return CardFrame(
      entry: entry,
      accent: style.color,
      categoryIcon: style.icon,
      categoryLabel: style.label,
      isImmediateNext: isImmediateNext,
      semanticSummary: 'Free time. $timeText. Nothing is required.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityVisual(
            visual: _visual,
            accent: style.color,
            semanticLabel: 'Free Time',
            height: entry.isNow ? 150 : 110,
            showPhoto: presentation.showPhoto,
            showSymbol: presentation.showSymbol,
            desaturate: entry.isDone,
          ),
          const SizedBox(height: AppSpace.md),
          CardHeadline(
            title: 'Free Time',
            timeText: timeText,
            emphasised: entry.isNow,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Nothing is required right now.',
            style: TextStyle(
              fontSize: 17,
              color: context.palette.textSecondary,
            ),
          ),
          if (entry.isNow) ...[
            const SizedBox(height: AppSpace.lg),
            TimeProgress(
              entry: entry,
              now: now,
              color: style.color,
              presentation: presentation,
            ),
            if (entry.nextEvent != null) ...[
              const SizedBox(height: AppSpace.sm),
              NextHint(next: entry.nextEvent!),
            ],
          ],
          if (onAdd != null) ...[
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: kLargeTouchTarget,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add Something to Do'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
