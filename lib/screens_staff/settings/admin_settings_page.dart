import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/staff_widgets.dart';

/// Account info, demo clock and privacy/security notes.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  /// DEMO ONLY: useful moments of the mock training day.
  static const _demoMoments = <(String, int, int)>[
    ('Before the Day', 6, 45),
    ('Bus to BBW', 8, 40),
    ('During Workshop', 9, 40),
    ('Workshop Almost Over', 10, 56),
    ('Lunch', 11, 45),
    ('Evening', 19, 30),
  ];

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final clock = services.clock;
    final user = services.auth.user;

    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          const PageHeader(title: 'Settings'),
          SectionCard(
            title: 'Account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLine(
                    icon: Icons.badge_outlined,
                    text: '${user?.displayName ?? '—'} · ${user?.role.name ?? ''}'),
                const SizedBox(height: AppSpace.md),
                OutlinedButton.icon(
                  onPressed: () => services.auth.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            title: 'Demo time (prototype only)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current app time: ${TimeFormat.hm(clock.now())}'
                  '${clock.isShifted ? ' (simulated)' : ' (real time)'}',
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final (label, h, m) in _demoMoments)
                      ActionChip(
                        label: Text('$label (${h.toString().padLeft(2, '0')}:'
                            '${m.toString().padLeft(2, '0')})'),
                        onPressed: () => clock.setTimeOfDay(h, m),
                      ),
                    ActionChip(
                      label: const Text('+15 min'),
                      onPressed: () => clock.shift(const Duration(minutes: 15)),
                    ),
                    ActionChip(
                      label: const Text('Use Real Time'),
                      onPressed: clock.useRealTime,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const SectionCard(
            title: 'Privacy & security (prototype status)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLine(
                    icon: Icons.info_outline_rounded,
                    text: 'Demo data is fictional. Schedules, progress and support '
                        'requests are stored in Supabase (EU) over HTTPS.'),
                SizedBox(height: AppSpace.xs),
                InfoLine(
                    icon: Icons.shield_outlined,
                    text: 'Access is enforced server-side by Supabase row-level '
                        'security; the app only hides what users cannot use. Production '
                        'still needs a privacy review, rotated demo passwords '
                        'and TLS for all traffic.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
