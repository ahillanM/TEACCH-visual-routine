import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/routine_template.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';

/// Create or edit a routine template (name, description, steps).
Future<void> showRoutineEditor(BuildContext context, {RoutineTemplate? template}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RoutineEditor(template: template),
  );
}

class _RoutineEditor extends StatefulWidget {
  final RoutineTemplate? template;
  const _RoutineEditor({this.template});

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  late final _name = TextEditingController(text: widget.template?.name ?? '');
  late final _description =
      TextEditingController(text: widget.template?.description ?? '');
  late List<RoutineStep> _steps = [...?widget.template?.steps];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _asTime(int minuteOfDay) =>
      TimeFormat.atMinuteOfDay(DateTime(2000), minuteOfDay);

  void _addFromLibrary(String? activityId) {
    final a = AppScope.of(context).library.activity(activityId);
    if (a == null) return;
    final start = _steps.isEmpty
        ? 9 * 60
        : _steps.last.startMinuteOfDay + _steps.last.durationMin;
    setState(() => _steps = [
          ..._steps,
          RoutineStep(
            title: a.name,
            category: a.category,
            startMinuteOfDay: start,
            durationMin: a.defaultDurationMin,
            visual: a.visual,
            libraryActivityId: a.id,
            placeId: a.defaultPlaceId,
            contactId: a.defaultContactId,
          ),
        ]);
  }

  void _save() {
    final routines = AppScope.of(context).routines;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showStaffMessage(context, 'Please give the routine a name.');
      return;
    }
    _steps.sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    routines.save(RoutineTemplate(
      id: widget.template?.id ?? routines.newId(),
      name: name,
      description: _description.text.trim(),
      steps: _steps,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return AlertDialog(
      title: Text(widget.template == null ? 'New routine' : 'Edit routine'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AppSpace.lg),
              const Text('Steps', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.sm),
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(CategoryStyle.of(_steps[i].category).icon,
                          color: CategoryStyle.of(_steps[i].category).color),
                      SizedBox(
                        width: 180,
                        child: Text(_steps[i].title,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      TimeField(
                        label: 'Start',
                        value: _asTime(_steps[i].startMinuteOfDay),
                        onChanged: (t) => setState(() => _steps[i] = _steps[i]
                            .copyWith(startMinuteOfDay: t.hour * 60 + t.minute)),
                      ),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<int>(
                          initialValue: _steps[i].durationMin,
                          decoration: const InputDecoration(labelText: 'Minutes'),
                          items: {
                            for (final m in [10, 15, 20, 30, 45, 60, 90, 120,
                              _steps[i].durationMin])
                              m
                          }
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text('$m')))
                              .toList(),
                          onChanged: (m) => setState(() =>
                              _steps[i] = _steps[i].copyWith(durationMin: m)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove step',
                        onPressed: () => setState(() => _steps.removeAt(i)),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(_steps.length),
                decoration: const InputDecoration(
                  labelText: 'Add step from library',
                  prefixIcon: Icon(Icons.add_rounded),
                ),
                items: [
                  for (final a in library.activities)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: _addFromLibrary,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save routine')),
      ],
    );
  }
}
