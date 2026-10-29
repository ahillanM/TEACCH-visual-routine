import 'package:flutter/material.dart';

import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';

/// Conventional day calendar for staff: hours down the side, events placed
/// by time, overlapping events side by side.
class DayTimeGrid extends StatelessWidget {
  final List<ScheduledEvent> events;
  final Set<String> draftIds;
  final DateTime now;
  final String Function(String? placeId) placeName;
  final ValueChanged<ScheduledEvent> onTap;

  const DayTimeGrid({
    super.key,
    required this.events,
    required this.draftIds,
    required this.now,
    required this.placeName,
    required this.onTap,
  });

  static const int firstHour = 6;
  static const int lastHour = 23;
  static const double hourHeight = 72;
  static const double gutter = 56;

  double _y(DateTime t) =>
      ((t.hour - firstHour) + t.minute / 60) * hourHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final columns = _assignColumns(events);
    final totalHeight = (lastHour - firstHour) * hourHeight;

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth - gutter;
        return Stack(
          children: [
            for (var h = firstHour; h < lastHour; h++)
              Positioned(
                top: (h - firstHour) * hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: gutter,
                      child: Text('${h.toString().padLeft(2, '0')}:00',
                          style: TextStyle(
                              color: palette.textSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: palette.border, height: 1)),
                  ],
                ),
              ),
            if (TimeFormat.sameDay(now, events.firstOrNull?.start ?? now) &&
                now.hour >= firstHour &&
                now.hour < lastHour)
              Positioned(
                top: _y(now),
                left: gutter - AppSpace.xs,
                right: 0,
                child: Semantics(
                  label: 'Current time ${TimeFormat.hm(now)}',
                  child: Container(height: 2, color: palette.nowAccent),
                ),
              ),
            for (final e in events)
              Positioned(
                top: _y(e.start),
                height: (_y(e.end) - _y(e.start)).clamp(24.0, double.infinity),
                left: gutter + width * columns[e.id]!.$1 / columns[e.id]!.$2,
                width: width / columns[e.id]!.$2 - AppSpace.xs,
                child: _EventBlock(
                  event: e,
                  isDraft: draftIds.contains(e.id),
                  placeName: placeName(e.placeId),
                  onTap: () => onTap(e),
                ),
              ),
          ],
        );
      }),
    );
  }

  /// Simple overlap layout: returns (column, columnCount) per event.
  static Map<String, (int, int)> _assignColumns(List<ScheduledEvent> events) {
    final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
    final result = <String, (int, int)>{};
    var cluster = <ScheduledEvent>[];
    var columnEnds = <DateTime>[];
    DateTime? clusterEnd;

    void flush() {
      for (final e in cluster) {
        result[e.id] = (result[e.id]!.$1, columnEnds.length);
      }
      cluster = [];
      columnEnds = [];
      clusterEnd = null;
    }

    for (final e in sorted) {
      if (clusterEnd != null && !e.start.isBefore(clusterEnd!)) flush();
      var col = columnEnds.indexWhere((end) => !e.start.isBefore(end));
      if (col < 0) {
        col = columnEnds.length;
        columnEnds.add(e.end);
      } else {
        columnEnds[col] = e.end;
      }
      result[e.id] = (col, 1);
      cluster.add(e);
      if (clusterEnd == null || e.end.isAfter(clusterEnd!)) clusterEnd = e.end;
    }
    flush();
    return result;
  }
}

class _EventBlock extends StatelessWidget {
  final ScheduledEvent event;
  final bool isDraft;
  final String placeName;
  final VoidCallback onTap;

  const _EventBlock({
    required this.event,
    required this.isDraft,
    required this.placeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = CategoryStyle.of(event.category, context.palette);
    final cancelled = event.isCancelled;
    final color = cancelled ? palette.textSecondary : style.color;
    final strip = cancelled || event.color == null
        ? color
        : TaskColorStyle.of(event.color!, palette).accent;
    final status = [
      if (isDraft) 'draft',
      if (cancelled) 'cancelled',
    ].join(', ');

    return Semantics(
      button: true,
      label: '${event.title}, ${TimeFormat.range(event.start, event.end)}, '
          '$placeName, ${event.assignedParticipantIds.length} participants'
          '${status.isEmpty ? '' : ', $status'}',
      excludeSemantics: true,
      child: Material(
        color: cancelled ? palette.surfaceMuted : style.tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: isDraft
              ? BorderSide(color: palette.textSecondary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: strip, width: event.color == null ? 4 : 8)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm, vertical: AppSpace.xxs),
            child: LayoutBuilder(builder: (context, c) {
              final roomy = c.maxHeight > 52;
              // Very short blocks (e.g. a 20-min bus) clip instead of overflowing.
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(cancelled ? Icons.event_busy_rounded : style.icon,
                          size: 14, color: color),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: roomy ? 14 : 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            decoration:
                                cancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isDraft)
                        Text('DRAFT',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: palette.textSecondary)),
                    ],
                  ),
                  if (roomy)
                    Text(
                      '${TimeFormat.range(event.start, event.end)} · $placeName · '
                      '${event.assignedParticipantIds.length} pers.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
