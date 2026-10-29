import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/impact_checker.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../ai/ai_event_builder_dialog.dart';
import '../common/staff_widgets.dart';
import 'day_time_grid.dart';
import 'event_detail_sheet.dart';
import 'week_overview.dart';

enum ScheduleView { day, week, participant }

/// Staff calendar: DAY / WEEK / PARTICIPANT views, drafts, add manually or
/// build with AI.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  ScheduleView _view = ScheduleView.day;
  DateTime? _day;
  String? _participantId;

  DateTime _currentDay(BuildContext context) =>
      _day ?? TimeFormat.dateOnly(AppScope.of(context).clock.now());

  void _shift(int days) => setState(() =>
      _day = _currentDay(context).add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.schedule;

    return ListenableBuilder(
      listenable: Listenable.merge([store, services.clock]),
      builder: (context, _) {
        final day = _currentDay(context);
        final now = services.clock.now();
        final draftIds = store.drafts.keys.toSet();
        final draftsToday = store.drafts.values
            .where((e) => TimeFormat.sameDay(e.start, day))
            .length;
        final step = _view == ScheduleView.week ? 7 : 1;

        return ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            PageHeader(
              title: 'Schedule',
              subtitle: TimeFormat.longDate(day),
              actions: [
                FilledButton.icon(
                  onPressed: () => openActivityEditor(context, day: day),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Manually'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showAiEventBuilder(context, day: day),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Build with AI'),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<ScheduleView>(
                  segments: const [
                    ButtonSegment(value: ScheduleView.day, label: Text('Day')),
                    ButtonSegment(value: ScheduleView.week, label: Text('Week')),
                    ButtonSegment(
                        value: ScheduleView.participant,
                        label: Text('Participant')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                ),
                IconButton(
                  tooltip: _view == ScheduleView.week
                      ? 'Previous Week'
                      : 'Previous Day',
                  onPressed: () => _shift(-step),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                TextButton(
                  onPressed: () => setState(() => _day = null),
                  child: const Text('Today'),
                ),
                IconButton(
                  tooltip: _view == ScheduleView.week ? 'Next Week' : 'Next Day',
                  onPressed: () => _shift(step),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            if (draftIds.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              _DraftsBar(
                total: draftIds.length,
                onDay: draftsToday,
                onPublishDay: draftsToday == 0
                    ? null
                    : () {
                        store.publishDrafts(
                          publishedBy: services.auth.user?.displayName ?? 'Staff',
                          day: day,
                        );
                        showStaffMessage(
                            context, '$draftsToday draft(s) published.');
                      },
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            switch (_view) {
              ScheduleView.day => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: DayTimeGrid(
                      events: store.staffEventsOn(day),
                      draftIds: draftIds,
                      now: now,
                      placeName: services.library.placeName,
                      onTap: (e) => showEventDetails(context, e.id),
                    ),
                  ),
                ),
              ScheduleView.week => WeekOverview(
                  anyDayInWeek: day,
                  eventsOn: store.staffEventsOn,
                  draftIds: draftIds,
                  today: TimeFormat.dateOnly(now),
                  onTap: (e) => showEventDetails(context, e.id),
                  onOpenDay: (d) => setState(() {
                    _day = d;
                    _view = ScheduleView.day;
                  }),
                ),
              ScheduleView.participant => _ParticipantView(
                  day: day,
                  participantId: _participantId,
                  onParticipant: (id) => setState(() => _participantId = id),
                  draftIds: draftIds,
                ),
            },
          ],
        );
      },
    );
  }
}

class _DraftsBar extends StatelessWidget {
  final int total;
  final int onDay;
  final VoidCallback? onPublishDay;

  const _DraftsBar({required this.total, required this.onDay, this.onPublishDay});

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.edit_note_rounded,
      title: '$total unpublished draft(s)',
      message: 'Participants do not see drafts. $onDay on this day.',
      action: FilledButton(
        onPressed: onPublishDay,
        child: const Text('Publish This Day'),
      ),
    );
  }
}

/// One participant's day as a list, with overlaps flagged.
class _ParticipantView extends StatelessWidget {
  final DateTime day;
  final String? participantId;
  final ValueChanged<String> onParticipant;
  final Set<String> draftIds;

  const _ParticipantView({
    required this.day,
    required this.participantId,
    required this.onParticipant,
    required this.draftIds,
  });

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final participants = services.participants.all;
    final selected = participantId ?? participants.first.id;
    final events = services.schedule
        .staffEventsOn(day)
        .where((e) => e.isAssignedTo(selected))
        .toList();
    final conflicts = ImpactChecker.conflictsOn(
      snapshot: services.schedule.published,
      day: day,
      participants: {selected: services.participants[selected]!},
    );
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          children: [
            for (final p in participants)
              ChoiceChip(
                avatar: ParticipantAvatar(participant: p, radius: 12),
                label: Text(p.displayName),
                selected: p.id == selected,
                onSelected: (_) => onParticipant(p.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        for (final c in conflicts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: palette.conflict),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                  child: Text('Conflict: ${c.message}',
                      style: TextStyle(color: palette.conflict))),
            ]),
          ),
        Card(
          child: events.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No activities on this day')
              : Column(
                  children: [
                    for (final e in events)
                      _EventTile(event: e, isDraft: draftIds.contains(e.id)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final ScheduledEvent event;
  final bool isDraft;

  const _EventTile({required this.event, required this.isDraft});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(event.category, context.palette);
    final library = AppScope.of(context).library;
    return ListTile(
      leading: Icon(event.isCancelled ? Icons.event_busy_rounded : style.icon,
          color: style.color),
      title: Text(
        event.title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          decoration: event.isCancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('${TimeFormat.range(event.start, event.end)} · '
          '${library.placeName(event.placeId)}'),
      trailing: EventStatusBadges(event: event, isDraft: isDraft),
      onTap: () => showEventDetails(context, event.id),
    );
  }
}
