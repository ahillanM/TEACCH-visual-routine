import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'auth_service.dart';

/// Holds authentication state for the app. Screens never store login state
/// themselves – they read it from here.
class AuthController extends ChangeNotifier {
  final AuthService _service;

  AuthController(this._service);

  AppUser? _user;
  bool _busy = false;
  String? _error;

  /// In-memory only: pre-fills the username after sign-out when the user
  /// chose "Remember me". Persisting it needs a storage package (future).
  String? _rememberedUsername;

  AppUser? get user => _user;
  bool get isBusy => _busy;
  String? get error => _error;
  String? get rememberedUsername => _rememberedUsername;

  Future<bool> signIn({
    required String username,
    required String password,
    bool remember = false,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signIn(username: username, password: password);
      _rememberedUsername = remember ? username.trim() : null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Sign-in is not possible right now. Please try again later.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
