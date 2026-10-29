import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/auth/auth_service.dart';
import '../core/models/app_user.dart';
import 'supabase_sync.dart';

/// Supabase email/password sign-in. The role comes only from
/// `public.profiles` (written by admins); an account without a profile row
/// has no access.
class SupabaseAuthService implements AuthService {
  final sb.SupabaseClient db;

  /// Loads the user's data before the interface is shown.
  final Future<void> Function(AppUser user) onSignedIn;
  final Future<void> Function() onSignedOut;

  SupabaseAuthService({
    required this.db,
    required this.onSignedIn,
    required this.onSignedOut,
  });

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final email = username.trim().toLowerCase();
    if (!email.contains('@')) {
      throw const AuthException('Please sign in with your email address.');
    }
    try {
      await db.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException {
      throw const AuthException(
        'That email and password do not match. Please try again.',
      );
    }
    final user = await _loadUser();
    if (user == null) {
      await db.auth.signOut();
      throw const AuthException(
        'This account has no access yet. Please ask the staff team.',
      );
    }
    await onSignedIn(user);
    return user;
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (db.auth.currentSession == null) return null;
    final user = await _loadUser();
    if (user == null) return null;
    await onSignedIn(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    await onSignedOut();
    await db.auth.signOut();
  }

  Future<AppUser?> _loadUser() async {
    final authUser = db.auth.currentUser;
    if (authUser == null) return null;
    final profile = await db
        .from('profiles')
        .select('id, display_name, role')
        .eq('id', authUser.id)
        .maybeSingle();
    if (profile == null) return null;
    final isParticipant = profile['role'] == 'participant';
    return AppUser(
      id: authUser.id,
      username: authUser.email ?? '',
      displayName: SupabaseSync.shortName(profile['display_name'] as String),
      role: isParticipant ? Role.participant : Role.staff,
      participantId: isParticipant ? authUser.id : null,
    );
  }
}
