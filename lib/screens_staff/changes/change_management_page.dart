import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/change_factory.dart';
import '../../core/logic/change_planner.dart';
import '../../core/logic/impact_checker.dart';
import '../../core/models/library_items.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';
import '../preview/participant_preview.dart';
import 'change_impact_panel.dart';

enum _Choice { freeTime, replacement, move, planB }

/// Cancel an activity safely:
/// 1. "What happens instead?"  2. Impact  3. Participant preview  4. Publish.
///
/// Nothing reaches participants until "Publish change" is pressed, and no
/// other activity moves unless staff explicitly choose to move it.
class ChangeManagementPage extends StatefulWidget {
  final String eventId;

  const ChangeManagementPage({super.key, required this.eventId});

  @override
  State<ChangeManagementPage> createState() => _ChangeManagementPageState();
}

class _ChangeManagementPageState extends State<ChangeManagementPage> {
  _Choice _choice = _Choice.freeTime;
  LibraryActivity? _replacementActivity;
  String? _moveEventId;
  DateTime? _moveNewStart;
  String? _previewParticipantId;
  late final String _replacementId =
      AppScope.of(context).schedule.newId('evt');

  ScheduledEvent get _original =>
      AppScope.of(context).schedule.published[widget.eventId]!;

  /// Later events of affected participants on the same day (move candidates).
  List<ScheduledEvent> _moveCandidates() {
    final original = _original;
    final snapshot = AppScope.of(context).schedule.published;
    return snapshot
        .eventsOn(original.start)
        .where((e) =>
            e.isActive &&
            e.id != original.id &&
            !e.start.isBefore(original.end) &&
            e.assignedParticipantIds
                .any(original.assignedParticipantIds.contains))
        .toList();
  }

  CancellationOption? _option() {
    final services = AppScope.of(context);
    final original = _original;
    switch (_choice) {
      case _Choice.freeTime:
        return const FreeTimeInstead();
      case _Choice.replacement:
        final a = _replacementActivity;
        if (a == null) return null;
        return ReplacementInstead(ScheduledEvent(
          id: _replacementId,
          title: a.name,
          category: a.category,
          start: original.start,
          end: original.end,
          visual: a.visual,
          placeId: a.defaultPlaceId,
          contactId: a.defaultContactId,
          whatToBring: a.whatToBring,
          instructions: a.instructions,
          libraryActivityId: a.id,
        ));
      case _Choice.move:
        final id = _moveEventId;
        final start = _moveNewStart;
        if (id == null || start == null) return null;
        return MoveActivityInstead(eventId: id, newStart: start);
      case _Choice.planB:
        final planB = services.library.activity(original.planBActivityId);
        return planB == null ? null : PlanBInstead(planB);
    }
  }

