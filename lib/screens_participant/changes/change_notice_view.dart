import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/change_notice_builder.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/change_event.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/status_badge.dart';
import '../participant_presentation_scope.dart';

/// Explains pending changes: what was planned, what happens instead, and
/// what stays the same. Pure view – reused by staff preview.
class ChangeNoticeView extends StatelessWidget {
  final ChangeNoticeData notice;

  const ChangeNoticeView({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in notice.items) ...[
          _ChangeNoticeCard(item: item),
          const SizedBox(height: AppSpace.lg),
        ],
      ],
    );
  }
}

class _ChangeNoticeCard extends StatelessWidget {
  final ChangeNoticeItem item;
  const _ChangeNoticeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.changeBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: item.isCancellation
            ? _cancellation(context)
            : item.isAddition
            ? _addition(context)
            : _edit(context),
      ),
    );
  }

  List<Widget> _cancellation(BuildContext context) {
    final palette = context.palette;
    final original = item.before!;
    final next = item.nextActivity;
    return [
      _EventRow(
        event: original,
        badge: StatusBadge(
          label: 'Cancelled',
          icon: Icons.event_busy_rounded,
          color: palette.changeText,
          filled: true,
          fontSize: 14,
        ),
        struckThrough: true,
      ),
      const SizedBox(height: AppSpace.lg),
      const _Label('Instead'),
      const SizedBox(height: AppSpace.sm),
      if (item.replacement != null)
        _EventRow(event: item.replacement!)
      else
        _FreeTimeRow(until: item.freeTimeUntil),
      if (next != null) ...[
        const SizedBox(height: AppSpace.lg),
        _Sentence(
          icon: item.nextActivityMoved
              ? Icons.update_rounded
              : Icons.event_available_rounded,
          text: item.nextActivityMoved
              ? '${next.title} now starts at ${TimeFormat.hm(next.start)}.'
              : '${next.title} still starts at ${TimeFormat.hm(next.start)}.',
        ),
      ],
    ];
  }

  List<Widget> _addition(BuildContext context) {
    final palette = context.palette;
    return [
      _EventRow(
        event: item.event,
        badge: StatusBadge(
          label: 'New',
          icon: Icons.add_circle_outline_rounded,
          color: palette.changeText,
          filled: true,
          fontSize: 14,
        ),
      ),
    ];
  }

  List<Widget> _edit(BuildContext context) {
    final palette = context.palette;
    final library = AppScope.of(context).library;
    final before = item.before;
    final after = item.after ?? item.event;
    final lines = <Widget>[];
    if (item.aspects.contains(ChangeAspect.timeChanged) && before != null) {
      lines.add(
        _Sentence(
          icon: Icons.schedule_rounded,
          text:
              'New time: ${TimeFormat.range(after.start, after.end)} '
              '(was ${TimeFormat.range(before.start, before.end)}).',
        ),
      );
    }
    if (item.aspects.contains(ChangeAspect.locationChanged)) {
      lines.add(
        _Sentence(
          icon: Icons.place_outlined,
          text:
              'New place: ${library.placeName(after.placeId)}'
              '${before == null ? '' : ' (was ${library.placeName(before.placeId)})'}.',
        ),
      );
    }
    if (item.aspects.contains(ChangeAspect.personChanged)) {
      lines.add(
        _Sentence(
          icon: Icons.person_outline_rounded,
          text: 'New person: ${library.contactName(after.contactId)}.',
        ),
      );
    }
    if (lines.isEmpty) {
      lines.add(
        const _Sentence(
          icon: Icons.info_outline_rounded,
          text: 'Some details of this activity changed.',
        ),
      );
    }
    return [
      _EventRow(
        event: after,
        badge: StatusBadge(
          label: 'Changed',
          icon: Icons.published_with_changes_rounded,
          color: palette.changeText,
          filled: true,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: AppSpace.md),
      for (final l in lines) ...[l, const SizedBox(height: AppSpace.xs)],
    ];
  }
}

class _EventRow extends StatelessWidget {
  final ScheduledEvent event;
  final Widget? badge;
  final bool struckThrough;

  const _EventRow({
    required this.event,
    this.badge,
    this.struckThrough = false,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = ParticipantPresentationScope.of(context);
    final style = CategoryStyle.of(event.category, context.palette);
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: ActivityVisual(
            visual: event.visual,
            accent: style.color,
            semanticLabel: event.title,
            height: 88,
            showPhoto: presentation.showPhoto,
            showSymbol: presentation.showSymbol,
            desaturate: struckThrough,
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?badge,
              if (badge != null) const SizedBox(height: AppSpace.xs),
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  decoration: struckThrough ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                TimeFormat.range(event.start, event.end),
                style: TextStyle(fontSize: 17, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FreeTimeRow extends StatelessWidget {
  final DateTime? until;
  const _FreeTimeRow({this.until});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(ActivityCategory.freeTime, context.palette);
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: style.tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(style.icon, size: 44, color: style.color),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Free Time', style: Theme.of(context).textTheme.titleLarge),
              if (until != null)
                Text(
                  'until ${TimeFormat.hm(until!)}',
                  style: TextStyle(fontSize: 17, color: palette.textSecondary),
                ),
              Text(
                'Nothing is required.',
                style: TextStyle(fontSize: 15, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: context.palette.textSecondary,
    ),
  );
}

class _Sentence extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Sentence({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.palette.textPrimary),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
