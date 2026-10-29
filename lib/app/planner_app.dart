import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_scope.dart';
import 'app_services.dart';
import 'role_aware_redirect.dart';

/// Root widget of the MVP (login → role-aware interface).
///
/// Intentionally separate from `lib/main.dart` (team rule: main.dart is only
/// changed during final integration). Run with:
///   flutter run -d chrome -t lib/main_mvp.dart
class PlannerApp extends StatefulWidget {
  final AppServices? services;

  const PlannerApp({super.key, this.services});

  @override
  State<PlannerApp> createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  late final AppServices _services = widget.services ?? AppServices.demo();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _services.errors.addListener(_showError);
    _services.auth.restoreSession();
  }

  void _showError() {
    final message = _services.errors.value;
    if (message == null) return;
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
    _services.errors.value = null;
  }

  @override
  void dispose() {
    _services.errors.removeListener(_showError);
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: MaterialApp(
        scaffoldMessengerKey: _messenger,
        title: 'BBW Visual Planner',
        debugShowCheckedModeBanner: false,
        theme: buildPlannerTheme(),
        home: const RoleAwareRedirect(),
      ),
    );
  }
}