  void _publish(PlannedChange plan) {
    final services = AppScope.of(context);
    final change = services.schedule.publish(
      upserts: plan.upserts,
      publishedBy: services.auth.user?.displayName ?? 'Staff',
      outcome: plan.outcome,
      cancelledEventId: plan.cancelled.id,
    );
    final count = change?.affectedParticipantIds.length ?? 0;
    Navigator.of(context).pop();
    showStaffMessage(context,
        'Change published. $count participant(s) will see "Your plan has changed".');
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.schedule;
    final original = _original;
    final option = _option();
    final plan = option == null
        ? null
        : ChangePlanner.planCancellation(
            base: store.published,
            eventId: original.id,
            option: option,
            newId: () => _replacementId,
          );

    final report = plan == null
        ? null
        : ImpactChecker.evaluate(
            base: store.published,
            upserts: plan.upserts,
            participants: services.participants.byId,
            placeName: services.library.placeName,
            contactName: services.library.contactName,
          );

    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final decision = _DecisionColumn(
      original: original,
      choice: _choice,
      onChoice: (c) => setState(() => _choice = c),
      replacementActivity: _replacementActivity,
      onReplacement: (a) => setState(() => _replacementActivity = a),
      moveCandidates: _moveCandidates(),
      moveEventId: _moveEventId,
      moveNewStart: _moveNewStart,
      onMove: (id, start) => setState(() {
        _moveEventId = id;
        _moveNewStart = start;
      }),
      planB: services.library.activity(original.planBActivityId),
      report: report,
    );
    final preview = plan == null || report == null
        ? const SizedBox.shrink()
        : _previewSection(plan, report);

    return Scaffold(
      appBar: AppBar(title: Text('Cancel: ${original.title}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: decision),
                  const SizedBox(width: AppSpace.xl),
                  preview,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [decision, const SizedBox(height: AppSpace.xl), preview],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back Without Changes'),
              ),
              const SizedBox(width: AppSpace.md),
              FilledButton.icon(
                onPressed: plan == null ? null : () => _publish(plan),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Publish Change'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewSection(PlannedChange plan, ImpactReport report) {
    final services = AppScope.of(context);
    final store = services.schedule;
    final affected = report.affectedParticipantIds.toList()..sort();
    if (affected.isEmpty) return const SizedBox.shrink();
    final selected = affected.contains(_previewParticipantId)
        ? _previewParticipantId!
        : affected.first;
    final participant = services.participants[selected];
    if (participant == null) return const SizedBox.shrink();

    final hypothetical = ChangeFactory.create(
      id: 'preview',
      base: store.published,
      upserts: plan.upserts,
      version: store.version + 1,
      publishedAt: services.clock.now(),
      publishedBy: services.auth.user?.displayName ?? 'Staff',
      outcome: plan.outcome,
      cancelledEventId: plan.cancelled.id,
    );

    return Column(
      children: [
        Text('3. Preview as participant',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          children: [
            for (final id in affected)
              ChoiceChip(
                label: Text(services.participants.nameOf(id)),
                selected: id == selected,
                onSelected: (_) => setState(() => _previewParticipantId = id),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        ParticipantPreview(
          key: ValueKey('$selected-${plan.upserts.length}-$_choice'),
          participant: participant,
          now: services.clock.now(),
          displayed: store.published,
          latest: store.published.applying(plan.upserts),
          pendingChanges: [hypothetical],
        ),
      ],
    );
  }
}

class _DecisionColumn extends StatelessWidget {
  final ScheduledEvent original;
  final _Choice choice;
  final ValueChanged<_Choice> onChoice;
  final LibraryActivity? replacementActivity;
  final ValueChanged<LibraryActivity?> onReplacement;
  final List<ScheduledEvent> moveCandidates;
  final String? moveEventId;
  final DateTime? moveNewStart;
  final void Function(String? id, DateTime? start) onMove;
  final LibraryActivity? planB;
  final ImpactReport? report;

  const _DecisionColumn({
    required this.original,
    required this.choice,
    required this.onChoice,
    required this.replacementActivity,
    required this.onReplacement,
    required this.moveCandidates,
    required this.moveEventId,
    required this.moveNewStart,
    required this.onMove,
    required this.planB,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final palette = context.palette;
    final moveEvent =
        moveCandidates.where((e) => e.id == moveEventId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Activity to Cancel',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(original.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${TimeFormat.weekday(original.start)} '
                '${TimeFormat.range(original.start, original.end)} · '
                '${services.library.placeName(original.placeId)}',
                style: TextStyle(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        SectionCard(
          title: '1. What happens instead?',
          child: RadioGroup<_Choice>(
            groupValue: choice,
            onChanged: (c) => onChoice(c ?? _Choice.freeTime),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RadioListTile(
                  value: _Choice.freeTime,
                  title: Text('Free Time'),
                  subtitle: Text(
                      'Nothing is required. The next activity keeps its time.'),
                ),
                const RadioListTile(
                  value: _Choice.replacement,
                  title: Text('Replacement Activity'),
                  subtitle: Text('Assign another activity in the same time slot.'),
                ),
                if (choice == _Choice.replacement)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.xxl, 0, AppSpace.lg, AppSpace.md),
                    child: DropdownButtonFormField<String>(
                      initialValue: replacementActivity?.id,
                      decoration:
                          const InputDecoration(labelText: 'Activity from Library'),
                      items: [
                        for (final a in services.library.activities)
                          if (a.id != original.libraryActivityId)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (id) =>
                          onReplacement(services.library.activity(id)),
                    ),
                  ),
                RadioListTile(
                  value: _Choice.move,
                  enabled: moveCandidates.isNotEmpty,
                  title: const Text('Move Another Activity'),
                  subtitle: const Text(
                      'Explicitly reschedule a later activity (e.g. lunch earlier).'),
                ),
                if (choice == _Choice.move)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.xxl, 0, AppSpace.lg, AppSpace.md),
                    child: Wrap(
                      spacing: AppSpace.md,
                      runSpacing: AppSpace.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            initialValue: moveEventId,
                            decoration: const InputDecoration(
                                labelText: 'Activity to Move'),
                            items: [
                              for (final e in moveCandidates)
                                DropdownMenuItem(
                                  value: e.id,
                                  child: Text(
                                      '${TimeFormat.hm(e.start)} ${e.title}'),
                                ),
                            ],
                            onChanged: (id) {
                              final e = moveCandidates
                                  .firstWhere((c) => c.id == id);
                              onMove(id, e.start);
                            },
                          ),
                        ),
                        if (moveEvent != null)
                          TimeField(
                            label: 'New Start',
                            value: moveNewStart ?? moveEvent.start,
                            onChanged: (t) => onMove(moveEvent.id, t),
                          ),
                      ],
                    ),
                  ),
                RadioListTile(
                  value: _Choice.planB,
                  enabled: planB != null,
                  title: Text(planB == null
                      ? 'Use predefined Plan B (none set)'
                      : 'Use predefined Plan B: ${planB!.name}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        SectionCard(
          title: '2. Impact',
          child: report == null
              ? Text('Complete step 1 to see the impact.',
                  style: TextStyle(color: palette.textSecondary))
              : ChangeImpactPanel(report: report!),
        ),
      ],
    );
  }
}
