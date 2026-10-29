import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../participant_presentation_scope.dart';
import 'card_frame.dart';
import 'next_hint.dart';
import 'time_progress.dart';

/// TRAVELLING: shows where to go from and what is at the destination.
class TravelCard extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final bool isImmediateNext;
  final VoidCallback? onTap;

  const TravelCard({
    super.key,
    required this.entry,
    required this.now,
    this.isImmediateNext = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final event = entry.event!;
    final presentation = ParticipantPresentationScope.of(context);
    final library = AppScope.of(context).library;
    final style = CategoryStyle.of(event.category, context.palette);
    final from = library.place(event.placeId);
    final next = entry.nextEvent;
    final destination = library.place(next?.placeId);

    return CardFrame(
      entry: entry,
      accent: style.color,
      categoryIcon: style.icon,
      categoryLabel: style.label,
      taskColor: event.color,
      isImmediateNext: isImmediateNext,
      onTap: onTap,
      semanticSummary:
          '${event.title}, ${TimeFormat.range(event.start, event.end)}'
          '${from == null ? '' : ', from ${from.name}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityVisual(
            visual: event.visual,
            accent: style.color,
            semanticLabel: event.title,
            height: entry.isNow ? 150 : 110,
            showPhoto: presentation.showPhoto,
            showSymbol: presentation.showSymbol,
            desaturate: entry.isDone,
          ),
          const SizedBox(height: AppSpace.md),
          CardHeadline(
            title: event.title,
            timeText: TimeFormat.range(event.start, event.end),
            emphasised: entry.isNow,
          ),
          if (presentation.showPlace && from != null) ...[
            const SizedBox(height: AppSpace.md),
            InfoLine(
              icon: Icons.trip_origin_rounded,
              text: 'From: ${from.name}',
              semanticPrefix: 'Start',
            ),
          ],
          if (presentation.showPlace && destination != null) ...[
            const SizedBox(height: AppSpace.xs),
            InfoLine(
              icon: Icons.flag_outlined,
              text: 'To: ${destination.name}',
              semanticPrefix: 'Destination',
            ),
          ],
          if (presentation.showWhatToBring && event.whatToBring.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            InfoLine(
              icon: Icons.backpack_outlined,
              text: 'Bring: ${event.whatToBring.join(', ')}',
              semanticPrefix: 'What to Bring',
            ),
          ],
          if (entry.isNow) ...[
            const SizedBox(height: AppSpace.lg),
            TimeProgress(
              entry: entry,
              now: now,
              color: style.color,
              presentation: presentation,
            ),
            if (next != null) ...[
              const SizedBox(height: AppSpace.sm),
              NextHint(next: next),
            ],
          ],
        ],
      ),
    );
  }
}
