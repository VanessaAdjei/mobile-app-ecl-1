// services/background_inventory_monitor_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_notification_service.dart';

class BackgroundInventoryMonitorService {
  static Timer? _monitorTimer;
  static bool _isRunning = false;
  static const Duration _monitorInterval = Duration(minutes: 15);
  static const Duration _initialDelay = Duration(seconds: 45);

  static final Map<String, dynamic> _inventoryCache = {};
  static DateTime? _lastMonitorTime;
  static const Duration _cacheExpiration = Duration(minutes: 30);

  static final Map<String, bool> _previousStockStatus = {};
  static final Map<String, int> _previousStockLevels = {};

  static void startBackgroundMonitoring() {
    if (_isRunning) return;

    debugPrint(
        '📦 BackgroundInventoryMonitorService: Starting background inventory monitoring');
    _isRunning = true;

    // Initial monitoring after delay
    Timer(_initialDelay, () {
      _monitorInventoryInBackground();
    });

    // Set up periodic monitoring
    _monitorTimer = Timer.periodic(_monitorInterval, (timer) {
      _monitorInventoryInBackground();
    });
  }

  // Stop background monitoring
  static void stopBackgroundMonitoring() {
    debugPrint(
        '📦 BackgroundInventoryMonitorService: Stopping background inventory monitoring');
    _isRunning = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  static Future<void> _monitorInventoryInBackground() async {
    try {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Starting background inventory monitoring');

      final cartItems = await _getCartItems();
      if (cartItems.isEmpty) {
        debugPrint(
            '📦 BackgroundInventoryMonitorService: No cart items to monitor');
        return;
      }

      final outOfStockItems = <String>[];
      final lowStockItems = <String>[];

      for (final item in cartItems) {
        final productId = item['product_id'] ?? item['id'];
        final productName = item['name'] ?? 'Unknown Product';

        if (productId != null) {
          final stockInfo = await _getProductStockInfo(productId.toString());

          if (stockInfo != null) {
            final currentStock = stockInfo['qty_in_stock'] ?? 0;
            final previousStock =
                _previousStockLevels[productId.toString()] ?? currentStock;
            final wasInStock =
                _previousStockStatus[productId.toString()] ?? true;

            // Update tracking
            _previousStockLevels[productId.toString()] = currentStock;
            _previousStockStatus[productId.toString()] = currentStock > 0;

            // Check for stock changes
            if (currentStock == 0 && wasInStock) {
              outOfStockItems.add(productName);
              debugPrint(
                  '📦 BackgroundInventoryMonitorService: $productName is now OUT OF STOCK');
            } else if (currentStock > 0 &&
                currentStock <= 5 &&
                previousStock > 5) {
              lowStockItems.add('$productName ($currentStock left)');
              debugPrint(
                  '📦 BackgroundInventoryMonitorService: $productName is LOW STOCK ($currentStock left)');
            }
          }
        }
      }

      // Send notifications for stock changes
      if (outOfStockItems.isNotEmpty) {
        await _sendOutOfStockNotification(outOfStockItems);
      }

      if (lowStockItems.isNotEmpty) {
        await _sendLowStockNotification(lowStockItems);
      }

      _lastMonitorTime = DateTime.now();
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Inventory monitoring completed');
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Background monitoring error: $e');
    }
  }

  // Get cart items from local storage
  static Future<List<Map<String, dynamic>>> _getCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');

      if (cartJson != null) {
        final cartItems = json.decode(cartJson) as List;
        return cartItems.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error getting cart items: $e');
    }
    return [];
  }

