import 'package:flutter/material.dart';

import '../core/auth/permissions.dart';
import '../widgets/common.dart';
import 'app_scope.dart';

/// Renders [child] only if the signed-in user has [permission].
///
/// UI-level gating only – see the note in `permissions.dart`.
class RoleGuard extends StatelessWidget {
  final Permission permission;
  final Widget child;

  const RoleGuard({super.key, required this.permission, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).auth.user;
    if (RolePermissions.can(user, permission)) return child;
    return const Scaffold(
      body: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'This area is not available',
        message: 'Please ask your support team if you need something changed.',
      ),
    );
  }
}
