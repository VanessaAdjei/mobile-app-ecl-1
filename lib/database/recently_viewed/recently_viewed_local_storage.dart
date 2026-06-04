import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists recently viewed product JSON blobs (from detail API / [Product.toJson]).
abstract class RecentlyViewedLocalStorage {
  Future<List<Map<String, dynamic>>> readAll();
  Future<void> writeAll(List<Map<String, dynamic>> entries);
}

class RecentlyViewedLocalStorageImpl implements RecentlyViewedLocalStorage {
  static const String _storageKey = 'recently_viewed_products_v1';

  @override
  Future<List<Map<String, dynamic>>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> writeAll(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(entries));
  }
}
