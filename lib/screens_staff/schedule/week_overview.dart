import 'package:flutter/material.dart';

import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';

/// Compact week view: one column per day (wide) or one section per day.
class WeekOverview extends StatelessWidget {
  final DateTime anyDayInWeek;
  final List<ScheduledEvent> Function(DateTime day) eventsOn;
  final Set<String> draftIds;
  final DateTime today;
  final ValueChanged<ScheduledEvent> onTap;
  final ValueChanged<DateTime> onOpenDay;

  const WeekOverview({
    super.key,
    required this.anyDayInWeek,
    required this.eventsOn,
    required this.draftIds,
    required this.today,
    required this.onTap,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final monday = TimeFormat.startOfWeek(anyDayInWeek);
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: _DayColumn(
                  day: d,
                  isToday: TimeFormat.sameDay(d, today),
                  events: eventsOn(d),
                  draftIds: draftIds,
                  onTap: onTap,
                  onOpenDay: () => onOpenDay(d),
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _DayColumn(
              day: d,
              isToday: TimeFormat.sameDay(d, today),
              events: eventsOn(d),
              draftIds: draftIds,
              onTap: onTap,
              onOpenDay: () => onOpenDay(d),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final List<ScheduledEvent> events;
  final Set<String> draftIds;
  final ValueChanged<ScheduledEvent> onTap;
  final VoidCallback onOpenDay;

  const _DayColumn({
    required this.day,
    required this.isToday,
    required this.events,
    required this.draftIds,
    required this.onTap,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isToday ? palette.nowAccent : palette.border,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: onOpenDay,
              child: Text(
                '${TimeFormat.shortWeekday(day)} ${day.day}.${day.month}.'
                '${isToday ? ' · Today' : ''}',
              ),
            ),
            for (final e in events)
              _WeekChip(event: e, isDraft: draftIds.contains(e.id), onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  final ScheduledEvent event;
  final bool isDraft;
  final ValueChanged<ScheduledEvent> onTap;

  const _WeekChip({required this.event, required this.isDraft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(event.category);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Material(
        color: event.isCancelled ? palette.surfaceMuted : style.tint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: () => onTap(event),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xs),
            child: Row(
              children: [
                Icon(event.isCancelled ? Icons.event_busy_rounded : style.icon,
                    size: 14,
                    color: event.isCancelled ? palette.textSecondary : style.color),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    '${TimeFormat.hm(event.start)} ${event.title}'
                    '${isDraft ? ' (draft)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      decoration:
                          event.isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
