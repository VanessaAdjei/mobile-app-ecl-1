// models/theme_preference.dart
// Model for theme preference. Plain data, no logic.

enum AppThemeChoice {
  light,
  dark;

  String get label {
    switch (this) {
      case AppThemeChoice.light:
        return 'Light';
      case AppThemeChoice.dark:
        return 'Dark';
    }
  }

  static AppThemeChoice fromStorage(String? value) {
    if (value == null || value.isEmpty) return AppThemeChoice.light;
    if (value == 'system') return AppThemeChoice.light;
    for (final choice in AppThemeChoice.values) {
      if (choice.name == value) return choice;
    }
    return AppThemeChoice.light;
  }
}

class ThemePreference {
  final AppThemeChoice choice;

  const ThemePreference({this.choice = AppThemeChoice.light});

  ThemePreference copyWith({AppThemeChoice? choice}) {
    return ThemePreference(choice: choice ?? this.choice);
  }
}
