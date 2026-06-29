import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug console logging for the ExpressPay checkout pipeline.
/// Always prints in debug builds (not gated behind [kCheckoutVerboseLogs]).
class ExpressPayApiLog {
  static const _divider =
      '══════════════════════════════════════════════════════';

  static void section(String title) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint(_divider);
    debugPrint('[EXPRESS-PAY] $title');
    debugPrint(_divider);
  }

  static void exchange({
    required String step,
    required String method,
    required String url,
    Map<String, dynamic>? request,
    String? requestRaw,
    required int statusCode,
    String? responseBody,
    Object? error,
  }) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');

    debugPrint('');
    debugPrint(_divider);
    debugPrint('[EXPRESS-PAY] $step');
    debugPrint('$method $url');
    if (request != null) {
      debugPrint('── Request ──');
      debugPrint(encoder.convert(request));
    } else if (requestRaw != null && requestRaw.trim().isNotEmpty) {
      debugPrint('── Request ──');
      try {
        final decoded = json.decode(requestRaw);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(requestRaw);
      }
    }
    debugPrint('── Response HTTP $statusCode ──');
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (responseBody != null && responseBody.trim().isNotEmpty) {
      try {
        final decoded = json.decode(responseBody);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(responseBody);
      }
    } else {
      debugPrint('(empty body)');
    }
    debugPrint(_divider);
    debugPrint('');
  }

  static void message(String text) {
    if (!kDebugMode) return;
    debugPrint('[EXPRESS-PAY] $text');
  }
}
