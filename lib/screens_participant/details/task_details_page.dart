import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/app_user.dart';
import '../../core/models/feed_entry.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../participant_presentation_scope.dart';

/// Optional extra information for one activity. The feed card alone is
/// always enough to understand the schedule; this page adds detail.
class TaskDetailsPage extends StatelessWidget {
  final FeedEntry entry;

  const TaskDetailsPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final event = entry.event!;
    final services = AppScope.of(context);
    final library = services.library;
    // Only the signed-in participant can mark their own activity as done
    // (not staff using "Preview as participant").
    final user = services.auth.user;
    final participantId =
        user?.role == Role.participant ? user!.participantId : null;
    final presentation = ParticipantPresentationScope.of(context);
    final style = CategoryStyle.of(event.category);
    final place = library.place(event.placeId);
    final contact = library.contact(event.contactId);
    final next = entry.nextEvent;
    final description =
        library.activity(event.libraryActivityId)?.participantDescription;

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: MaxWidth(
        maxWidth: AppBreakpoints.participantMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            ActivityVisual(
              visual: event.visual,
              accent: style.color,
              semanticLabel: event.title,
              height: 240,
              showPhoto: presentation.showPhoto,
              showSymbol: presentation.showSymbol,
            ),
            const SizedBox(height: AppSpace.lg),
            Semantics(
              header: true,
              child: Text(event.title,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(TimeFormat.range(event.start, event.end),
                style: Theme.of(context).textTheme.titleLarge),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Text(description, style: const TextStyle(fontSize: 17)),
            ],
            const SizedBox(height: AppSpace.lg),
            if (place != null)
              _Section(
                label: 'Where',
                child: InfoLine(
                  icon: Icons.place_outlined,
                  text: '${place.name}\n${place.participantDescription}',
                ),
              ),
            if (contact != null)
              _Section(
                label: 'With',
                child: InfoLine(
                  icon: Icons.person_outline_rounded,
                  text: '${contact.name} · ${contact.roleLabel}',
                ),
              ),
            if (event.whatToBring.isNotEmpty)
              _Section(
                label: 'What to bring',
                child: Column(
                  children: [
                    for (final item in event.whatToBring)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.xs),
                        child: InfoLine(
                            icon: Icons.backpack_outlined, text: item),
                      ),
                  ],
                ),
              ),
            if (event.instructions != null && event.instructions!.isNotEmpty)
              _Section(
                label: 'What to do',
                child: Text(event.instructions!,
                    style: const TextStyle(fontSize: 17, height: 1.4)),
              ),
            if (next != null)
              _Section(
                label: 'Afterwards',
                child: InfoLine(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  text: '${next.title} at ${TimeFormat.hm(next.start)}'
                      '${next.placeId == null ? '' : ' · ${library.placeName(next.placeId)}'}',
                ),
              ),
            const SizedBox(height: AppSpace.md),
            if (participantId != null) ...[
              ListenableBuilder(
                listenable: services.progress,
                builder: (context, _) {
                  final done = services.progress.isDone(event.id, participantId);
                  return SizedBox(
                    height: kLargeTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: () => services.progress
                          .setDone(event.id, participantId, !done),
                      icon: Icon(done
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded),
                      label: Text(done ? 'Done ✓  (tap to undo)' : 'I am done'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpace.md),
            ],
            SizedBox(
              height: kLargeTouchTarget,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to my day'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(label), child],
      ),
    );
  }
}
