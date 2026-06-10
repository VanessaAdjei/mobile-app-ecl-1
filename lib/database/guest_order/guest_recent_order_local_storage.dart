import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the latest guest order snapshot keyed by [guest_id].
abstract class GuestRecentOrderLocalStorage {
  Future<Map<String, dynamic>?> readForGuest(String guestId);
  Future<void> writeForGuest(String guestId, Map<String, dynamic> payload);
  Future<void> clearForGuest(String guestId);
}

class GuestRecentOrderLocalStorageImpl implements GuestRecentOrderLocalStorage {
  static String _storageKey(String guestId) =>
      'guest_recent_order_v1_$guestId';

  @override
  Future<Map<String, dynamic>?> readForGuest(String guestId) async {
    if (guestId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(guestId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeForGuest(String guestId, Map<String, dynamic> payload) async {
    if (guestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(guestId), json.encode(payload));
  }

  @override
  Future<void> clearForGuest(String guestId) async {
    if (guestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(guestId));
  }
}
