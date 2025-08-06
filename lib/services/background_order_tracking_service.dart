// services/background_order_tracking_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_notification_service.dart';

class BackgroundOrderTrackingService {
  static Timer? _trackingTimer;
  static bool _isRunning = false;
  static const Duration _trackingInterval = Duration(minutes: 10);
  static const Duration _initialDelay = Duration(seconds: 60);

  // Cache for order data
  static Map<String, dynamic> _orderCache = {};
  static DateTime? _lastTrackingTime;
  static const Duration _cacheExpiration = Duration(minutes: 15);

  // Start background order tracking
  static void startBackgroundTracking() {
    if (_isRunning) return;

    debugPrint(
        '📦 BackgroundOrderTrackingService: Starting background order tracking');
    _isRunning = true;

    // Initial tracking after delay
    Timer(_initialDelay, () {
      _trackOrdersInBackground();
    });

    // Set up periodic tracking
    _trackingTimer = Timer.periodic(_trackingInterval, (timer) {
      _trackOrdersInBackground();
    });
  }

  // Stop background tracking
  static void stopBackgroundTracking() {
    debugPrint(
        '📦 BackgroundOrderTrackingService: Stopping background order tracking');
    _isRunning = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  // Track orders in background
  static Future<void> _trackOrdersInBackground() async {
    try {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Starting background order tracking');

      // Get user's orders
      final orders = await _getUserOrders();
      if (orders.isEmpty) {
        debugPrint('📦 BackgroundOrderTrackingService: No orders to track');
        return;
      }

      // Track each order
      for (final order in orders) {
        await _trackOrderStatus(order);
      }

      _lastTrackingTime = DateTime.now();
      debugPrint('📦 BackgroundOrderTrackingService: Order tracking completed');
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Background tracking error: $e');
    }
  }

  // Get user's orders from local storage
  static Future<List<Map<String, dynamic>>> _getUserOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('user_orders');

      if (ordersJson != null) {
        final orders = json.decode(ordersJson) as List;
        return orders.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error getting user orders: $e');
    }
    return [];
  }

  // Track individual order status
  static Future<void> _trackOrderStatus(Map<String, dynamic> order) async {
    try {
      final orderId = order['id'];
      final lastStatus = order['status'];

      // Get current status from server
      final currentStatus = await _getOrderStatusFromServer(orderId);
      if (currentStatus == null) return;

      // Check if status changed
      if (currentStatus != lastStatus) {
        debugPrint(
            '📦 BackgroundOrderTrackingService: Order $orderId status changed from $lastStatus to $currentStatus');

        // Update local cache
        order['status'] = currentStatus;
        order['last_updated'] = DateTime.now().millisecondsSinceEpoch;

        // Save updated orders
        await _saveUserOrders([order]);

        // Send notification for status change
        await _sendStatusChangeNotification(order, lastStatus, currentStatus);
      }
    } catch (e) {
      debugPrint('📦 BackgroundOrderTrackingService: Error tracking order: $e');
    }
  }

  // Get order status from server
  static Future<String?> _getOrderStatusFromServer(String orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/orders/$orderId/status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'];
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error getting order status: $e');
    }
    return null;
  }

  // Save user orders to local storage
  static Future<void> _saveUserOrders(List<Map<String, dynamic>> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_orders', json.encode(orders));
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error saving user orders: $e');
    }
  }

  // Send status change notification
  static Future<void> _sendStatusChangeNotification(
    Map<String, dynamic> order,
    String oldStatus,
    String newStatus,
  ) async {
    try {
      final orderId = order['id'];
      final orderNumber = order['order_number'] ?? orderId;

      String title = 'Order Update';
      String body = 'Your order #$orderNumber status has been updated';

      // Customize message based on status
      switch (newStatus.toLowerCase()) {
        case 'confirmed':
          body =
              'Your order #$orderNumber has been confirmed and is being processed';
          break;
        case 'processing':
          body = 'Your order #$orderNumber is now being processed';
          break;
        case 'shipped':
          body = 'Your order #$orderNumber has been shipped!';
          break;
        case 'delivered':
          body = 'Your order #$orderNumber has been delivered!';
          break;
        case 'cancelled':
          body = 'Your order #$orderNumber has been cancelled';
          break;
      }

      // Send local notification
      await NativeNotificationService.showNotification(
        title: title,
        body: body,
        payload: 'order_$orderId',
      );

      debugPrint(
          '📦 BackgroundOrderTrackingService: Status change notification sent for order $orderId');
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error sending notification: $e');
    }
  }

  // Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error getting auth token: $e');
      return null;
    }
  }

  // Check for delivery updates
  static Future<void> _checkDeliveryUpdates() async {
    try {
      final orders = await _getUserOrders();
      final shippedOrders = orders
          .where(
              (order) => order['status']?.toString().toLowerCase() == 'shipped')
          .toList();

      for (final order in shippedOrders) {
        await _checkDeliveryStatus(order);
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error checking delivery updates: $e');
    }
  }

  // Check delivery status for shipped orders
  static Future<void> _checkDeliveryStatus(Map<String, dynamic> order) async {
    try {
      final orderId = order['id'];
      final deliveryStatus = await _getDeliveryStatusFromServer(orderId);

      if (deliveryStatus != null) {
        order['delivery_status'] = deliveryStatus;
        await _saveUserOrders([order]);

        if (deliveryStatus['estimated_delivery'] != null) {
          await NativeNotificationService.showNotification(
            title: 'Delivery Update',
            body:
                'Your order will be delivered on ${deliveryStatus['estimated_delivery']}',
            payload: 'delivery_$orderId',
          );
        }
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error checking delivery status: $e');
    }
  }

  // Get delivery status from server
  static Future<Map<String, dynamic>?> _getDeliveryStatusFromServer(
      String orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/orders/$orderId/delivery'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['delivery_status'];
      }
    } catch (e) {
      debugPrint(
          '📦 BackgroundOrderTrackingService: Error getting delivery status: $e');
    }
    return null;
  }

  // Get tracking status
  static bool get isRunning => _isRunning;
  static DateTime? get lastTrackingTime => _lastTrackingTime;
  static bool get isCacheValid {
    if (_lastTrackingTime == null) return false;
    final timeSinceLastTracking = DateTime.now().difference(_lastTrackingTime!);
    return timeSinceLastTracking < _cacheExpiration;
  }
}
