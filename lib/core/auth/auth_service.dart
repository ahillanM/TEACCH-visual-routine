import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Authentication boundary. The UI only talks to this interface, so the
/// mock below can be swapped for a Supabase-backed implementation (owned by
/// the backend team in `lib/services/`) without touching any screen.
abstract class AuthService {
  Future<AppUser> signIn({required String username, required String password});
  Future<void> signOut();
}

/// MOCK: in-memory demo accounts. Not secure, for the prototype only.
class MockAuthService implements AuthService {
  final Map<String, ({String password, AppUser user})> accounts;
  final Duration latency;

  const MockAuthService({
    required this.accounts,
    this.latency = const Duration(milliseconds: 400),
  });

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = accounts[username.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException(
        'That username and password do not match. Please try again.',
      );
    }
    return account.user;
  }

  @override
  Future<void> signOut() async {}
}
