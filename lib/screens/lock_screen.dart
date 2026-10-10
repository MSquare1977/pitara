import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Defers entirely to whatever the device already uses — Face ID,
/// fingerprint, PIN, or pattern. We never see or store the credential
/// ourselves; local_auth just asks the OS "did this person pass device
/// unlock?" and returns yes/no.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attemptUnlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock whenever the app returns from the background.
    if (state == AppLifecycleState.resumed && !_unlocked) {
      _attemptUnlock();
    }
  }

  Future<void> _attemptUnlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        // Device has no biometrics/PIN configured at all — let the user
        // through rather than lock them out of a feature the device can't do.
        setState(() {
          _unlocked = true;
          _authenticating = false;
        });
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock Pitara',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows fallback to device PIN/pattern
          stickyAuth: true,
        ),
      );

      setState(() {
        _unlocked = didAuthenticate;
        _authenticating = false;
        if (!didAuthenticate) _error = 'Authentication failed';
      });
    } catch (e) {
      setState(() {
        _authenticating = false;
        _error = 'Could not authenticate';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const HomeScreen();

    // Always navy + brass (like the splash screen), regardless of light/dark
    // mode — the lock screen is the first impression and should feel like
    // a vault door, not a form.
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.navy700, AppTheme.navy800, AppTheme.navy900],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.brassLight.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppTheme.brassLight.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brassLight.withValues(alpha: 0.22),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded, size: 52, color: AppTheme.brassLight),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Pitara',
                    style: TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ivory,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your documents, locked down.',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0.4,
                      color: AppTheme.ivory.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
                      ),
                    ),
                  SizedBox(
                    width: 240,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brassLight,
                        foregroundColor: AppTheme.navy800,
                      ),
                      onPressed: _authenticating ? null : _attemptUnlock,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(_authenticating ? 'Checking...' : 'Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}