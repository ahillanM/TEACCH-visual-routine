import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/routine_template.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'assign_routine_dialog.dart';
import 'routine_editor_dialog.dart';

/// Predefined routine modules: create, edit, duplicate, assign.
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  static const double _cardWidth = 360;

  @override
  Widget build(BuildContext context) {
    final routines = AppScope.of(context).routines;
    return ListenableBuilder(
      listenable: routines,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          PageHeader(
            title: 'Routines',
            subtitle: 'Reusable modules – assigning creates editable drafts',
            actions: [
              FilledButton.icon(
                onPressed: () => showRoutineEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Routine'),
              ),
            ],
          ),
          if (routines.templates.isEmpty)
            const EmptyState(
                icon: Icons.view_list_outlined, title: 'No routines yet'),
          Wrap(
            spacing: AppSpace.lg,
            runSpacing: AppSpace.lg,
            children: [
              for (final t in routines.templates)
                SizedBox(width: _cardWidth, child: _RoutineCard(template: t)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineTemplate template;
  const _RoutineCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final routines = AppScope.of(context).routines;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(template.name, style: Theme.of(context).textTheme.titleMedium),
            Text(template.description,
                style: TextStyle(color: palette.textSecondary)),
            const SizedBox(height: AppSpace.md),
            for (final s in template.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        TimeFormat.hm(TimeFormat.atMinuteOfDay(
                            DateTime(2000), s.startMinuteOfDay)),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                    Icon(CategoryStyle.of(s.category, context.palette).icon,
                        size: 16, color: CategoryStyle.of(s.category, context.palette).color),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(child: Text(s.title)),
                    Text('${s.durationMin} min',
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                FilledButton.tonal(
                  onPressed: () =>
                      showAssignRoutineDialog(context, template: template),
                  child: const Text('Assign'),
                ),
                TextButton(
                  onPressed: () => showRoutineEditor(context, template: template),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => routines.duplicate(template),
                  child: const Text('Duplicate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
