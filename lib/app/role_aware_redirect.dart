import 'package:flutter/material.dart';

import '../core/auth/permissions.dart';
import '../core/models/app_user.dart';
import '../screens_auth/login_page.dart';
import '../screens_participant/participant_shell.dart';
import '../screens_staff/admin_shell.dart';
import 'app_scope.dart';
import 'role_guard.dart';

/// The one place that decides which interface a user sees.
///
/// * signed out → [LoginPage]
/// * participant → [ParticipantShell] (no professional features exist there)
/// * staff / admin → [AdminShell], additionally wrapped in a [RoleGuard]
class RoleAwareRedirect extends StatelessWidget {
  const RoleAwareRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.user;
        if (user == null) return const LoginPage();
        return switch (user.role) {
          Role.participant => user.participantId == null
              ? const LoginPage()
              : ParticipantShell(
                  key: ValueKey(user.id),
                  participantId: user.participantId!,
                ),
          Role.staff || Role.admin => RoleGuard(
              key: ValueKey(user.id),
              permission: Permission.viewAllSchedules,
              child: const AdminShell(),
            ),
        };
      },
    );
  }
}
