import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/impact_checker.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/staff_widgets.dart';
import 'participant_status_list.dart';
import 'support_requests_panel.dart';

/// Staff landing page: "What needs attention, and how do I safely manage
/// everyone's schedules?" No clinical scores – only operational facts.
class AdminTodayPage extends StatelessWidget {
  /// Navigates to another staff section (e.g. Schedule) by index.
  final ValueChanged<int> onNavigate;

  const AdminTodayPage({super.key, required this.onNavigate});

  static const int scheduleIndex = 2;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.schedule,
        services.support,
        services.participants,
        services.clock,
      ]),
      builder: (context, _) {
        final now = services.clock.now();
        final store = services.schedule;
        final participants = services.participants;
        final changesToday = store.changesOn(now).length;
        final conflicts = ImpactChecker.conflictsOn(
          snapshot: store.published,
          day: now,
          participants: participants.byId,
        );
        final unacknowledged = store
            .participantsWithPendingChanges(participants.byId.keys)
            .length;
        final preparation = store.published
            .eventsOn(now)
            .where((e) =>
                e.isActive && e.start.isAfter(now) && e.whatToBring.isNotEmpty)
            .length;
        final user = services.auth.user;

        return ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            PageHeader(
              title: 'Good day${user == null ? '' : ', ${user.displayName}'}',
              subtitle: '${TimeFormat.longDate(now)} · ${TimeFormat.hm(now)}',
            ),
            const SectionLabel('Needs attention'),
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              children: [
                SummaryTile(
                  icon: Icons.support_agent_rounded,
                  value: '${services.support.openCount}',
                  label: 'open support requests',
                  needsAttention: services.support.openCount > 0,
                ),
                SummaryTile(
                  icon: Icons.mark_chat_unread_outlined,
                  value: '$unacknowledged',
                  label: 'participants have not seen a change yet',
                  needsAttention: unacknowledged > 0,
                ),
                SummaryTile(
                  icon: Icons.warning_amber_rounded,
                  value: '${conflicts.length}',
                  label: conflicts.length == 1
                      ? 'unresolved conflict'
                      : 'unresolved conflicts',
                  needsAttention: conflicts.isNotEmpty,
                  onTap: () => onNavigate(scheduleIndex),
                ),
                SummaryTile(
                  icon: Icons.published_with_changes_rounded,
                  value: '$changesToday',
                  label: 'schedule changes today',
                  onTap: () => onNavigate(scheduleIndex),
                ),
                SummaryTile(
                  icon: Icons.backpack_outlined,
                  value: '$preparation',
                  label: 'activities need preparation',
                ),
                SummaryTile(
                  icon: Icons.edit_note_rounded,
                  value: '${store.drafts.length}',
                  label: 'unpublished drafts',
                  needsAttention: store.drafts.isNotEmpty,
                  onTap: () => onNavigate(scheduleIndex),
                ),
              ],
            ),
            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              for (final c in conflicts)
                InfoLine(icon: Icons.warning_amber_rounded, text: c.message),
            ],
            const SizedBox(height: AppSpace.xl),
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= AppBreakpoints.medium;
              const support = SupportRequestsPanel();
              const people = ParticipantStatusList();
              if (!wide) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [support, SizedBox(height: AppSpace.lg), people],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: support),
                  SizedBox(width: AppSpace.lg),
                  Expanded(child: people),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
