import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/participant.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';

/// Small building blocks shared by the staff pages.

class ParticipantAvatar extends StatelessWidget {
  final Participant participant;
  final double radius;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.brandSoft,
      child: Text(
        participant.initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: palette.brand,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Multi-select of participants as filter chips.
class ParticipantSelector extends StatelessWidget {
  final List<Participant> participants;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Shows the staff's saved groups as one-tap shortcuts above the people.
  final bool showGroups;

  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.selected,
    required this.onChanged,
    this.showGroups = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showGroups) return _people(context);
    final groups = AppScope.of(context).groups;
    return ListenableBuilder(
      listenable: groups,
      builder: (context, _) {
        final known = {for (final p in participants) p.id};
        final usable = [
          for (final g in groups.groups)
            if (g.memberIds.any(known.contains)) g,
        ];
        if (usable.isEmpty) return _people(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Groups',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final g in usable)
                  _groupChip(g.name, g.memberIds.where(known.contains).toSet()),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'People',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            _people(context),
          ],
        );
      },
    );
  }

  /// Selected when every member is selected; toggling adds or removes the
  /// whole group without touching anyone else.
  Widget _groupChip(String name, Set<String> members) {
    final allIn = selected.containsAll(members);
    return FilterChip(
      avatar: const Icon(Icons.groups_2_outlined, size: 18),
      label: Text('$name (${members.length})'),
      selected: allIn,
      showCheckmark: false,
      onSelected: (_) => onChanged(
        allIn ? ({...selected}..removeAll(members)) : {...selected, ...members},
      ),
    );
  }

  Widget _people(BuildContext context) {
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
            label: Text(
              selected.length == participants.length
                  ? 'Clear All'
                  : 'Select All',
            ),
            onPressed: () => onChanged(
              selected.length == participants.length
                  ? {}
                  : {for (final p in participants) p.id},
            ),
          ),
      ],
    );
  }
}

/// Summary tile for the dashboard ("3 schedule changes").
///
/// Colour comes from [tone] (icon chip + top strip), never a fully
/// saturated card; [needsAttention] adds the strip and a stronger border.
/// Without a tone the tile stays neutral (slate).
class SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool needsAttention;
  final SemanticTone? tone;
  final VoidCallback? onTap;

  const SummaryTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.needsAttention = false,
    this.tone,
    this.onTap,
  });

  static const double width = 200;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iconColor = tone?.color ?? palette.textSecondary;
    final iconBackground = tone?.soft ?? palette.surfaceMuted;
    final strip = tone?.accent ?? palette.textSecondary;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: needsAttention ? strip : palette.border,
            width: needsAttention ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: needsAttention ? strip : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: palette.textPrimary),
                ),
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

  const EventStatusBadges({
    super.key,
    required this.event,
    this.isDraft = false,
  });

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
            color: palette.textSecondary,
            fontSize: 11,
          ),
        if (event.isCancelled)
          StatusBadge(
            label: 'Cancelled',
            icon: Icons.event_busy_rounded,
            color: palette.textSecondary,
            fontSize: 11,
          ),
        if (event.isParticipantOwned)
          StatusBadge(
            label: 'Added by Participant',
            icon: Icons.person_add_alt_outlined,
            color: palette.textSecondary,
            fontSize: 11,
          ),
        if (event.assignedParticipantIds.length > 1)
          StatusBadge(
            label: '${event.assignedParticipantIds.length} participants',
            icon: Icons.groups_outlined,
            color: palette.textSecondary,
            fontSize: 11,
          ),
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
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
        onChanged(
          DateTime(
            value.year,
            value.month,
            value.day,
            picked.hour,
            picked.minute,
          ),
        );
      },
    );
  }
}

void showStaffMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
