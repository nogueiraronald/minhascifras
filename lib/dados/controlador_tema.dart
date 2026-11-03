import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerenciador de tema (Modo Claro / Modo Escuro) com persistência local.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  static const _kThemeKey = 'app_theme_mode_v1';
  final SharedPreferences _prefs;

  static Future<ThemeController> open() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeController(prefs);
  }

  ThemeMode get themeMode {
    final val = _prefs.getString(_kThemeKey);
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  bool isDark(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> toggle(BuildContext context) async {
    final currentlyDark = isDark(context);
    final next = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    await _prefs.setString(_kThemeKey, next == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    final val = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await _prefs.setString(_kThemeKey, val);
    notifyListeners();
  }
}
