// services/theme_service.dart
// Use-case layer for theme. Calls Repository only; no direct DB access.

import '../models/theme_preference.dart';
import '../repositories/theme_repository.dart';

class ThemeService {
  ThemeService([ThemeRepository? repository])
      : _repository = repository ?? ThemeRepositoryImpl();

  final ThemeRepository _repository;

  Future<ThemePreference> getTheme() async {
    return _repository.getThemePreference();
  }

  Future<void> setTheme(ThemePreference preference) async {
    await _repository.setThemePreference(preference);
  }
}
