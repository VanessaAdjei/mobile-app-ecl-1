import 'package:flutter/foundation.dart';

/// Set to `true` locally when debugging delivery fee / ExpressPay issues.
const bool kCheckoutVerboseLogs = false;

void checkoutLog(String message) {
  if (kDebugMode && kCheckoutVerboseLogs) {
    debugPrint(message);
  }
}