  // Get product stock information from API
  static Future<Map<String, dynamic>?> _getProductStockInfo(
      String productId) async {
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

          // Extract stock information
          return {
            'qty_stocked': productData['qty_stocked'] ?? 0,
            'qty_sold': productData['qty_sold'] ?? 0,
            'qty_in_stock': productData['qty_in_stock'] ?? 0,
            'product_name':
                productData['product']?['name'] ?? 'Unknown Product',
            'batch_no': productData['batch_no'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error getting stock info for product $productId: $e');
    }
    return null;
  }

  // Send out of stock notification
  static Future<void> _sendOutOfStockNotification(
      List<String> outOfStockItems) async {
    try {
      String title = 'Out of Stock Alert';
      String body = '';

      if (outOfStockItems.length == 1) {
        body = '${outOfStockItems[0]} is now out of stock.';
      } else if (outOfStockItems.length <= 3) {
        body = '${outOfStockItems.join(', ')} are now out of stock.';
      } else {
        body =
            '${outOfStockItems.length} items in your cart are now out of stock.';
      }

      await NativeNotificationService.showNotification(
        title: title,
        body: body,
        payload: 'out_of_stock_alert',
      );

      debugPrint(
          '📦 BackgroundInventoryMonitorService: Out of stock notification sent for ${outOfStockItems.length} items');
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error sending out of stock notification: $e');
    }
  }

  // Send low stock notification
  static Future<void> _sendLowStockNotification(
      List<String> lowStockItems) async {
    try {
      String title = 'Low Stock Alert';
      String body = '';

      if (lowStockItems.length == 1) {
        body = '${lowStockItems[0]} is running low on stock.';
      } else if (lowStockItems.length <= 3) {
        body = '${lowStockItems.join(', ')} are running low on stock.';
      } else {
        body =
            '${lowStockItems.length} items in your cart are running low on stock.';
      }

      await NativeNotificationService.showNotification(
        title: title,
        body: body,
        payload: 'low_stock_alert',
      );

      debugPrint(
          '📦 BackgroundInventoryMonitorService: Low stock notification sent for ${lowStockItems.length} items');
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error sending low stock notification: $e');
    }
  }

  // Check if a specific product is in stock
  static Future<bool> isProductInStock(String productId) async {
    try {
      final stockInfo = await _getProductStockInfo(productId);
      if (stockInfo != null) {
        final qtyInStock = stockInfo['qty_in_stock'] ?? 0;
        return qtyInStock > 0;
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error checking stock for product $productId: $e');
    }
    return false; // Assume out of stock if check fails
  }

  // Get current stock level for a product
  static Future<int> getProductStockLevel(String productId) async {
    try {
      final stockInfo = await _getProductStockInfo(productId);
      if (stockInfo != null) {
        return stockInfo['qty_in_stock'] ?? 0;
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error getting stock level for product $productId: $e');
    }
    return 0;
  }

  // Check if cart has out of stock items
  static Future<List<String>> getOutOfStockCartItems() async {
    try {
      final cartItems = await _getCartItems();
      final outOfStockItems = <String>[];

      for (final item in cartItems) {
        final productId = item['product_id'] ?? item['id'];
        final productName = item['name'] ?? 'Unknown Product';

        if (productId != null) {
          final isInStock = await isProductInStock(productId.toString());
          if (!isInStock) {
            outOfStockItems.add(productName);
          }
        }
      }

      return outOfStockItems;
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error checking cart for out of stock items: $e');
      return [];
    }
  }

  // Preload stock information for popular products
  static Future<void> _preloadPopularProductStock() async {
    try {
      // This could be expanded to preload stock for frequently viewed products
      final popularProductIds = await _getPopularProductIds();

      for (final productId in popularProductIds) {
        final stockInfo = await _getProductStockInfo(productId);
        if (stockInfo != null) {
          _inventoryCache[productId] = stockInfo;
        }
      }

      debugPrint(
          '📦 BackgroundInventoryMonitorService: Preloaded stock info for ${popularProductIds.length} popular products');
    } catch (e) {
      debugPrint(
          '📦 BackgroundInventoryMonitorService: Error preloading popular product stock: $e');
    }
  }

  // Get popular product IDs (this could be based on user behavior or predefined list)
  static Future<List<String>> _getPopularProductIds() async {
    // For now, return an empty list. This could be expanded based on:
    // - User's browsing history
    // - Most viewed products
    // - Frequently purchased items
    return [];
  }

  // Get service status
  static bool get isRunning => _isRunning;
  static DateTime? get lastMonitorTime => _lastMonitorTime;
  static bool get isCacheValid {
    if (_lastMonitorTime == null) return false;
    final timeSinceLastMonitor = DateTime.now().difference(_lastMonitorTime!);
    return timeSinceLastMonitor < _cacheExpiration;
  }

  // Get cached inventory data
  static Map<String, dynamic> get cachedInventoryData => _inventoryCache;
}
