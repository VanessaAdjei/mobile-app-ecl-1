import 'package:flutter/foundation.dart';

/// Launch waterfall timestamps for catalog load debugging (no behavior change).
class CatalogTimer {
  CatalogTimer._();

  static final Map<String, int> _stamps = {};
  static bool _summaryEmitted = false;

  static void mark(String event) {
    _stamps[event] = DateTime.now().millisecondsSinceEpoch;
    debugPrint('⏱ CatalogTimer [$event]: ${_stamps[event]}ms epoch');
  }

  static void summary() {
    final start = _stamps['app_open'];
    if (start == null) return;
    debugPrint('⏱ CatalogTimer — launch waterfall (from app_open):');
    final ordered = _stamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in ordered) {
      debugPrint('⏱ +${entry.value - start}ms — ${entry.key}');
    }
  }

  /// Logs [summary] once per process (first time home has products via listener).
  static void summaryOnce() {
    if (_summaryEmitted) return;
    _summaryEmitted = true;
    summary();
  }

  /// For tests / hot restart during development.
  @visibleForTesting
  static void reset() {
    _stamps.clear();
    _summaryEmitted = false;
  }
}
