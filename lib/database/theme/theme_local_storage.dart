// database/theme/theme_local_storage.dart
// Persistence layer for theme preference. Used only by ThemeRepository.

import 'package:shared_preferences/shared_preferences.dart';

abstract class ThemeLocalStorage {
  Future<bool> getDarkMode();
  Future<void> setDarkMode(bool value);
}

class ThemeLocalStorageImpl implements ThemeLocalStorage {
  static const String _keyDarkMode = 'darkMode';

  @override
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  @override
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }
}
