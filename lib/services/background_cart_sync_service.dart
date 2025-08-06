// services/background_cart_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/cartprovider.dart';

class BackgroundCartSyncService {
  static Timer? _syncTimer;
  static bool _isRunning = false;
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _initialDelay = Duration(seconds: 30);

  // Cache for cart data
  static Map<String, dynamic>? _lastCartData;
  static DateTime? _lastSyncTime;
  static const Duration _cacheExpiration = Duration(minutes: 10);

  // Start background cart synchronization
  static void startBackgroundSync() {
    if (_isRunning) return;

    debugPrint('🛒 BackgroundCartSyncService: Starting background cart sync');
    _isRunning = true;

    // Initial sync after delay
    Timer(_initialDelay, () {
      _syncCartInBackground();
    });

    // Set up periodic sync
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _syncCartInBackground();
    });
  }

  // Stop background synchronization
  static void stopBackgroundSync() {
    debugPrint('🛒 BackgroundCartSyncService: Stopping background cart sync');
    _isRunning = false;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Sync cart data in background
  static Future<void> _syncCartInBackground() async {
    try {
      debugPrint('🛒 BackgroundCartSyncService: Starting background cart sync');

      // Get current cart data
      final cartData = await _getCurrentCartData();
      if (cartData == null) {
        debugPrint('🛒 BackgroundCartSyncService: No cart data to sync');
        return;
      }

      // Check if data has changed
      if (_hasCartDataChanged(cartData)) {
        debugPrint(
            '🛒 BackgroundCartSyncService: Cart data changed, syncing...');

        // Sync with server
        final success = await _syncWithServer(cartData);
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

  // Get current cart data from local storage
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

  // Check if cart data has changed
  static bool _hasCartDataChanged(Map<String, dynamic> newData) {
    if (_lastCartData == null) return true;

    try {
      final oldItems = _lastCartData!['items'] as List;
      final newItems = newData['items'] as List;

      if (oldItems.length != newItems.length) return true;

      // Compare items
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

  // Sync cart data with server
  static Future<bool> _syncWithServer(Map<String, dynamic> cartData) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('🛒 BackgroundCartSyncService: No auth token for sync');
        return false;
      }

      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/sync-cart'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(cartData),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      }
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Server sync error: $e');
    }
    return false;
  }

  // Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Error getting auth token: $e');
      return null;
    }
  }

  // Check inventory for cart items
  static Future<void> _checkInventory() async {
    try {
      final cartData = await _getCurrentCartData();
      if (cartData == null) return;

      final items = cartData['items'] as List;
      final outOfStockItems = <String>[];

      for (final item in items) {
        final productId = item['productId'];
        final isAvailable = await _checkProductAvailability(productId);

        if (!isAvailable) {
          outOfStockItems.add(item['name'] ?? 'Unknown Product');
        }
      }

      if (outOfStockItems.isNotEmpty) {
        debugPrint(
            '🛒 BackgroundCartSyncService: Out of stock items detected: $outOfStockItems');
        // Could trigger notification here
      }
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Inventory check error: $e');
    }
  }

  static Future<bool> _checkProductAvailability(String productId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/products/$productId'),
          )
          .timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('data') && data['data'] != null) {
          final productData = data['data'];
          final qtyInStock = productData['qty_in_stock'] ?? 0;
          return qtyInStock > 0;
        }
      }
    } catch (e) {
      debugPrint('🛒 BackgroundCartSyncService: Availability check error: $e');
    }
    return true; // Assume available if check fails
  }

  // Get sync status
  static bool get isRunning => _isRunning;
  static DateTime? get lastSyncTime => _lastSyncTime;
  static bool get isCacheValid {
    if (_lastSyncTime == null) return false;
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync < _cacheExpiration;
  }
}
