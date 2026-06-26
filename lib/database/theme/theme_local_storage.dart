// database/theme/theme_local_storage.dart
// Persistence layer for theme preference. Used only by ThemeRepository.

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/theme_preference.dart';

abstract class ThemeLocalStorage {
  Future<AppThemeChoice> getThemeChoice();
  Future<void> setThemeChoice(AppThemeChoice choice);
}

class ThemeLocalStorageImpl implements ThemeLocalStorage {
  static const String _keyThemeChoice = 'themeChoice';
  static const String _legacyKeyDarkMode = 'darkMode';

  @override
  Future<AppThemeChoice> getThemeChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyThemeChoice);
    if (stored != null && stored.isNotEmpty) {
      return AppThemeChoice.fromStorage(stored);
    }

    // Migrate legacy on/off toggle to explicit light/dark.
    if (prefs.containsKey(_legacyKeyDarkMode)) {
      final isDark = prefs.getBool(_legacyKeyDarkMode) ?? false;
      return isDark ? AppThemeChoice.dark : AppThemeChoice.light;
    }

    return AppThemeChoice.light;
  }

  @override
  Future<void> setThemeChoice(AppThemeChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeChoice, choice.name);
  }
}
