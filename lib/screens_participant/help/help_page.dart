import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/participant_day.dart';
import '../../core/models/support_request.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';

/// HELP: large, clear options that send a (mock) support request to staff.
/// Kept separate from schedule logic – it only reads the current activity
/// title for context.
class HelpPage extends StatelessWidget {
  final String participantId;

  /// Pre-selects a reason (e.g. when coming from "I need help" on a notice).
  final SupportReason? suggestedReason;

  const HelpPage({
    super.key,
    required this.participantId,
    this.suggestedReason,
  });

  static IconData iconFor(SupportReason r) => switch (r) {
        SupportReason.dontKnowWhereToGo => Icons.wrong_location_outlined,
        SupportReason.dontUnderstand => Icons.help_outline_rounded,
        SupportReason.scheduleWrong => Icons.event_busy_outlined,
        SupportReason.needSupport => Icons.support_agent_rounded,
      };

  Future<void> _request(BuildContext context, SupportReason reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(iconFor(reason), size: 40),
        title: Text(reason.label),
        content: const Text('Send this to your support team?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final services = AppScope.of(context);
    final now = services.clock.now();
    final day = ParticipantDay.resolve(
      store: services.schedule,
      participantId: participantId,
      now: now,
    );
    services.support.create(
      participantId: participantId,
      reason: reason,
      at: now,
      currentActivityTitle: day.current.event?.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.support,
      builder: (context, _) {
        final mine = services.support.unresolved
            .where((r) => r.participantId == participantId)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Semantics(
              header: true,
              child: Text('Help',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: AppSpace.xs),
            Text('Choose what fits. Your support team will come to you.',
                style: TextStyle(
                    fontSize: 17, color: context.palette.textSecondary)),
            const SizedBox(height: AppSpace.lg),
            if (mine.isNotEmpty) ...[
              for (final r in mine) _SentRequest(request: r),
              const SizedBox(height: AppSpace.md),
            ],
            for (final reason in SupportReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _HelpOption(
                  reason: reason,
                  highlighted: reason == suggestedReason,
                  onTap: () => _request(context, reason),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HelpOption extends StatelessWidget {
  final SupportReason reason;
  final bool highlighted;
  final VoidCallback onTap;

  const _HelpOption({
    required this.reason,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: reason.label,
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: highlighted ? palette.nowAccent : palette.border,
            width: highlighted ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  Icon(HelpPage.iconFor(reason), size: 36, color: palette.brand),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Text(reason.label,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentRequest extends StatelessWidget {
  final SupportRequest request;
  const _SentRequest({required this.request});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final seen = request.status == SupportStatus.acknowledged;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(seen ? Icons.directions_walk_rounded : Icons.send_rounded,
                color: palette.brand),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seen
                        ? 'Your support team has seen your message.'
                        : 'Your message was sent at '
                            '${TimeFormat.hm(request.createdAt)}.',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(request.reason.label,
                      style: TextStyle(color: palette.textSecondary)),
                ],
              ),
            ),
            StatusBadge(
              label: seen ? 'Seen' : 'Sent',
              icon: seen ? Icons.visibility_outlined : Icons.check_rounded,
              color: palette.brand,
            ),
          ],
        ),
      ),
    );
  }
}
