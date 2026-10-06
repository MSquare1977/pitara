import 'package:google_sign_in/google_sign_in.dart';

/// Wraps google_sign_in's v7 singleton API. Deliberately uses the simple
/// direct-await pattern (not the authenticationEvents stream the package
/// docs also offer) — the stream approach has a known issue in early 7.x
/// releases, and we don't need its extra complexity for this foundational
/// sign-in-only phase.
class AuthService {
  // From Google Cloud Console → Credentials → the "Web application" type
  // OAuth client (NOT the Android one) → Client ID.
  // Required by google_sign_in even on Android — it's used to request an
  // ID token tied to this project, separate from the Android client that
  // Google Play Services matches by package name + SHA-1.
  static const String _serverClientId =
      '317838821525-809uveohol648uo4st0l3hnr4gviimga.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Tries to restore a previous session without showing any UI. Call once
  /// at app startup. Returns null if there's no previous session to restore
  /// — this one case is expected and fine to swallow, since "no session
  /// yet" isn't an error.
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    await _ensureInitialized();
    try {
      return await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      return null;
    }
  }

  /// Shows the account picker / sign-in UI. Lets real errors propagate
  /// (don't swallow them) so a genuine failure is visible instead of
  /// silently doing nothing.
  Future<GoogleSignInAccount?> signInInteractively() async {
    await _ensureInitialized();
    return _googleSignIn.authenticate();
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}