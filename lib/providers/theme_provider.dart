// providers/theme_provider.dart
// Controller: UI state for theme. Calls Service only (Route → Controller → Service → Repository → Model → Database).

import 'package:flutter/material.dart';
import 'package:eclapp/models/theme_preference.dart';
import 'package:eclapp/services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider([ThemeService? service]) : _service = service ?? ThemeService() {
    _loadThemePreference();
  }

  final ThemeService _service;
  AppThemeChoice _choice = AppThemeChoice.light;

  AppThemeChoice get themeChoice => _choice;

  ThemeMode get themeMode {
    switch (_choice) {
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
        return ThemeMode.dark;
    }
  }

  /// Effective dark state when a [BuildContext] is unavailable (legacy callers).
  bool get isDarkMode => _choice == AppThemeChoice.dark;

  static AppThemeChoice nextChoice(AppThemeChoice current) {
    return current == AppThemeChoice.light
        ? AppThemeChoice.dark
        : AppThemeChoice.light;
  }

  static IconData iconForChoice(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.light:
        return Icons.light_mode_outlined;
      case AppThemeChoice.dark:
        return Icons.dark_mode_outlined;
    }
  }

  static String shortLabel(AppThemeChoice choice) => choice.label;

  Future<void> _loadThemePreference() async {
    final preference = await _service.getTheme();
    _choice = preference.choice;
    notifyListeners();
  }

  void cycleThemeChoice() {
    setThemeChoice(nextChoice(_choice));
  }

  void setThemeChoice(AppThemeChoice choice) {
    if (_choice == choice) return;
    _choice = choice;
    _service.setTheme(ThemePreference(choice: choice));
    notifyListeners();
  }
}
