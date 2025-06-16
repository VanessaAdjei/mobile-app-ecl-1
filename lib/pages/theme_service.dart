import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String darkModeKey = "dark_mode";

  static Future<void> saveDarkModePreference(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModeKey, isDarkMode);
  }

  static Future<bool> loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(darkModeKey) ?? false;
  }
}
