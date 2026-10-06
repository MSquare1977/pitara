import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
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

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: scheme.primary),
              const SizedBox(height: 16),
              const Text('Pitara is locked',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                ),
              FilledButton.icon(
                onPressed: _authenticating ? null : _attemptUnlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(_authenticating ? 'Checking...' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
