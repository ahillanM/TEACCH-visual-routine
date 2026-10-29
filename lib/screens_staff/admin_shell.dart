import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/time/time_format.dart';
import '../theme.dart';
import 'library/library_page.dart';
import 'participants/participants_page.dart';
import 'routines/routines_page.dart';
import 'schedule/schedule_page.dart';
import 'settings/admin_settings_page.dart';
import 'today/admin_today_page.dart';

/// One entry of the professional navigation.
class AdminDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AdminDestination(this.label, this.icon, this.selectedIcon);
}

const adminDestinations = <AdminDestination>[
  AdminDestination('Today', Icons.dashboard_outlined, Icons.dashboard_rounded),
  AdminDestination('Participants', Icons.groups_outlined, Icons.groups_rounded),
  AdminDestination('Schedule', Icons.calendar_month_outlined,
      Icons.calendar_month_rounded),
  AdminDestination('Routines', Icons.view_list_outlined, Icons.view_list_rounded),
  AdminDestination('Library', Icons.collections_bookmark_outlined,
      Icons.collections_bookmark_rounded),
  AdminDestination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

/// Professional interface: sidebar on desktop/tablet, drawer on phones.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  Widget _page() => switch (_index) {
        0 => AdminTodayPage(onNavigate: _go),
        1 => const ParticipantsPage(),
        2 => const SchedulePage(),
        3 => const RoutinesPage(),
        4 => const LibraryPage(),
        _ => const AdminSettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= AppBreakpoints.compact;
    final extended = width >= AppBreakpoints.expanded;
    final palette = context.palette;

    final page = KeyedSubtree(key: ValueKey(_index), child: _page());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: palette.border)),
        title: Row(
          children: [
            Icon(Icons.view_day_rounded, color: palette.brand),
            const SizedBox(width: AppSpace.sm),
            const Flexible(
              child: Text('BBW Visual Planner · Staff',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: const [_ClockChip(), SizedBox(width: AppSpace.md)],
      ),
      drawer: useRail
          ? null
          : NavigationDrawer(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                Navigator.pop(context);
                _go(i);
              },
              children: [
                const SizedBox(height: AppSpace.lg),
                for (final d in adminDestinations)
                  NavigationDrawerDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  extended: extended,
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final d in adminDestinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: palette.border),
                Expanded(child: page),
              ],
            )
          : page,
    );
  }
}

/// Shows the (possibly simulated) app time so demos are unambiguous.
class _ClockChip extends StatelessWidget {
  const _ClockChip();

  @override
  Widget build(BuildContext context) {
    final clock = AppScope.of(context).clock;
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => Chip(
        avatar: const Icon(Icons.schedule_rounded, size: 18),
        label: Text('${TimeFormat.hm(clock.now())}'
            '${clock.isShifted ? ' (demo)' : ''}'),
      ),
    );
  }
}
