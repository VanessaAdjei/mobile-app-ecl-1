import 'dart:convert';

import 'package:eclapp/models/guest_checkout_draft.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists guest delivery/payment details locally until checkout completes.
class GuestCheckoutDraftService {
  GuestCheckoutDraftService._();

  static const String _draftKey = 'guest_checkout_draft_v1';

  static Future<String?> _currentGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_id');
    if (guestId == null || guestId.isEmpty) return null;
    return guestId;
  }

  static Future<void> save(GuestCheckoutDraft draft) async {
    if (draft.guestId.isEmpty) return;
    if (!draft.hasContactInfo &&
        draft.deliveryOption == 'delivery' &&
        draft.address.trim().isEmpty &&
        draft.pickupSiteLabel.trim().isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
      await prefs.setBool('guest_info_collected', true);
    } catch (e, st) {
      debugPrint('GuestCheckoutDraftService.save failed: $e\n$st');
    }
  }

  static Future<GuestCheckoutDraft?> load() async {
    try {
      final guestId = await _currentGuestId();
      if (guestId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final draft = GuestCheckoutDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (draft.guestId != guestId) {
        await clear();
        return null;
      }
      if (!draft.hasContactInfo) return null;
      return draft;
    } catch (e, st) {
      debugPrint('GuestCheckoutDraftService.load failed: $e\n$st');
      return null;
    }
  }

  static Future<bool> hasDraft() async {
    final draft = await load();
    return draft != null;
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e, st) {
      debugPrint('GuestCheckoutDraftService.clear failed: $e\n$st');
    }
  }

  /// Clears the draft when the cart is cleared after a successful payment.
  static Future<void> clearAfterSuccessfulCheckout() async {
    await clear();
  }

  static Future<bool> isGuestSession() async {
    return !(await AuthService.isLoggedIn());
  }
}
