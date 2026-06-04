// services/background_order_checker.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'order_notification_service.dart';
import '../providers/order_tracking_provider.dart';
import '../utils/order_status_notification_copy.dart';

/// Polls GET /orders and fires local notifications when cached status changes.
///
/// Works while the app process is alive (timer + resume). Not a substitute for
/// push notifications when the app is force-quit.
class BackgroundOrderChecker {
  static Timer? _timer;
  static bool _checkInProgress = false;
  static const Duration _checkInterval = Duration(minutes: 2);

  /// Stable id for [user_orders] cache and change detection.
  static String _orderKey(Map<String, dynamic> order) {
    return order['delivery_id']?.toString() ??
        order['transaction_id']?.toString() ??
        order['id']?.toString() ??
        order['order_number']?.toString() ??
        '';
  }

  static String _orderStatus(Map<String, dynamic> order) {
    return (order['status'] ?? order['order_status'] ?? '').toString().trim();
  }

  /// Start periodic checking for order updates
  static void startPeriodicChecking() {
    debugPrint('🔄 Starting background order checking...');
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) {
      unawaited(_checkForOrderUpdates());
    });
    unawaited(_checkForOrderUpdates());
  }

  /// Stop periodic checking
  static void stopPeriodicChecking() {
    debugPrint('🔄 Stopping background order checking...');
    _timer?.cancel();
    _timer = null;
  }

  /// Run one poll immediately (foreground resume, purchases screen, manual).
  static Future<void> checkNow({bool manual = false}) async {
    if (manual) debugPrint('🔄 Manual order check triggered');
    await _checkForOrderUpdates();
  }

  static bool get isRunning => _timer != null && _timer!.isActive;

  static Future<void> _checkForOrderUpdates() async {
    if (_checkInProgress) {
      debugPrint('🔄 Order check already in progress, skipping');
      return;
    }
    _checkInProgress = true;
    try {
      debugPrint('🔄 Checking for order updates...');

      final prefs = await SharedPreferences.getInstance();
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('🔄 No auth token found, skipping order check');
        return;
      }

      final responseData = await AuthService.getOrders();
      if (responseData['status'] != 'success' || responseData['data'] == null) {
        debugPrint('🔄 No orders found or invalid response format');
        return;
      }

      final ordersData = responseData['data'] as List<dynamic>;
      final rawOrders = ordersData
          .map((order) => Map<String, dynamic>.from(order as Map))
          .toList();

      final groupedOrders = _groupOrdersByTransaction(rawOrders);
      await _trackOrderStatusChangesAndNotify(prefs, groupedOrders);
      await prefs.setString('user_orders', json.encode(groupedOrders));

      debugPrint(
        '🔄 Order check completed - ${groupedOrders.length} orders '
        '(from ${rawOrders.length} raw items)',
      );
    } catch (e, st) {
      debugPrint('🔄 Error checking for order updates: $e\n$st');
    } finally {
      _checkInProgress = false;
    }
  }

  /// Group raw API orders by delivery_id/transaction_id (one entry per transaction)
  static List<Map<String, dynamic>> _groupOrdersByTransaction(
    List<Map<String, dynamic>> rawOrders,
  ) {
    final Map<String, List<Map<String, dynamic>>> byKey = {};
    for (final o in rawOrders) {
      final key = _orderKey(o);
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
        'status': _orderStatus(first),
        'items': items
            .expand((o) => (o['items'] as List<dynamic>?) ?? [])
            .toList(),
        'total_amount':
            first['total_amount'] ?? first['total'] ?? first['total_price'],
      };
    }).toList();
  }

  /// Compare new orders with cached ones and send notifications for status changes.
  static Future<void> _trackOrderStatusChangesAndNotify(
    SharedPreferences prefs,
    List<Map<String, dynamic>> newOrders,
  ) async {
    try {
      final cachedJson = prefs.getString('user_orders');
      final cachedOrders = <String, Map<String, dynamic>>{};
      if (cachedJson != null) {
        final list = json.decode(cachedJson) as List<dynamic>?;
        if (list != null) {
          for (final o in list) {
            if (o is! Map) continue;
            final order = Map<String, dynamic>.from(o);
            final key = _orderKey(order);
            if (key.isNotEmpty) cachedOrders[key] = order;
          }
        }
      }

      for (final order in newOrders) {
        final orderId = _orderKey(order);
        final newStatus = _orderStatus(order);
        if (orderId.isEmpty || newStatus.isEmpty) continue;

        final orderNumber =
            order['order_number']?.toString() ?? order['delivery_id']?.toString() ?? orderId;

        final oldOrder = cachedOrders[orderId];
        if (oldOrder == null) {
          // First time in checker cache — baseline only (placed alert handled at checkout).
          continue;
        }

        final oldStatus = _orderStatus(oldOrder);
        if (oldStatus.isNotEmpty &&
            oldStatus.toLowerCase() == newStatus.toLowerCase()) {
          continue;
        }

        debugPrint(
          '🔄 Status change: order $orderId "$oldStatus" -> "$newStatus"',
        );

        final (title, message) = orderStatusNotificationContent(
          orderNumber,
          newStatus,
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
        OrderTrackingProvider.notifyOrderStatusChanged();
      }
    } catch (e, st) {
      debugPrint('🔄 Error tracking order status changes: $e\n$st');
    }
  }

}
