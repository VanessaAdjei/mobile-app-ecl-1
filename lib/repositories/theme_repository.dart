// repositories/theme_repository.dart
// Data access for theme. Uses Database (ThemeLocalStorage) and returns Model (ThemePreference).

import '../database/theme/theme_local_storage.dart';
import '../models/theme_preference.dart';

abstract class ThemeRepository {
  Future<ThemePreference> getThemePreference();
  Future<void> setThemePreference(ThemePreference preference);
}

class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl([ThemeLocalStorage? storage])
      : _storage = storage ?? ThemeLocalStorageImpl();

  final ThemeLocalStorage _storage;

  @override
  Future<ThemePreference> getThemePreference() async {
    final isDarkMode = await _storage.getDarkMode();
    return ThemePreference(isDarkMode: isDarkMode);
  }

  @override
  Future<void> setThemePreference(ThemePreference preference) async {
    await _storage.setDarkMode(preference.isDarkMode);
  }
}
