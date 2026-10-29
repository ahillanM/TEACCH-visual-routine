import 'package:flutter/material.dart';

import '../../core/models/participant.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';

/// Small building blocks shared by the staff pages.

class ParticipantAvatar extends StatelessWidget {
  final Participant participant;
  final double radius;

  const ParticipantAvatar({super.key, required this.participant, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.brand.withValues(alpha: 0.14),
      child: Text(
        participant.initials,
        style: TextStyle(
            fontWeight: FontWeight.w800,
            color: palette.brand,
            fontSize: radius * 0.8),
      ),
    );
  }
}

/// Multi-select of participants as filter chips.
class ParticipantSelector extends StatelessWidget {
  final List<Participant> participants;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final p in participants)
          FilterChip(
            avatar: ParticipantAvatar(participant: p, radius: 12),
            label: Text(p.displayName),
            selected: selected.contains(p.id),
            onSelected: (on) => onChanged(
              on ? {...selected, p.id} : ({...selected}..remove(p.id)),
            ),
          ),
        if (participants.length > 1)
          ActionChip(
            label: Text(selected.length == participants.length
                ? 'Clear all'
                : 'Select all'),
            onPressed: () => onChanged(selected.length == participants.length
                ? {}
                : {for (final p in participants) p.id}),
          ),
      ],
    );
  }
}

/// Summary tile for the dashboard ("3 schedule changes").
class SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool needsAttention;
  final VoidCallback? onTap;

  const SummaryTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.needsAttention = false,
    this.onTap,
  });

  static const double width = 200;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = needsAttention ? palette.changeText : palette.textSecondary;
    return SizedBox(
      width: width,
      child: Card(
        color: needsAttention ? palette.changeSurface : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
              color: needsAttention ? palette.changeBorder : palette.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent),
                const SizedBox(height: AppSpace.sm),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: palette.textPrimary)),
                Text(label, style: TextStyle(color: palette.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status badges for an event in staff views (draft / cancelled / shared).
class EventStatusBadges extends StatelessWidget {
  final ScheduledEvent event;
  final bool isDraft;

  const EventStatusBadges({super.key, required this.event, this.isDraft = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: [
        if (isDraft)
          StatusBadge(
              label: 'Draft',
              icon: Icons.edit_note_rounded,
              color: palette.changeText,
              fontSize: 11),
        if (event.isCancelled)
          StatusBadge(
              label: 'Cancelled',
              icon: Icons.event_busy_rounded,
              color: palette.textSecondary,
              fontSize: 11),
        if (event.assignedParticipantIds.length > 1)
          StatusBadge(
              label: '${event.assignedParticipantIds.length} participants',
              icon: Icons.groups_outlined,
              color: palette.textSecondary,
              fontSize: 11),
      ],
    );
  }
}

/// A section card with a heading, used to group content on staff pages.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Time picker button using 24h format.
class TimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.schedule_rounded),
      label: Text('$label ${TimeFormat.hm(value)}'),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked == null) return;
        onChanged(DateTime(
            value.year, value.month, value.day, picked.hour, picked.minute));
      },
    );
  }
}

void showStaffMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
