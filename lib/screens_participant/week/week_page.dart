import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import '../participant_presentation_scope.dart';

/// A simple, visual overview of the week – one row per day. Read-only.
class WeekPage extends StatelessWidget {
  final String participantId;

  const WeekPage({super.key, required this.participantId});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.schedule,
      builder: (context, _) {
        final today = TimeFormat.dateOnly(services.clock.now());
        final monday = TimeFormat.startOfWeek(today);
        final snapshot = services.schedule.displayedSnapshotFor(participantId);

        return ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Semantics(
              header: true,
              child: Text('This week',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: AppSpace.lg),
            for (var i = 0; i < 7; i++)
              Builder(builder: (context) {
                final day = monday.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: _DayRow(
                    day: day,
                    isToday: TimeFormat.sameDay(day, today),
                    isPast: day.isBefore(today),
                    events: snapshot.activeEventsFor(participantId, day),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isPast;
  final List<ScheduledEvent> events;

  const _DayRow({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.events,
  });

  static const double _thumb = 64;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final presentation = ParticipantPresentationScope.of(context);
    return Semantics(
      container: true,
      label: '${TimeFormat.weekday(day)}${isToday ? ', today' : ''}, '
          '${events.length} activities',
      child: Card(
        color: isPast ? palette.doneSurface : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isToday ? palette.nowAccent : palette.border,
            width: isToday ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _openDay(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(TimeFormat.weekday(day),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: AppSpace.sm),
                    Text('${day.day}.${day.month}.',
                        style: TextStyle(color: palette.textSecondary)),
                    const Spacer(),
                    if (isToday)
                      StatusBadge(
                        label: 'Today',
                        icon: Icons.today_rounded,
                        color: palette.nowAccent,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ExcludeSemantics(
                  child: SizedBox(
                    height: _thumb,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.sm),
                      itemBuilder: (context, i) => SizedBox(
                        width: _thumb,
                        child: ActivityVisual(
                          visual: events[i].visual,
                          accent: CategoryStyle.of(events[i].category).color,
                          semanticLabel: events[i].title,
                          height: _thumb,
                          showPhoto: false,
                          showSymbol: presentation.showSymbol ||
                              !presentation.showPhoto,
                          desaturate: isPast,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
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

  void _openDay(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              Text(TimeFormat.longDate(day),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              if (events.isEmpty)
                const EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'Nothing planned'),
              for (final e in events)
                ListTile(
                  leading: Icon(CategoryStyle.of(e.category).icon,
                      color: CategoryStyle.of(e.category).color),
                  title: Text(e.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(TimeFormat.range(e.start, e.end)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
