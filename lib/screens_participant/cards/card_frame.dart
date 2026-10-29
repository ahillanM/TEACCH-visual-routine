import 'package:flutter/material.dart';

import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';

/// Shared frame for every participant feed card.
///
/// Gives all cards the same structure and temporal styling:
/// * NOW  – strongest border + filled "Now" label
/// * DONE – muted surface, "Done" label, still readable and tappable
/// * NEXT – normal appearance, "Next"/"Later" label
///
/// Card types only provide their content, so a new card type cannot drift
/// from the shared layout.
class CardFrame extends StatelessWidget {
  final FeedEntry entry;
  final Color accent;
  final IconData categoryIcon;
  final String categoryLabel;
  final bool isImmediateNext;
  final String semanticSummary;
  final VoidCallback? onTap;
  final Widget child;

  const CardFrame({
    super.key,
    required this.entry,
    required this.accent,
    required this.categoryIcon,
    required this.categoryLabel,
    required this.semanticSummary,
    required this.child,
    this.isImmediateNext = false,
    this.onTap,
  });

  static const double nowBorderWidth = 3;
  static const double defaultBorderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isNow = entry.isNow;
    final isDone = entry.isDone;

    final borderColor = isNow ? palette.nowAccent : palette.border;
    final background = isDone ? palette.doneSurface : palette.surface;

    return Semantics(
      container: true,
      button: onTap != null,
      label: '${TemporalLabel.textFor(entry.state, isImmediateNext)}. '
          '$semanticSummary',
      child: AnimatedContainer(
        duration: AppMotion.of(context),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: borderColor,
            width: isNow ? nowBorderWidth : defaultBorderWidth,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        TemporalLabel(
                          state: entry.state,
                          isImmediateNext: isImmediateNext,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              label: categoryLabel,
                              icon: categoryIcon,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          TimeFormat.hm(entry.start),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Now" / "Done" / "Next" / "Later" label with icon – never colour alone.
class TemporalLabel extends StatelessWidget {
  final TemporalState state;
  final bool isImmediateNext;

  const TemporalLabel({
    super.key,
    required this.state,
    this.isImmediateNext = false,
  });

  static String textFor(TemporalState state, bool isImmediateNext) =>
      switch (state) {
        TemporalState.now => 'Now',
        TemporalState.done => 'Done',
        TemporalState.next => isImmediateNext ? 'Next' : 'Later',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = textFor(state, isImmediateNext);
    return switch (state) {
      TemporalState.now => StatusBadge(
          label: text,
          icon: Icons.radio_button_checked_rounded,
          color: palette.nowAccent,
          filled: true,
          fontSize: 15,
        ),
      TemporalState.done => StatusBadge(
          label: text,
          icon: Icons.check_rounded,
          color: palette.textSecondary,
        ),
      TemporalState.next => StatusBadge(
          label: text,
          icon: Icons.arrow_downward_rounded,
          color: palette.textSecondary,
        ),
    };
  }
}

/// Title + time block used by every card.
class CardHeadline extends StatelessWidget {
  final String title;
  final String timeText;
  final bool emphasised;

  const CardHeadline({
    super.key,
    required this.title,
    required this.timeText,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (emphasised
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.titleLarge)
              ?.copyWith(height: 1.2),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          timeText,
          style: theme.textTheme.titleMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
