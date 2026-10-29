import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/change_event.dart';
import '../../core/models/schedule_snapshot.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';
import 'participant_preview.dart';

/// Opens a dialog that previews one or several participants.
///
/// Without [latest]/[pendingChanges] it shows the live published state.
/// With them it previews a hypothetical (unpublished) change.
Future<void> showParticipantPreview(
  BuildContext context, {
  required List<String> participantIds,
  ScheduleSnapshot? latest,
  List<ChangeEvent> pendingChanges = const [],
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.lg),
      child: _PreviewDialogBody(
        participantIds: participantIds,
        latest: latest,
        pendingChanges: pendingChanges,
      ),
    ),
  );
}

class _PreviewDialogBody extends StatefulWidget {
  final List<String> participantIds;
  final ScheduleSnapshot? latest;
  final List<ChangeEvent> pendingChanges;

  const _PreviewDialogBody({
    required this.participantIds,
    required this.latest,
    required this.pendingChanges,
  });

  @override
  State<_PreviewDialogBody> createState() => _PreviewDialogBodyState();
}

class _PreviewDialogBodyState extends State<_PreviewDialogBody> {
  late String _selected = widget.participantIds.first;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final directory = services.participants;
    final participant = directory[_selected]!;
    final store = services.schedule;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Preview as ${participant.displayName}',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Close preview',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (widget.participantIds.length > 1) ...[
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                for (final id in widget.participantIds)
                  ChoiceChip(
                    avatar: ParticipantAvatar(
                        participant: directory[id]!, radius: 12),
                    label: Text(directory.nameOf(id)),
                    selected: id == _selected,
                    onSelected: (_) => setState(() => _selected = id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          Text(
            _profileSummary(participant.profile.informationDensity.name,
                participant.profile.visualPreference.name),
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          ParticipantPreview(
            key: ValueKey(_selected),
            participant: participant,
            now: services.clock.now(),
            displayed: widget.latest == null
                ? store.displayedSnapshotFor(_selected)
                : store.published,
            latest: widget.latest ?? store.published,
            pendingChanges: widget.latest == null
                ? store.pendingChangesFor(_selected)
                : widget.pendingChanges,
          ),
        ],
      ),
    );
  }

  String _profileSummary(String density, String visuals) =>
      'Information: $density · Visuals: $visuals';
}
