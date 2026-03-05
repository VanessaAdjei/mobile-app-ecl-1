// models/theme_preference.dart
// Model for theme preference. Plain data, no logic.

class ThemePreference {
  final bool isDarkMode;

  const ThemePreference({this.isDarkMode = false});

  ThemePreference copyWith({bool? isDarkMode}) {
    return ThemePreference(isDarkMode: isDarkMode ?? this.isDarkMode);
  }
}
