import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reduces accidental product opens while scrolling or double-tapping.
class ProductTapGuard {
  ProductTapGuard._();

  static DateTime? _lastScrollAt;
  static DateTime? _lastOpenAt;
  static String? _lastOpenKey;

  /// Call when a product list/grid scrolls.
  static void markScrolling() {
    _lastScrollAt = DateTime.now();
  }

  /// Returns false when a tap should be ignored (just scrolled or duplicate).
  static bool canOpen(String key) {
    final now = DateTime.now();
    if (_lastScrollAt != null &&
        now.difference(_lastScrollAt!) <
            const Duration(milliseconds: 120)) {
      return false;
    }
    if (_lastOpenAt != null &&
        _lastOpenKey == key &&
        now.difference(_lastOpenAt!) <
            const Duration(milliseconds: 700)) {
      return false;
    }
    return true;
  }

  static void recordOpen(String key) {
    _lastOpenAt = DateTime.now();
    _lastOpenKey = key;
  }

  static String openKey({required String urlName, String? productId}) {
    final id = productId?.trim() ?? '';
    final slug = urlName.trim();
    if (id.isNotEmpty) return 'id:$id';
    if (slug.isNotEmpty) return 'url:$slug';
    return 'unknown';
  }

  static void hapticOnOpen() {
    HapticFeedback.lightImpact();
  }
}

/// Marks descendant scrolls so [ProductTapGuard] can ignore trailing taps.
class ProductTapScrollScope extends StatelessWidget {
  const ProductTapScrollScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only the main vertical feed should block taps — ignore nested
        // horizontal lists (e.g. popular products auto-scroll).
        if (notification is ScrollUpdateNotification &&
            notification.metrics.axis == Axis.vertical) {
          final delta = notification.scrollDelta;
          if (delta != null && delta.abs() > 2) {
            ProductTapGuard.markScrolling();
          }
        }
        return false;
      },
      child: child,
    );
  }
}
