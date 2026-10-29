import 'package:flutter/material.dart';

import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';

/// "Next: Lunch at 11:30" – answers "what happens next?" on the NOW card.
class NextHint extends StatelessWidget {
  final ScheduledEvent next;

  const NextHint({super.key, required this.next});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right_rounded,
          color: palette.textSecondary,
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Next: ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: '${next.title} at ${TimeFormat.hm(next.start)}'),
              ],
            ),
            style: TextStyle(fontSize: 16, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}
