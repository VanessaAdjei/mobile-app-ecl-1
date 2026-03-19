// services/notification_handler_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/notifications.dart';
import 'package:eclapp/providers/order_tracking_provider.dart';
import 'native_notification_service.dart';
import 'order_notification_service.dart';

class NotificationHandlerService {
  static void handleNotificationPayload(BuildContext context, String? payload) {
    if (payload == null || payload.isEmpty) {
      debugPrint('📱 Handler: No payload to handle');
      return;
    }

    try {
      debugPrint('📱 Handler: Processing payload: $payload');
      final Map<String, dynamic> data = json.decode(payload);

      final String type = data['type']?.toString() ?? '';
      debugPrint('📱 Handler: Notification type: $type');

      switch (type) {
        case 'order_placed':
          _handleOrderPlacedNotification(context, data);
          break;
        case 'order_status':
          _handleOrderStatusNotification(context, data);
          break;
        case 'delivery':
          _handleDeliveryNotification(context, data);
          break;
        case 'test':
          _handleTestNotification(context, data);
          break;
        default:
          debugPrint('📱 Handler: Unknown notification type: $type');

          _navigateToNotificationsImmediately(context);
          break;
      }
    } catch (e) {
      debugPrint('📱 Handler: Error processing payload: $e');
      _navigateToNotificationsImmediately(context);
    }
  }

  static void _handleOrderPlacedNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order placed notification');

    _navigateToNotificationsImmediately(context);
  }

  /// Handle order status notification
  static void _handleOrderStatusNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order status notification');
    // Refresh tracking screen immediately so status updates without user action
    OrderTrackingProvider.notifyOrderStatusChanged();
    _navigateToNotificationsImmediately(context);
  }

  /// Handle delivery notification
  static void _handleDeliveryNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling delivery notification');
    final orderId = data['order_id']?.toString() ?? data['delivery_id']?.toString() ?? '';
    final orderNumber = data['order_number']?.toString() ?? orderId;
    OrderNotificationService.createOrderStatusNotification(
      orderId: orderId.isNotEmpty ? orderId : DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: orderNumber.isNotEmpty ? orderNumber : 'Order',
      status: data['status']?.toString() ?? 'delivered',
      title: 'Order Delivered',
      message: orderNumber.isNotEmpty
          ? 'Your order #$orderNumber has been delivered. Thank you for shopping with us!'
          : 'Your order has been delivered. Thank you for shopping with us!',
      totalAmount: data['total_amount']?.toString(),
      items: (data['items'] as List<dynamic>?) ?? const [],
    );
    OrderTrackingProvider.notifyOrderStatusChanged();
    _navigateToNotificationsImmediately(context);
  }

  static void _handleTestNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling test notification');
    _navigateToNotifications(context);
  }

  static void _navigateToNotifications(BuildContext context) {
    debugPrint('📱 Handler: Navigating to notifications page');

    final navigatorKey = NativeNotificationService.globalNavigatorKey;
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        ),
      );
    } else {
      debugPrint(
          '📱 Handler: Navigator not available for notifications navigation');
    }
  }

  static void _navigateToNotificationsImmediately(BuildContext context) {
    debugPrint('📱 Handler: Navigating to notifications page immediately');

    final navigatorKey = NativeNotificationService.globalNavigatorKey;
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        ),
      );
    } else {
      debugPrint(
          '📱 Handler: Navigator not available for notifications navigation');
    }
  }

  static String? getNotificationPayload() {
    return null;
  }
}
