import '../models/app_user.dart';

/// Every action that is permission-checked in the UI.
enum Permission {
  viewOwnSchedule,
  acknowledgeChanges,
  requestSupport,
  viewAllSchedules,
  editSchedules,
  publishChanges,
  manageParticipants,
  manageRoutines,
  manageLibrary,
}

/// The single place where roles map to permissions.
///
/// NOTE: this is UI-level gating only. Production use requires the same
/// rules to be enforced server-side (e.g. Supabase row-level security);
/// hiding a button in the frontend is not authorisation.
abstract final class RolePermissions {
  static const _participant = {
    Permission.viewOwnSchedule,
    Permission.acknowledgeChanges,
    Permission.requestSupport,
  };

  static const _staff = {
    Permission.viewAllSchedules,
    Permission.editSchedules,
    Permission.publishChanges,
    Permission.manageParticipants,
    Permission.manageRoutines,
  };

  static const _admin = {
    ..._staff,
    Permission.manageLibrary,
  };

  static Set<Permission> of(Role role) => switch (role) {
        Role.participant => _participant,
        Role.staff => _staff,
        Role.admin => _admin,
      };

  static bool can(AppUser? user, Permission permission) =>
      user != null && of(user.role).contains(permission);

  static bool isProfessional(AppUser? user) =>
      user != null && user.role != Role.participant;
}
