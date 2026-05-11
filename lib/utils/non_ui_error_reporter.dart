import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Reports errors that must not disrupt the UI (e.g. background polling).
///
/// - Always logs via [developer.log] (visible in DevTools / device logs).
/// - In debug, also [debugPrint]s for quick console reading.
/// - Optional [register] callback for Crashlytics, Sentry, etc.
///
/// Call [register] once from `main()` after `WidgetsFlutterBinding.ensureInitialized()`,
/// for example when Firebase Crashlytics is available:
///
/// ```dart
/// NonUiErrorReporter.register((context, error, stackTrace) {
///   FirebaseCrashlytics.instance.recordError(
///     error,
///     stackTrace,
///     reason: context,
///     fatal: false,
///   );
/// });
/// ```
typedef NonUiErrorCallback = void Function(
  String context,
  Object error,
  StackTrace? stackTrace,
);

class NonUiErrorReporter {
  NonUiErrorReporter._();

  static NonUiErrorCallback? _remote;

  /// Call once from [main] to forward non-UI errors to Crashlytics / Sentry.
  static void register(NonUiErrorCallback? callback) {
    _remote = callback;
  }

  static void report(
    String context,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    developer.log(
      error.toString(),
      name: context,
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode) {
      debugPrint('[$context] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    try {
      _remote?.call(context, error, stackTrace);
    } catch (_) {
      // Never let reporting break the app.
    }
  }
}
