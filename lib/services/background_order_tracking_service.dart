// services/background_order_tracking_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'native_notification_service.dart';
import 'order_notification_service.dart';
import '../utils/app_error_utils.dart';

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
      // Get user's orders
      final orders = await _getUserOrders();
      if (orders.isEmpty) {
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

    }
    return [];
  }

  // Track individual order status
  static Future<void> _trackOrderStatus(Map<String, dynamic> order) async {
    try {
      final orderId = order['delivery_id']?.toString() ??
          order['transaction_id']?.toString() ??
          order['id']?.toString() ??
          '';
      final lastStatus = order['status']?.toString();
      if (orderId.isEmpty) return;

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
        await _sendStatusChangeNotification(order, lastStatus ?? 'unknown', currentStatus);
      }
    } catch (e) {

    }
  }

  // Status from GET /orders (per-order /status route is not on production API).
  static Future<String?> _getOrderStatusFromServer(String orderId) async {
    try {
      final result = await AuthService.getOrders();
      if (result['status'] != 'success' || result['data'] is! List) {
        return null;
      }

      for (final item in result['data'] as List) {
        if (item is! Map) continue;
        final order = Map<String, dynamic>.from(item);
        final candidateIds = <String>{
          order['delivery_id']?.toString() ?? '',
          order['transaction_id']?.toString() ?? '',
          order['id']?.toString() ?? '',
          order['order_number']?.toString() ?? '',
        }..removeWhere((v) => v.isEmpty);

        if (candidateIds.contains(orderId)) {
          final status = order['status']?.toString();
          if (status != null && status.isNotEmpty) return status;
        }
      }
    } catch (e) {
      AppErrorUtils.log('BackgroundOrderTracking._getOrderStatusFromServer', e);
    }
    return null;
  }

  // Save user orders to local storage (merge updated order with existing)
  static Future<void> _saveUserOrders(List<Map<String, dynamic>> updatedOrders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getUserOrders();
      final byId = <String, Map<String, dynamic>>{};
      for (final o in existing) {
        final id = o['id']?.toString() ?? o['transaction_id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = Map<String, dynamic>.from(o);
      }
      for (final o in updatedOrders) {
        final id = o['id']?.toString() ?? o['transaction_id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = Map<String, dynamic>.from(o);
      }
      await prefs.setString('user_orders', json.encode(byId.values.toList()));
    } catch (e, st) {
      AppErrorUtils.log('BackgroundOrderTracking._mergeOrders', e, st);
    }
  }

  // Send status change notification for every tracking stage
  static Future<void> _sendStatusChangeNotification(
    Map<String, dynamic> order,
    String oldStatus,
    String newStatus,
  ) async {
    try {
      final orderId = order['id']?.toString() ?? '';
      final orderNumber = order['order_number']?.toString() ?? orderId;
      final totalAmount = order['total_amount']?.toString() ?? order['total']?.toString();
      final items = order['items'] as List<dynamic>?;

      String title = 'Order Update';
      String message = 'Your order #$orderNumber status has been updated';

      final s = newStatus.toLowerCase();
      if (s.contains('order placed') || s == 'pending' || s == 'placed') {
        title = 'Order Placed';
        message = 'Your order #$orderNumber has been placed and is being processed.';
      } else if (s.contains('paid') || s.contains('payment')) {
        title = 'Payment Received';
        message = 'Payment for order #$orderNumber has been received. Your order is being confirmed.';
      } else if (s.contains('confirm') || s.contains('processing')) {
        title = 'Order Confirmed';
        message = 'Your order #$orderNumber has been confirmed and is being prepared.';
      } else if (s.contains('out for delivery') || s.contains('out for')) {
        title = 'Out for Delivery';
        message = 'Your order #$orderNumber is out for delivery. It will arrive soon!';
      } else if (s.contains('ready for dispatch') ||
          s.contains('ready_for_dispatch') ||
          s.contains('ready to dispatch')) {
        title = 'Ready for Dispatch';
        message =
            'Your order #$orderNumber is packed and ready for dispatch.';
      } else if (s.contains('dispatched') ||
          (s.contains('dispatch') && !s.contains('confirmation'))) {
        title = 'Ready for Dispatch';
        message =
            'Your order #$orderNumber is packed and ready for dispatch.';
      } else if (s.contains('ship') && !s.contains('out for')) {
        title = 'Out for Delivery';
        message =
            'Your order #$orderNumber has been shipped and is on its way!';
      } else if (s == 'arrived' || s.contains('arrived')) {
        title = 'Order Arrived';
        message =
            'Your order #$orderNumber has arrived at your delivery location.';
      } else if (s.contains('delivered') || s == 'completed') {
        title = 'Order Delivered';
        message = 'Your order #$orderNumber has been delivered. Thank you for shopping with us!';
      } else if (s.contains('cancel')) {
        title = 'Order Cancelled';
        message = 'Your order #$orderNumber has been cancelled.';
      }

      await OrderNotificationService.createOrderStatusNotification(
        orderId: orderId,
        orderNumber: orderNumber,
        status: newStatus,
        title: title,
        message: message,
        totalAmount: totalAmount,
        items: items,
      );
    } catch (e) {
      debugPrint('📦 Error sending status notification: $e');
    }
  }

  // Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (e) {
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
    } catch (e, st) {
      AppErrorUtils.log('BackgroundOrderTracking._checkDeliveryUpdates', e, st);
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
    } catch (e, st) {
      AppErrorUtils.log('BackgroundOrderTracking._checkDeliveryStatus', e, st);
    }
  }

  // Get delivery status from server
  static Future<Map<String, dynamic>?> _getDeliveryStatusFromServer(
      String orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(ApiConfig.getOrderDeliveryUrl(orderId)),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['delivery_status'];
      }
    } catch (e, st) {
      AppErrorUtils.log(
        'BackgroundOrderTracking._getDeliveryStatusFromServer',
        e,
        st,
      );
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
