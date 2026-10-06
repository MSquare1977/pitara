import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

/// This is purely an identity layer for now — signing in doesn't yet change
/// what documents are visible or where they're stored (that's Phase 4,
/// cloud sync). Today it just establishes who the signed-in account is, as
/// groundwork for later.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  GoogleSignInAccount? _user;
  bool _loading = false;
  String? _lastError;

  GoogleSignInAccount? get user => _user;
  bool get isSignedIn => _user != null;
  bool get loading => _loading;
  String? get lastError => _lastError;

  Future<void> tryRestoreSession() async {
    _loading = true;
    notifyListeners();
    _user = await _authService.attemptSilentSignIn();
    _loading = false;
    notifyListeners();
  }

  /// Throws on failure so the UI can show the real error — callers should
  /// wrap this in a try/catch rather than relying on a silent null return.
  Future<void> signIn() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      _user = await _authService.signInInteractively();
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }
}