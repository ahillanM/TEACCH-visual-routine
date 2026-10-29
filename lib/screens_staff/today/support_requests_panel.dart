import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/support_request.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import '../common/staff_widgets.dart';

/// Participant support requests with OPEN → ACKNOWLEDGED → RESOLVED.
class SupportRequestsPanel extends StatelessWidget {
  const SupportRequestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final requests = services.support.unresolved;
    return SectionCard(
      title: 'Support Requests',
      child: requests.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No open support requests')
          : Column(
              children: [
                for (final r in requests) _RequestTile(request: r),
              ],
            ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final SupportRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final palette = context.palette;
    final participant = services.participants[request.participantId];
    final open = request.status == SupportStatus.open;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (participant != null) ParticipantAvatar(participant: participant),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(services.participants.nameOf(request.participantId),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    StatusBadge(
                      label: open ? 'Open' : 'Acknowledged',
                      icon: open
                          ? Icons.notifications_active_outlined
                          : Icons.visibility_outlined,
                      color: open ? palette.brand : palette.textSecondary,
                      fontSize: 11,
                    ),
                  ],
                ),
                Text('"${request.reason.label}"'),
                Text(
                  '${TimeFormat.hm(request.createdAt)}'
                  '${request.currentActivityTitle == null ? '' : ' · during ${request.currentActivityTitle}'}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (open)
            TextButton(
              onPressed: () => services.support
                  .setStatus(request.id, SupportStatus.acknowledged),
              child: const Text('Acknowledge'),
            ),
          TextButton(
            onPressed: () =>
                services.support.setStatus(request.id, SupportStatus.resolved),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }
}
