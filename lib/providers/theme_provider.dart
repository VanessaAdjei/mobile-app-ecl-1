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
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadThemePreference() async {
    final preference = await _service.getTheme();
    _isDarkMode = preference.isDarkMode;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _service.setTheme(ThemePreference(isDarkMode: _isDarkMode));
    notifyListeners();
  }
}
