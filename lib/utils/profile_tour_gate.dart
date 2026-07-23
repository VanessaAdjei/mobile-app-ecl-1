import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/profile_page_tour.dart';

/// Blocks the main tab shell / profile UI until the profile spotlight tour
/// is skipped or completed.
class ProfileTourGate {
  ProfileTourGate._();

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
    if (prefs.getBool(kProfileTourSeenKey) ?? false) return false;
    return prefs.getBool('hasLaunchedBefore') ?? false;
  }

  static Future<void> armIfTourPending() async {
    if (await shouldBlockForTour()) arm();
  }
}
