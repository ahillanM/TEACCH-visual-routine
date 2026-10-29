import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/change_notice_builder.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'change_notice_view.dart';

/// Today's acknowledged plan changes. Cancelled activities stay visible
/// here instead of cluttering the active feed.
class ChangeHistorySheet extends StatelessWidget {
  final String participantId;

  const ChangeHistorySheet({super.key, required this.participantId});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.schedule;
    final today = services.clock.now();
    final changes = store
        .participantChangesOn(participantId, today)
        .where((c) => c.version <= store.acknowledgedVersionFor(participantId))
        .toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text("Today's plan changes",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            if (changes.isEmpty)
              const EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No changes today',
                message: 'Your plan is the same as it was planned.',
              ),
            for (final c in changes) ...[
              Text('Changed at ${TimeFormat.hm(c.publishedAt)}',
                  style: TextStyle(color: context.palette.textSecondary)),
              const SizedBox(height: AppSpace.sm),
              ChangeNoticeView(
                notice: ChangeNoticeBuilder.build(
                  changes: [c],
                  after: store.snapshotAt(c.version),
                  participantId: participantId,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
