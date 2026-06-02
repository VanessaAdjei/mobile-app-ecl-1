// services/background_cart_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_service.dart';

class BackgroundCartSyncService {
  static Timer? _syncTimer;
  static bool _isRunning = false;
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _initialDelay = Duration(seconds: 30);

  static final CartService _cartService = CartService();

  static Map<String, dynamic>? _lastCartData;
  static DateTime? _lastSyncTime;
  static const Duration _cacheExpiration = Duration(minutes: 10);

  static void startBackgroundSync() {
    if (_isRunning) return;

    debugPrint('🛒 BackgroundCartSyncService: Starting background cart sync');
    _isRunning = true;

    Timer(_initialDelay, () {
      _syncCartInBackground();
    });

    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _syncCartInBackground();
    });
  }

  static void stopBackgroundSync() {
    debugPrint('🛒 BackgroundCartSyncService: Stopping background cart sync');
    _isRunning = false;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _syncCartInBackground() async {
    try {
      debugPrint('🛒 BackgroundCartSyncService: Starting background cart sync');

      final cartData = await _getCurrentCartData();
      if (cartData == null) {
        debugPrint('🛒 BackgroundCartSyncService: No cart data to sync');
        return;
      }

      if (_hasCartDataChanged(cartData)) {
        debugPrint(
            '🛒 BackgroundCartSyncService: Cart data changed, syncing...');

        final success = await _cartService.syncCartPayload(cartData: cartData);
        if (success) {
          _lastCartData = cartData;
          _lastSyncTime = DateTime.now();
          debugPrint('🛒 BackgroundCartSyncService: Cart sync successful');
        }
      } else {
        debugPrint('🛒 BackgroundCartSyncService: No changes to sync');
      }
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Background sync error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getCurrentCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');

      if (cartJson != null) {
        final cartItems = json.decode(cartJson) as List;
        return {
          'items': cartItems,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Error getting cart data: $e');
    }
    return null;
  }

  static bool _hasCartDataChanged(Map<String, dynamic> newData) {
    if (_lastCartData == null) return true;

    try {
      final oldItems = _lastCartData!['items'] as List? ?? [];
      final newItems = newData['items'] as List? ?? [];

      if (oldItems.length != newItems.length) return true;

      for (int i = 0; i < oldItems.length; i++) {
        final oldItem = oldItems[i] as Map<String, dynamic>;
        final newItem = newItems[i] as Map<String, dynamic>;

        if (oldItem['productId'] != newItem['productId'] ||
            oldItem['quantity'] != newItem['quantity']) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Error comparing cart data: $e');
      return true;
    }
  }

  static bool get isRunning => _isRunning;
  static DateTime? get lastSyncTime => _lastSyncTime;
  static bool get isCacheValid {
    if (_lastSyncTime == null) return false;
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync < _cacheExpiration;
  }
}
