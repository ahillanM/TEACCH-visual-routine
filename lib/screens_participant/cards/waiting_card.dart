import 'package:flutter/material.dart';

import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import 'card_frame.dart';
import 'next_hint.dart';

/// Compact card for short transitions: WAITING (derived gap or before the
/// day starts) and PREPARING (staff-planned "get ready" time).
class WaitingCard extends StatelessWidget {
  final FeedEntry entry;
  final bool isImmediateNext;
  final VoidCallback? onTap;

  const WaitingCard({
    super.key,
    required this.entry,
    this.isImmediateNext = false,
    this.onTap,
  });

  bool get _isPreparing => entry.kind == FeedEntryKind.preparing;

  String get _title {
    if (entry.event != null) return entry.event!.title;
    if (_isPreparing) return 'Get ready';
    final next = entry.nextEvent;
    if (next != null && entry.start.hour == 0 && entry.start.minute == 0) {
      return 'Your day starts at ${TimeFormat.hm(next.start)}';
    }
    return 'Short wait';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final next = entry.nextEvent;
    final icon =
        _isPreparing ? Icons.checklist_rounded : Icons.hourglass_empty_rounded;
    final label = _isPreparing ? 'Preparing' : 'Waiting';
    final timeText = entry.end == null ? '' : 'Until ${TimeFormat.hm(entry.end!)}';

    return CardFrame(
      entry: entry,
      accent: palette.textSecondary,
      categoryIcon: icon,
      categoryLabel: label,
      isImmediateNext: isImmediateNext,
      onTap: onTap,
      semanticSummary: '$_title. $timeText.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 34, color: palette.textSecondary),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardHeadline(title: _title, timeText: timeText),
                if (next != null && !entry.isDone) ...[
                  const SizedBox(height: AppSpace.sm),
                  NextHint(next: next),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
