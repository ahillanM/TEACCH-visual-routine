import 'package:flutter/material.dart';

import '../theme.dart';

/// A gentle, thick progress bar showing time passed through an activity.
///
/// It represents time, never performance. Changes animate slowly (or not at
/// all under reduced motion); it never flashes or turns red.
class CalmProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final String semanticLabel;

  const CalmProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.semanticLabel,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()} percent of the time has passed',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: AppMotion.of(context, AppMotion.standard),
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: height,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ),
    );
  }
}
