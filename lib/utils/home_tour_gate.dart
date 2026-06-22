import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Blocks the main tab shell until the home spotlight tour is skipped or completed.
class HomeTourGate {
  HomeTourGate._();

  static final ValueNotifier<bool> blocking = ValueNotifier<bool>(false);

  static void arm() {
    if (blocking.value) return;
    blocking.value = true;
  }

  static void release() {
    if (!blocking.value) return;
    blocking.value = false;
  }

  static Future<bool> shouldBlockForTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_seen_smart_tips') ?? false) return false;
    return prefs.getBool('hasLaunchedBefore') ?? false;
  }

  static Future<void> armIfTourPending() async {
    if (await shouldBlockForTour()) arm();
  }
}
