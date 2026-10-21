import 'package:flutter/material.dart';
import '../data/services/local_store.dart';

/// Light / dark / follow-the-phone appearance, remembered on this device.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = switch (LocalStore.getString(_key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  ThemeMode get mode => _mode;

  void setMode(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    LocalStore.setString(_key, m.name);
    notifyListeners();
  }

  /// Flips between light and dark (resolving "system" first).
  void toggle(BuildContext context) {
    final darkNow = Theme.of(context).brightness == Brightness.dark;
    setMode(darkNow ? ThemeMode.light : ThemeMode.dark);
  }
}
