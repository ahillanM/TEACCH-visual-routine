import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/presentation_rules.dart';
import '../../core/models/feed_entry.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../participant_presentation_scope.dart';
import 'card_frame.dart';
import 'next_hint.dart';
import 'time_progress.dart';
import 'transition_warning.dart';

/// The normal activity card: IMAGE → TITLE → TIME → PLACE/PERSON → PROGRESS.
///
/// What is shown is controlled by [CardPresentation] (participant profile);
/// the layout stays identical for every activity.
class TaskCard extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final bool isImmediateNext;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.entry,
    required this.now,
    this.isImmediateNext = false,
    this.onTap,
  });

  static const double nowVisualHeight = 190;
  static const double visualHeight = 150;

  @override
  Widget build(BuildContext context) {
    final event = entry.event!;
    final presentation = ParticipantPresentationScope.of(context);
    final library = AppScope.of(context).library;
    final style = CategoryStyle.of(event.category);
    final place = library.place(event.placeId);
    final contact = library.contact(event.contactId);

    return CardFrame(
      entry: entry,
      accent: style.color,
      categoryIcon: style.icon,
      categoryLabel: style.label,
      isImmediateNext: isImmediateNext,
      onTap: onTap,
      semanticSummary: [
        event.title,
        TimeFormat.range(event.start, event.end),
        if (presentation.showPlace && place != null) 'at ${place.name}',
        if (presentation.showPerson && contact != null) 'with ${contact.name}',
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityVisual(
            visual: event.visual,
            accent: style.color,
            semanticLabel: event.title,
            height: entry.isNow ? nowVisualHeight : visualHeight,
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
          ..._details(presentation, place?.name, contact?.name, event),
          if (entry.isNow) ...[
            const SizedBox(height: AppSpace.lg),
            TimeProgress(
              entry: entry,
              now: now,
              color: style.color,
              presentation: presentation,
            ),
            const SizedBox(height: AppSpace.md),
            TransitionWarning(
              entry: entry,
              now: now,
              thresholdsMinutes: presentation.transitionWarningMinutes,
            ),
            if (entry.nextEvent != null) ...[
              const SizedBox(height: AppSpace.sm),
              NextHint(next: entry.nextEvent!),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _details(
    CardPresentation p,
    String? placeName,
    String? contactName,
    ScheduledEvent event,
  ) {
    final lines = <Widget>[
      if (p.showPlace && placeName != null)
        InfoLine(
            icon: Icons.place_outlined, text: placeName, semanticPrefix: 'Place'),
      if (p.showPerson && contactName != null)
        InfoLine(
            icon: Icons.person_outline_rounded,
            text: contactName,
            semanticPrefix: 'With'),
      if (p.showWhatToBring && event.whatToBring.isNotEmpty)
        InfoLine(
            icon: Icons.backpack_outlined,
            text: 'Bring: ${event.whatToBring.join(', ')}',
            semanticPrefix: 'What to bring'),
      if (p.showLeaveHint && !entry.isDone && !entry.isNow && placeName != null)
        InfoLine(
          icon: Icons.directions_walk_rounded,
          text: 'Leave at ${TimeFormat.hm(event.start.subtract(
            const Duration(minutes: CardPresentation.leaveEarlyMinutes),
          ))}',
          semanticPrefix: 'When to leave',
        ),
    ];
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpace.md),
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpace.xs),
        lines[i],
      ],
    ];
  }
}
