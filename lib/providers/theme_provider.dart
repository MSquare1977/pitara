import 'package:flutter/material.dart';

/// Lets the user override the device's light/dark setting from inside the app.
/// Starts following the system, then cycles system -> light -> dark on tap.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
