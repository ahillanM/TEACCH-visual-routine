import 'package:flutter/material.dart';

import '../core/models/app_user.dart';
import '../theme.dart';
import 'admin_theme.dart';
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
  final _adminTheme = AdminThemeController();

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
    _adminTheme.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: AdminThemeScope(
        controller: _adminTheme,
        child: ListenableBuilder(
          listenable: Listenable.merge([_adminTheme, _services.auth]),
          builder: (context, _) {
            // Dark mode only applies to signed-in staff; login and the
            // participant UI stay light.
            final role = _services.auth.user?.role;
            final dark =
                _adminTheme.isDark && role != null && role != Role.participant;
            return MaterialApp(
              scaffoldMessengerKey: _messenger,
              title: 'BBW Visual Planner',
              debugShowCheckedModeBanner: false,
              theme: buildPlannerTheme(),
              darkTheme: buildPlannerTheme(dark: true),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const RoleAwareRedirect(),
            );
          },
        ),
      ),
    );
  }
}
