import 'package:flutter/material.dart';

import '../../core/logic/change_notice_builder.dart';
import '../../core/models/change_event.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'change_notice_view.dart';

/// What the participant chose on the change notice.
enum ChangeNoticeResult { understood, needHelp }

/// Full-screen "PLAN CHANGED" page with "I understand", "More information"
/// and "I need help". Returns a [ChangeNoticeResult] when popped.
class ChangeNoticePage extends StatefulWidget {
  final ChangeNoticeData notice;
  final List<ChangeEvent> changes;

  /// When true (staff preview) the buttons do nothing.
  final bool previewOnly;

  const ChangeNoticePage({
    super.key,
    required this.notice,
    required this.changes,
    this.previewOnly = false,
  });

  @override
  State<ChangeNoticePage> createState() => _ChangeNoticePageState();
}

class _ChangeNoticePageState extends State<ChangeNoticePage> {
  bool _showMore = false;

  void _close(ChangeNoticeResult result) {
    if (widget.previewOnly) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan changed'),
        automaticallyImplyLeading: !widget.previewOnly,
      ),
      body: MaxWidth(
        maxWidth: AppBreakpoints.participantMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Semantics(
              header: true,
              child: Text('Your plan has changed.',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpace.lg),
            ChangeNoticeView(notice: widget.notice),
            if (_showMore) _MoreInformation(changes: widget.changes),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: kLargeTouchTarget,
              child: FilledButton.icon(
                onPressed: () => _close(ChangeNoticeResult.understood),
                icon: const Icon(Icons.check_rounded),
                label: const Text('I understand'),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: kLargeTouchTarget,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore
                    ? Icons.expand_less_rounded
                    : Icons.info_outline_rounded),
                label: Text(_showMore ? 'Less information' : 'More information'),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: kLargeTouchTarget,
              child: OutlinedButton.icon(
                onPressed: () => _close(ChangeNoticeResult.needHelp),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('I need help'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreInformation extends StatelessWidget {
  final List<ChangeEvent> changes;
  const _MoreInformation({required this.changes});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.lg),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Text(
                'Changed by ${c.publishedBy} at ${TimeFormat.hm(c.publishedAt)}.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: AppSpace.xs),
          const Text(
            'Your support team planned this change. '
            'If something is unclear, press "I need help".',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
