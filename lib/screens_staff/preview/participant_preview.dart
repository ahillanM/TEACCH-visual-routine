import 'package:flutter/material.dart';

import '../../core/logic/participant_day.dart';
import '../../core/models/change_event.dart';
import '../../core/models/participant.dart';
import '../../core/models/schedule_snapshot.dart';
import '../../screens_participant/changes/change_notice_page.dart';
import '../../screens_participant/participant_presentation_scope.dart';
import '../../screens_participant/today/participant_today_view.dart';
import '../../theme.dart';

enum _PreviewMode { today, notice, after }

/// "Preview as participant": renders the REAL participant widgets
/// ([ParticipantTodayView], [ChangeNoticePage]) inside a phone frame with
/// the participant's own profile. Nothing is duplicated, so preview and the
/// real participant experience cannot drift apart.
class ParticipantPreview extends StatefulWidget {
  final Participant participant;
  final DateTime now;

  /// What the participant currently sees.
  final ScheduleSnapshot displayed;

  /// The (possibly hypothetical, unpublished) latest version.
  final ScheduleSnapshot latest;
  final List<ChangeEvent> pendingChanges;

  const ParticipantPreview({
    super.key,
    required this.participant,
    required this.now,
    required this.displayed,
    required this.latest,
    this.pendingChanges = const [],
  });

  @override
  State<ParticipantPreview> createState() => _ParticipantPreviewState();
}

class _ParticipantPreviewState extends State<ParticipantPreview> {
  _PreviewMode? _mode;

  @override
  Widget build(BuildContext context) {
    final day = ParticipantDay.fromSnapshots(
      participantId: widget.participant.id,
      now: widget.now,
      displayed: widget.displayed,
      latest: widget.latest,
      pendingChanges: widget.pendingChanges,
    );
    final hasChanges = day.hasPendingChanges;
    final mode = _mode ?? (hasChanges ? _PreviewMode.notice : _PreviewMode.today);

    final dayAfter = ParticipantDay.fromSnapshots(
      participantId: widget.participant.id,
      now: widget.now,
      displayed: widget.latest,
      latest: widget.latest,
      pendingChanges: const [],
    );

    final Widget screen = switch (mode) {
      _PreviewMode.today => ParticipantTodayView(day: day),
      _PreviewMode.notice => ChangeNoticePage(
          notice: day.notice,
          changes: widget.pendingChanges,
          previewOnly: true,
        ),
      _PreviewMode.after => ParticipantTodayView(day: dayAfter),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasChanges)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: SegmentedButton<_PreviewMode>(
              segments: const [
                ButtonSegment(
                    value: _PreviewMode.today,
                    label: Text('Before'),
                    icon: Icon(Icons.view_day_outlined)),
                ButtonSegment(
                    value: _PreviewMode.notice,
                    label: Text('Plan Changed'),
                    icon: Icon(Icons.published_with_changes_rounded)),
                ButtonSegment(
                    value: _PreviewMode.after,
                    label: Text('After "I understand"'),
                    icon: Icon(Icons.check_rounded)),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
        PhoneFrame(
          child: ParticipantPresentationScope(
            profile: widget.participant.profile,
            child: Builder(
              builder: (context) => Material(
                color: context.palette.background,
                child: KeyedSubtree(
                  key: ValueKey('${widget.participant.id}-$mode'),
                  child: screen,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A simple phone-sized frame for previews.
class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  static const Size size = Size(380, 700);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Participant Preview',
      container: true,
      child: Container(
        width: size.width,
        height: size.height,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: context.palette.previewFrame,
          borderRadius: BorderRadius.circular(36),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(size.width - AppSpace.lg, size.height - AppSpace.lg),
              padding: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
