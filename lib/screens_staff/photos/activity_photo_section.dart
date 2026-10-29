import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/participant.dart';
import '../../core/models/scheduled_event.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/staff_widgets.dart';
import 'activity_photo_dialog.dart';

/// "Photo" block of the staff event details: per assigned participant, add,
/// change or remove a custom photo. Hidden when photos are unavailable.
///
/// Photos belong to published activities only, because the stored photo is
/// attached to the participant's published schedule entry.
class ActivityPhotoSection extends StatelessWidget {
  final ScheduledEvent event;
  final bool isPublished;
  final bool isDraft;

  const ActivityPhotoSection({
    super.key,
    required this.event,
    required this.isPublished,
    required this.isDraft,
  });

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final photos = services.photos;
    if (photos == null || event.isCancelled) return const SizedBox.shrink();
    final palette = context.palette;
    final people = [
      for (final id in event.assignedParticipantIds) ?services.participants[id],
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Photo'),
        if (people.isEmpty)
          Text(
            'Assign participants to add a photo.',
            style: TextStyle(color: palette.textSecondary),
          )
        else if (!isPublished || isDraft)
          const InfoLine(
            icon: Icons.info_outline_rounded,
            text: 'Publish this activity first, then add a photo.',
          )
        else
          for (final p in people)
            _PersonPhotoRow(
              event: event,
              participant: p,
              hasPhoto: photos.hasPhoto(event.id, p.id),
            ),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }
}

class _PersonPhotoRow extends StatelessWidget {
  final ScheduledEvent event;
  final Participant participant;
  final bool hasPhoto;

  const _PersonPhotoRow({
    required this.event,
    required this.participant,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ParticipantAvatar(participant: participant),
      title: Text(
        participant.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Row(
        children: [
          Icon(
            hasPhoto ? Icons.photo_outlined : Icons.interests_outlined,
            size: 16,
            color: palette.textSecondary,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(hasPhoto ? 'Custom photo' : 'Pictogram'),
        ],
      ),
      trailing: OutlinedButton.icon(
        onPressed: () => showActivityPhotoDialog(
          context,
          event: event,
          participant: participant,
        ),
        icon: Icon(hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined),
        label: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
      ),
    );
  }
}
