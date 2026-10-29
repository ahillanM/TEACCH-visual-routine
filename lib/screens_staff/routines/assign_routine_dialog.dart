import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/routine_assigner.dart';
import '../../core/models/routine_template.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';

/// Assign a routine template to participants on a date. Creates DRAFT
/// events that can be customised and then published from Schedule.
Future<void> showAssignRoutineDialog(
  BuildContext context, {
  RoutineTemplate? template,
  Set<String> initialParticipantIds = const {},
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AssignRoutineDialog(
      template: template,
      initialParticipantIds: initialParticipantIds,
    ),
  );
}

class _AssignRoutineDialog extends StatefulWidget {
  final RoutineTemplate? template;
  final Set<String> initialParticipantIds;

  const _AssignRoutineDialog({
    required this.template,
    required this.initialParticipantIds,
  });

  @override
  State<_AssignRoutineDialog> createState() => _AssignRoutineDialogState();
}

class _AssignRoutineDialogState extends State<_AssignRoutineDialog> {
  late String? _templateId = widget.template?.id;
  late Set<String> _participants = {...widget.initialParticipantIds};
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final templates = services.routines.templates;
    final day = _day ??
        TimeFormat.dateOnly(services.clock.now()).add(const Duration(days: 1));
    final template = templates.where((t) => t.id == _templateId).firstOrNull;

    return AlertDialog(
      title: const Text('Assign routine'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _templateId,
                decoration: const InputDecoration(labelText: 'Routine'),
                items: [
                  for (final t in templates)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (id) => setState(() => _templateId = id),
              ),
              const SizedBox(height: AppSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(TimeFormat.longDate(day)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: day,
                      firstDate: day.subtract(const Duration(days: 30)),
                      lastDate: day.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _day = picked);
                  },
                ),
              ),
              const SizedBox(height: AppSpace.md),
              const Text('Participants',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.sm),
              ParticipantSelector(
                participants: services.participants.all,
                selected: _participants,
                onChanged: (s) => setState(() => _participants = s),
              ),
              if (template != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  '${template.steps.length} activities will be created as drafts.',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: template == null || _participants.isEmpty
              ? null
              : () {
                  final store = services.schedule;
                  final events = RoutineAssigner.instantiate(
                    template: template,
                    day: day,
                    participantIds: _participants,
                    newId: () => store.newId('evt'),
                  );
                  store.saveDrafts(events);
                  Navigator.pop(context);
                  showStaffMessage(context,
                      '${events.length} draft activities created for ${TimeFormat.longDate(day)}. '
                      'Customise and publish them in Schedule.');
                },
          child: const Text('Create drafts'),
        ),
      ],
    );
  }
}
