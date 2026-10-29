import 'package:flutter/material.dart';

import '../core/models/task_color.dart';
import '../theme.dart';

/// Lets staff give a task a colour participants learn to recognise.
/// Every swatch is labelled, so the choice never relies on colour alone.
class TaskColorPicker extends StatelessWidget {
  final TaskColor? value;
  final ValueChanged<TaskColor?> onChanged;

  const TaskColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Colour',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpace.xxs),
        Text(
          'Participants see this colour on the card, so they can recognise '
          'the task.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            _Swatch(
              label: 'None',
              color: null,
              selected: value == null,
              onTap: () => onChanged(null),
            ),
            for (final c in TaskColor.values)
              _Swatch(
                label: c.label,
                color: TaskColorStyle.of(c, palette).accent,
                selected: value == c,
                onTap: () => onChanged(c),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Task colour $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? palette.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color ?? palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.border),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: color == null
                            ? palette.textPrimary
                            : palette.onColor(color!),
                      )
                    : (color == null
                          ? Icon(
                              Icons.block_rounded,
                              size: 18,
                              color: palette.textSecondary,
                            )
                          : null),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
