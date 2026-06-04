import 'dart:convert';

import 'package:eclapp/models/product_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Memory + disk cache for successful product **detail API** responses.
///
/// Data always originated from the detail endpoint (never list/catalog preview).
class ProductDetailCache {
  ProductDetailCache._();

  static const Duration memoryFreshDuration = Duration(minutes: 15);
  static const Duration diskMaxAge = Duration(hours: 24);
  static const String _diskPrefix = 'product_detail_v1_';
  static const String _diskTsPrefix = 'product_detail_ts_v1_';

  static final Map<String, _MemoryEntry> _memory = {};
  static bool isMemoryFresh(String urlName) {
    final entry = _memory[urlName];
    if (entry == null) return false;
    return DateTime.now().difference(entry.savedAt) < memoryFreshDuration;
  }

  /// Instant read from RAM only (for warm-up on tap).
  static Product? memoryPeek(String urlName) {
    if (urlName.isEmpty) return null;
    return _memory[urlName]?.product;
  }

  /// RAM first, then disk if younger than [diskMaxAge].
  static Future<Product?> read(String urlName) async {
    if (urlName.isEmpty) return null;

    final mem = _memory[urlName];
    if (mem != null) return mem.product;

    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_diskTsPrefix$urlName');
    if (ts == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(savedAt) > diskMaxAge) {
      await _removeDisk(prefs, urlName);
      return null;
    }

    final raw = prefs.getString('$_diskPrefix$urlName');
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final product = Product.fromJson(map);
      _memory[urlName] = _MemoryEntry(product, savedAt);
      return product;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductDetailCache: bad disk entry for $urlName: $e');
      }
      await _removeDisk(prefs, urlName);
      return null;
    }
  }

  static void putMemory(String urlName, Product product) {
    if (urlName.isEmpty) return;
    _memory[urlName] = _MemoryEntry(product, DateTime.now());
  }

  static Future<void> put(String urlName, Product product) async {
    if (urlName.isEmpty) return;
    final now = DateTime.now();
    _memory[urlName] = _MemoryEntry(product, now);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_diskPrefix$urlName', json.encode(product.toJson()));
      await prefs.setInt('$_diskTsPrefix$urlName', now.millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductDetailCache: disk write failed for $urlName: $e');
      }
    }
  }

  static Future<void> invalidate(String urlName) async {
    if (urlName.isEmpty) return;
    _memory.remove(urlName);
    try {
      final prefs = await SharedPreferences.getInstance();
      await _removeDisk(prefs, urlName);
    } catch (_) {}
  }

  static Future<void> _removeDisk(SharedPreferences prefs, String urlName) async {
    await prefs.remove('$_diskPrefix$urlName');
    await prefs.remove('$_diskTsPrefix$urlName');
  }
}

class _MemoryEntry {
  _MemoryEntry(this.product, this.savedAt);

  final Product product;
  final DateTime savedAt;
}
