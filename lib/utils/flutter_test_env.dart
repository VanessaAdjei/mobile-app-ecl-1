import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// True under `flutter test`. The test VM blocks real HTTP (empty 400 responses).
bool get isFlutterTest {
  if (kIsWeb) return false;
  try {
    return Platform.environment['FLUTTER_TEST'] == 'true';
  } catch (_) {
    return false;
  }
}
