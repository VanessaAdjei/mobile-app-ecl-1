import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/terms_acceptance_page.dart';

/// Ensures app-level terms acceptance before signup or other gated flows.
class TermsGate {
  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('terms_accepted') ?? false;
  }

  /// Shows [TermsAcceptancePage] when needed. Returns whether terms are accepted.
  static Future<bool> ensureAccepted(BuildContext context) async {
    if (await isAccepted()) return true;
    if (!context.mounted) return false;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TermsAcceptancePage(
          onAccepted: () => Navigator.pop(context),
        ),
      ),
    );

    return isAccepted();
  }
}
