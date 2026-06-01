import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native_notification_service.dart';

/// Deferred home prompts (permissions) — spotlight is handled separately.
class HomeFirstVisitFlow {
  HomeFirstVisitFlow._();

  /// Optional permission sheet for returning users who skipped onboarding prompts.
  static Future<void> runDeferredPrompts({
    required BuildContext context,
    required Future<void> Function() showDeferredPermissionsSheet,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasLaunchedBefore') ?? false)) return;
    if (!context.mounted) return;

    final permissionsHandled =
        prefs.getBool('notification_prompt_attempted') ?? false;
    final deferredShown =
        prefs.getBool('deferred_permissions_prompt_shown') ?? false;

    if (!permissionsHandled &&
        !deferredShown &&
        context.mounted &&
        await NativeNotificationService.needsPermissionsPrompt()) {
      await showDeferredPermissionsSheet();
    }
  }
}
