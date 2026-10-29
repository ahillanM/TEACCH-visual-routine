import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../changes/change_management_page.dart';
import '../common/staff_widgets.dart';
import '../editor/activity_editor_page.dart';
import '../preview/participant_preview_dialog.dart';

/// Opens the activity editor for a new or existing event.
Future<void> openActivityEditor(
  BuildContext context, {
  ScheduledEvent? event,
  required DateTime day,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ActivityEditorPage(initial: event, day: day),
  ));
}

/// Opens the cancellation / change management flow.
Future<void> openChangeManagement(BuildContext context, String eventId) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChangeManagementPage(eventId: eventId),
  ));
}

/// Details and actions for one event in the staff calendar.
Future<void> showEventDetails(BuildContext context, String eventId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventDetailSheet(eventId: eventId),
  );
}

class _EventDetailSheet extends StatelessWidget {
  final String eventId;
  const _EventDetailSheet({required this.eventId});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.schedule;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final event = store.staffEvent(eventId);
        if (event == null) {
          return const EmptyState(
              icon: Icons.event_busy_outlined, title: 'Activity not found');
        }
        final isDraft = store.hasDraft(eventId);
        final isPublished = store.published[eventId] != null;
        final library = services.library;
        final names = (event.assignedParticipantIds
                .map(services.participants.nameOf)
                .toList()
              ..sort())
            .join(', ');
        final style = CategoryStyle.of(event.category, context.palette);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(style.icon, color: style.color),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(event.title,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                EventStatusBadges(event: event, isDraft: isDraft),
                const SizedBox(height: AppSpace.md),
                InfoLine(
                    icon: Icons.schedule_rounded,
                    text: '${TimeFormat.longDate(event.start)}, '
                        '${TimeFormat.range(event.start, event.end)}'),
                const SizedBox(height: AppSpace.xs),
                InfoLine(
                    icon: Icons.place_outlined,
                    text: library.placeName(event.placeId)),
                const SizedBox(height: AppSpace.xs),
                InfoLine(
                    icon: Icons.person_outline_rounded,
                    text: library.contactName(event.contactId)),
                const SizedBox(height: AppSpace.xs),
                InfoLine(
                    icon: Icons.groups_outlined,
                    text: names.isEmpty ? 'No participants assigned' : names),
                const SizedBox(height: AppSpace.xl),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    if (!event.isCancelled)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          openActivityEditor(context,
                              event: event, day: event.start);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    if (isPublished && event.isActive && !isDraft)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          openChangeManagement(context, event.id);
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('Cancel activity…'),
                      ),
                    if (event.assignedParticipantIds.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => showParticipantPreview(
                          context,
                          participantIds:
                              event.assignedParticipantIds.toList()..sort(),
                        ),
                        icon: const Icon(Icons.phone_android_rounded),
                        label: const Text('Preview as Participant'),
                      ),
                    if (isDraft) ...[
                      FilledButton.icon(
                        onPressed: () {
                          store.publish(
                            upserts: [event],
                            publishedBy:
                                services.auth.user?.displayName ?? 'Staff',
                          );
                          Navigator.pop(context);
                          showStaffMessage(context, 'Draft published.');
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Publish Draft'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          store.discardDraft(event.id);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Discard Draft'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
