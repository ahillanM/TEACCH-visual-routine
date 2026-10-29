import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/participant_day.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/staff_widgets.dart';
import '../preview/participant_preview_dialog.dart';
import '../routines/assign_routine_dialog.dart';
import '../schedule/event_detail_sheet.dart';
import '../today/participant_status_list.dart';
import 'profile_preferences_editor.dart';

/// One participant: today, support preferences, routines, preview.
class ParticipantDetailPage extends StatelessWidget {
  final String participantId;

  const ParticipantDetailPage({super.key, required this.participantId});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.participants,
        services.schedule,
        services.clock,
      ]),
      builder: (context, _) {
        final p = services.participants[participantId];
        if (p == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Participant not found',
            ),
          );
        }
        final now = services.clock.now();
        final day = ParticipantDay.resolve(
          store: services.schedule,
          participantId: p.id,
          now: now,
        );
        final events = services.schedule
            .staffEventsOn(now)
            .where((e) => e.isAssignedTo(p.id))
            .toList();
        final wide =
            MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

        final todayCard = SectionCard(
          title: 'Today',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLine(
                icon: Icons.radio_button_checked_rounded,
                text: 'Now: ${ParticipantStatusList.describe(day.current)}',
              ),
              if (day.nextActivity != null)
                InfoLine(
                  icon: Icons.arrow_downward_rounded,
                  text:
                      'Next: ${day.nextActivity!.event!.title} at '
                      '${TimeFormat.hm(day.nextActivity!.start)}',
                ),
              if (day.hasPendingChanges)
                const InfoLine(
                  icon: Icons.mark_chat_unread_outlined,
                  text: 'A published change has not been acknowledged yet.',
                ),
              const Divider(height: AppSpace.xl),
              for (final e in events)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    CategoryStyle.of(e.category, context.palette).icon,
                    color: CategoryStyle.of(e.category, context.palette).color,
                  ),
                  title: Text(
                    e.title,
                    style: TextStyle(
                      decoration: e.isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(TimeFormat.range(e.start, e.end)),
                  trailing: EventStatusBadges(
                    event: e,
                    isDraft: services.schedule.hasDraft(e.id),
                  ),
                  onTap: () => showEventDetails(context, e.id),
                ),
            ],
          ),
        );

        final prefsCard = SectionCard(
          title: 'Support & Display Preferences',
          child: ProfilePreferencesEditor(
            profile: p.profile,
            onChanged: (profile) =>
                services.participants.updateProfile(p.id, profile),
          ),
        );

        return Scaffold(
          appBar: AppBar(title: Text(p.displayName)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              PageHeader(
                title: p.displayName,
                subtitle: p.livingGroup,
                actions: [
                  FilledButton.icon(
                    onPressed: () =>
                        showParticipantPreview(context, participantIds: [p.id]),
                    icon: const Icon(Icons.phone_android_rounded),
                    label: const Text('Preview as Participant'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showAssignRoutineDialog(
                      context,
                      initialParticipantIds: {p.id},
                    ),
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Assign Routine'),
                  ),
                ],
              ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: todayCard),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(child: prefsCard),
                  ],
                )
              else ...[
                todayCard,
                const SizedBox(height: AppSpace.lg),
                prefsCard,
              ],
            ],
          ),
        );
      },
    );
  }
}
