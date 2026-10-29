import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/participant_day.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/staff_widgets.dart';
import '../today/participant_status_list.dart';
import 'participant_detail_page.dart';

/// Searchable participant list.
class ParticipantsPage extends StatefulWidget {
  const ParticipantsPage({super.key});

  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(
          [services.participants, services.schedule, services.clock]),
      builder: (context, _) {
        final results = services.participants.search(_query);
        final now = services.clock.now();
        return ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            const PageHeader(
              title: 'Participants',
              subtitle: 'Schedules, support preferences and previews',
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search participants',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: AppSpace.lg),
            if (results.isEmpty)
              const EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No participants found'),
            for (final p in results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Card(
                  child: Builder(builder: (context) {
                    final day = ParticipantDay.resolve(
                        store: services.schedule, participantId: p.id, now: now);
                    final next = day.nextActivity;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg, vertical: AppSpace.sm),
                      leading: ParticipantAvatar(participant: p, radius: 24),
                      title: Text(p.displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                        '${p.livingGroup}\n'
                        'Now: ${ParticipantStatusList.describe(day.current)}'
                        '${next == null ? '' : ' · Next: ${next.event!.title}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ParticipantDetailPage(participantId: p.id),
                      )),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}
