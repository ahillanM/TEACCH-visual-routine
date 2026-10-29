import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/impact_checker.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';

/// Shows affected participants and factual consequences of a planned change.
class ChangeImpactPanel extends StatelessWidget {
  final ImpactReport report;

  const ChangeImpactPanel({super.key, required this.report});

  static IconData iconFor(ImpactKind kind) => switch (kind) {
        ImpactKind.cancelled => Icons.event_busy_outlined,
        ImpactKind.added => Icons.add_circle_outline_rounded,
        ImpactKind.timeChanged => Icons.schedule_rounded,
        ImpactKind.locationChanged => Icons.place_outlined,
        ImpactKind.personChanged => Icons.person_outline_rounded,
        ImpactKind.overlap => Icons.warning_amber_rounded,
        ImpactKind.unfamiliarLocation => Icons.explore_outlined,
        ImpactKind.noParticipants => Icons.person_off_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final directory = AppScope.of(context).participants;
    final palette = context.palette;
    final affected = report.affectedParticipantIds.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Affected participants (${affected.length})',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpace.sm),
        if (affected.isEmpty)
          Text('No participants are affected.',
              style: TextStyle(color: palette.textSecondary))
        else
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final id in affected)
                if (directory[id] != null)
                  Chip(
                    avatar: ParticipantAvatar(
                        participant: directory[id]!, radius: 12),
                    label: Text(directory.nameOf(id)),
                  ),
            ],
          ),
        const SizedBox(height: AppSpace.lg),
        Text('Schedule Consequences',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpace.sm),
        if (report.items.isEmpty)
          Text('No changes yet.', style: TextStyle(color: palette.textSecondary)),
        for (final item in report.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  iconFor(item.kind),
                  size: 20,
                  color: item.isConflict ? palette.conflict : palette.textSecondary,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    item.isConflict ? 'Conflict: ${item.message}' : item.message,
                    style: TextStyle(
                      color: item.isConflict ? palette.conflict : palette.textPrimary,
                      fontWeight:
                          item.isConflict ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'These checks are factual only. The decision stays with staff.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
