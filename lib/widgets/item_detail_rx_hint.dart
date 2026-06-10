import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spotlight_tour.dart';

/// One-time coach mark on prescription product pages — highlights upload CTA.
class ItemDetailRxHint {
  ItemDetailRxHint._();

  static const String _prefKey = 'has_seen_item_detail_rx_hint';

  static bool _targetReady(GlobalKey key) {
    final rect = SpotlightTour.targetRect(key);
    return rect != null && rect.width > 8 && rect.height > 8;
  }

  /// Returns true if the overlay was shown.
  static Future<bool> maybeStart({
    required BuildContext context,
    required GlobalKey uploadButtonKey,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_prefKey) ?? false)) {
      if (kDebugMode) debugPrint('ItemDetailRxHint: skipped — already seen');
      return false;
    }
    if (!(prefs.getBool('hasLaunchedBefore') ?? false)) {
      if (kDebugMode) {
        debugPrint('ItemDetailRxHint: skipped — onboarding not finished');
      }
      return false;
    }
    if (!context.mounted) return false;

    if (force) {
      await prefs.setBool(_prefKey, false);
    }

    for (var i = 0; i < 80; i++) {
      if (!context.mounted) return false;
      if (_targetReady(uploadButtonKey)) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!_targetReady(uploadButtonKey) || !context.mounted) {
      if (kDebugMode) {
        debugPrint('ItemDetailRxHint: skipped — upload button not laid out');
      }
      return false;
    }

    if (kDebugMode) debugPrint('ItemDetailRxHint: showing');
    await SpotlightTour.show(
      context: context,
      steps: [
        SpotlightStep(
          targetKey: uploadButtonKey,
          title: 'Prescription required',
          body:
              'Tap here to upload your prescription before checkout. Our pharmacist will review it.',
          align: SpotlightTooltipAlign.above,
          padding: 6,
        ),
      ],
      onFinished: () {
        unawaited(prefs.setBool(_prefKey, true));
      },
    );
    return true;
  }
}
