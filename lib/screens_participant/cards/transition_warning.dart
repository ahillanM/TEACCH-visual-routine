import 'package:flutter/material.dart';

import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';

/// Subtle notice shown on the NOW card shortly before it ends.
///
/// Thresholds come from the participant profile (none / 5 / 5-2-1 min).
/// No alarm styling, no flashing. Sound and vibration are stored as
/// preferences only in the prototype.
class TransitionWarning extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final List<int> thresholdsMinutes;

  const TransitionWarning({
    super.key,
    required this.entry,
    required this.now,
    required this.thresholdsMinutes,
  });

  /// The threshold currently reached, or null when no warning applies.
  static int? activeThreshold(
    FeedEntry entry,
    DateTime now,
    List<int> thresholdsMinutes,
  ) {
    final remaining = entry.remainingAt(now);
    if (remaining == null || thresholdsMinutes.isEmpty) return null;
    final left = remaining.inSeconds / 60;
    if (left <= 0) return null;
    final reached = thresholdsMinutes.where((t) => left <= t).toList()..sort();
    return reached.isEmpty ? null : reached.first;
  }

  @override
  Widget build(BuildContext context) {
    final minutes = activeThreshold(entry, now, thresholdsMinutes);
    if (minutes == null) return const SizedBox.shrink();
    final palette = context.palette;
    final next = entry.nextEvent;
    final unit = minutes == 1 ? 'minute' : 'minutes';

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, color: palette.accent),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                next == null
                    ? 'About $minutes $unit left.'
                    : 'About $minutes $unit left. '
                          'Then: ${next.title} at ${TimeFormat.hm(next.start)}.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
