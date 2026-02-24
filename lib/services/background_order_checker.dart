// services/background_order_checker.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'order_notification_service.dart';

class BackgroundOrderChecker {
  static Timer? _timer;
  static const Duration _checkInterval =
      Duration(minutes: 5); // Check every 5 minutes
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';

  /// Start periodic checking for order updates
  static void startPeriodicChecking() {
    debugPrint('🔄 Starting background order checking...');

    // Stop any existing timer
    _timer?.cancel();

    // Start new timer
    _timer = Timer.periodic(_checkInterval, (timer) {
      _checkForOrderUpdates();
    });

    // Also check immediately on startup
    _checkForOrderUpdates();
  }

  /// Stop periodic checking
  static void stopPeriodicChecking() {
    debugPrint('🔄 Stopping background order checking...');
    _timer?.cancel();
    _timer = null;
  }

  /// Check for order updates
  static Future<void> _checkForOrderUpdates() async {
    try {
      debugPrint('🔄 Checking for order updates...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        debugPrint('🔄 No auth token found, skipping order check');
        return;
      }

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(
            Uri.parse('$_baseUrl/orders'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> ordersData = responseData['data'];
          final List<Map<String, dynamic>> rawOrders = ordersData
              .map((order) => Map<String, dynamic>.from(order))
              .toList();

          // Group by delivery_id/transaction_id (API returns items per order)
          final List<Map<String, dynamic>> groupedOrders =
              _groupOrdersByTransaction(rawOrders);

          await _trackOrderStatusChangesAndNotify(prefs, groupedOrders);
          await prefs.setString('user_orders', json.encode(groupedOrders));

          debugPrint(
              '🔄 Order check completed - ${groupedOrders.length} orders (from ${rawOrders.length} raw items)');
        } else {
          debugPrint('🔄 No orders found or invalid response format');
        }
      } else {
        debugPrint('🔄 Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔄 Error checking for order updates: $e');
    }
  }

  /// Group raw API orders by delivery_id/transaction_id (one entry per transaction)
  static List<Map<String, dynamic>> _groupOrdersByTransaction(
    List<Map<String, dynamic>> rawOrders,
  ) {
    final Map<String, List<Map<String, dynamic>>> byKey = {};
    for (final o in rawOrders) {
      final key = o['delivery_id']?.toString() ??
          o['transaction_id']?.toString() ??
          o['order_id']?.toString() ??
          o['id']?.toString() ??
          '';
      if (key.isEmpty) continue;
      byKey.putIfAbsent(key, () => []).add(o);
    }
    return byKey.entries.map((e) {
      final items = e.value;
      final first = items.first;
      return {
        ...first,
        'id': e.key,
        'delivery_id': e.key,
        'transaction_id': e.key,
        'order_number': first['order_number'] ?? first['delivery_id'] ?? e.key,
        'status': first['status'] ?? first['order_status'] ?? '',
        'items': items.expand((o) => (o['items'] as List<dynamic>?) ?? []).toList(),
        'total_amount': first['total_amount'] ?? first['total'] ?? first['total_price'],
      };
    }).toList();
  }

  /// Compare new orders with cached ones and send notifications for every status change
  static Future<void> _trackOrderStatusChangesAndNotify(
    SharedPreferences prefs,
    List<Map<String, dynamic>> newOrders,
  ) async {
    try {
      final cachedJson = prefs.getString('user_orders');
      final Map<String, Map<String, dynamic>> cachedOrders = {};
      if (cachedJson != null) {
        final list = json.decode(cachedJson) as List<dynamic>?;
        if (list != null) {
          for (final o in list) {
            final order = Map<String, dynamic>.from(o);
            final key = order['delivery_id']?.toString() ??
                order['transaction_id']?.toString() ??
                order['id']?.toString() ??
                order['order_number']?.toString();
            if (key != null && key.isNotEmpty) cachedOrders[key] = order;
          }
        }
      }

      for (final order in newOrders) {
        final orderId = order['delivery_id']?.toString() ??
            order['transaction_id']?.toString() ??
            order['id']?.toString() ??
            '';
        final orderNumber =
            order['order_number']?.toString() ?? order['delivery_id']?.toString() ?? orderId;
        final newStatus =
            (order['status'] ?? order['order_status'] ?? '').toString().trim();
        if (orderId.isEmpty || newStatus.isEmpty) continue;

        final oldOrder = cachedOrders[orderId];
        final oldStatus = oldOrder != null
            ? (oldOrder['status'] ?? oldOrder['order_status'] ?? '')
                .toString()
                .trim()
            : null;

        if (oldStatus == null || oldStatus.isEmpty) continue;
        if (oldStatus.toLowerCase() == newStatus.toLowerCase()) continue;

        debugPrint(
            '🔄 Status change: order $orderId $oldStatus -> $newStatus');

        final (title, message) = _getStatusNotificationContent(
          orderNumber,
          newStatus,
          order,
        );
        await OrderNotificationService.createOrderStatusNotification(
          orderId: orderId,
          orderNumber: orderNumber,
          status: newStatus,
          title: title,
          message: message,
          totalAmount:
              order['total_amount']?.toString() ?? order['total']?.toString(),
          items: order['items'] as List<dynamic>?,
        );
      }
    } catch (e) {
      debugPrint('🔄 Error tracking order status changes: $e');
    }
  }

  static (String title, String message) _getStatusNotificationContent(
    String orderNumber,
    String status,
    Map<String, dynamic> order,
  ) {
    final s = status.toLowerCase();
    if (s.contains('order placed') || s.contains('pending') || s == 'placed') {
      return (
        'Order Placed',
        'Your order #$orderNumber has been placed and is being processed.',
      );
    }
    if (s.contains('paid') || s.contains('payment')) {
      return (
        'Payment Received',
        'Payment for order #$orderNumber has been received. Your order is being confirmed.',
      );
    }
    if (s.contains('confirm') || s.contains('processing')) {
      return (
        'Order Confirmed',
        'Your order #$orderNumber has been confirmed and is being prepared.',
      );
    }
    if (s.contains('ship') && !s.contains('out for')) {
      return (
        'Order Shipped',
        'Your order #$orderNumber has been shipped and is on its way!',
      );
    }
    if (s.contains('out for delivery') || s.contains('out for')) {
      return (
        'Out for Delivery',
        'Your order #$orderNumber is out for delivery. It will arrive soon!',
      );
    }
    if (s.contains('delivered')) {
      return (
        'Order Delivered',
        'Your order #$orderNumber has been delivered. Thank you for shopping with us!',
      );
    }
    if (s.contains('cancel')) {
      return (
        'Order Cancelled',
        'Your order #$orderNumber has been cancelled.',
      );
    }
    return (
      'Order Update',
      'Your order #$orderNumber status: $status',
    );
  }

  /// Manually trigger an order check
  static Future<void> checkNow() async {
    debugPrint('🔄 Manual order check triggered');
    await _checkForOrderUpdates();
  }

  /// Check if the service is running
  static bool get isRunning => _timer != null && _timer!.isActive;
}
