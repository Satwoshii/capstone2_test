import 'package:flutter/material.dart';
import 'local_db_service.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static const String _themeKey = 'themeMode';

  Future<void> init() async {
    final savedTheme = await LocalDbService.instance.getConfig(_themeKey);
    if (savedTheme != null) {
      if (savedTheme == 'dark') {
        themeMode.value = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        themeMode.value = ThemeMode.light;
      } else {
        themeMode.value = ThemeMode.system;
      }
    }
  }

  Future<void> toggleTheme() async {
    if (themeMode.value == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    String value = 'light';
    if (mode == ThemeMode.dark) {
      value = 'dark';
    } else if (mode == ThemeMode.system) {
      value = 'system';
    }
    await LocalDbService.instance.setConfig(_themeKey, value);
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
}
