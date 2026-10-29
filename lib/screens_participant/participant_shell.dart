import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models/support_request.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'help/help_page.dart';
import 'participant_presentation_scope.dart';
import 'today/today_page.dart';
import 'week/week_page.dart';

/// The participant interface: TODAY · WEEK · HELP.
///
/// Contains no editing, deleting or admin features at all. The profile is
/// applied once here (theme, text size, motion) and inherited by all pages,
/// including pages pushed on the nested navigator.
class ParticipantShell extends StatelessWidget {
  final String participantId;

  const ParticipantShell({super.key, required this.participantId});

  @override
  Widget build(BuildContext context) {
    final directory = AppScope.of(context).participants;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) {
        final participant = directory[participantId];
        if (participant == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Schedule unavailable',
              message: 'Please ask your support team.',
            ),
          );
        }
        return ParticipantPresentationScope(
          profile: participant.profile,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _ShellHome(
                participantId: participantId,
                name: participant.displayName,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShellHome extends StatefulWidget {
  final String participantId;
  final String name;

  const _ShellHome({required this.participantId, required this.name});

  @override
  State<_ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<_ShellHome> {
  static const _today = 0;
  static const _help = 2;

  int _index = _today;
  SupportReason? _suggestedReason;

  void _goToHelp(SupportReason reason) {
    setState(() {
      _index = _help;
      _suggestedReason = reason;
    });
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await AppScope.of(context).auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pages = [
      TodayPage(participantId: widget.participantId, onNeedHelp: _goToHelp),
      WeekPage(participantId: widget.participantId),
      HelpPage(
        participantId: widget.participantId,
        suggestedReason: _suggestedReason,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpace.lg,
        title: Text(
          'Hi ${widget.name}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: MaxWidth(
          maxWidth: AppBreakpoints.participantMaxWidth,
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i != _help) _suggestedReason = null;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_day_outlined),
            selectedIcon: Icon(Icons.view_day_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week_rounded),
            label: 'Week',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent_rounded),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}
