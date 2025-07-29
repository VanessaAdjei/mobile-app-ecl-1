// services/notification_handler_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/notifications.dart';
import 'package:eclapp/pages/order_tracking_page.dart';

class NotificationHandlerService {
  static const String _notificationPayloadKey = 'notification_payload';

  /// Handle notification payload when app is opened from notification
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

      // Handle immediately without delay for faster response
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
          _navigateToNotifications(context);
          break;
      }
    } catch (e) {
      debugPrint('📱 Handler: Error processing payload: $e');
      _navigateToNotifications(context);
    }
  }

  /// Handle order placed notification
  static void _handleOrderPlacedNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order placed notification');

    final String orderId = data['order_id']?.toString() ?? '';
    final String orderNumber = data['order_number']?.toString() ?? '';

    if (orderId.isNotEmpty && orderNumber.isNotEmpty) {
      // Create order details map for OrderTrackingPage
      final Map<String, dynamic> orderDetails = {
        'id': orderId,
        'order_number': orderNumber,
        'status': data['status'] ?? 'Order Placed',
        'total_amount': data['total_amount'] ?? '0.00',
        'payment_method': data['payment_method'] ?? 'Unknown',
        'items': data['items'] ?? [],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      };

      // Navigate to order tracking page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderDetails: orderDetails,
          ),
        ),
      );
    } else {
      _navigateToNotifications(context);
    }
  }

  /// Handle order status notification
  static void _handleOrderStatusNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order status notification');

    final String orderId = data['order_id']?.toString() ?? '';
    final String orderNumber = data['order_number']?.toString() ?? '';

    if (orderId.isNotEmpty && orderNumber.isNotEmpty) {
      // Create order details map for OrderTrackingPage
      final Map<String, dynamic> orderDetails = {
        'id': orderId,
        'order_number': orderNumber,
        'status': data['status'] ?? 'Order Updated',
        'total_amount': data['total_amount'] ?? '0.00',
        'payment_method': data['payment_method'] ?? 'Unknown',
        'items': data['items'] ?? [],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      };

      // Navigate to order tracking page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderDetails: orderDetails,
          ),
        ),
      );
    } else {
      _navigateToNotifications(context);
    }
  }

  /// Handle delivery notification
  static void _handleDeliveryNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling delivery notification');

    final String orderId = data['order_id']?.toString() ?? '';
    final String orderNumber = data['order_number']?.toString() ?? '';

    if (orderId.isNotEmpty && orderNumber.isNotEmpty) {
      // Create order details map for OrderTrackingPage
      final Map<String, dynamic> orderDetails = {
        'id': orderId,
        'order_number': orderNumber,
        'status': data['status'] ?? 'Out for Delivery',
        'total_amount': data['total_amount'] ?? '0.00',
        'payment_method': data['payment_method'] ?? 'Unknown',
        'items': data['items'] ?? [],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      };

      // Navigate to order tracking page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            orderDetails: orderDetails,
          ),
        ),
      );
    } else {
      _navigateToNotifications(context);
    }
  }

  /// Handle test notification
  static void _handleTestNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling test notification');
    _navigateToNotifications(context);
  }

  /// Navigate to notifications page
  static void _navigateToNotifications(BuildContext context) {
    debugPrint('📱 Handler: Navigating to notifications page');

    // Navigate to notifications page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  /// Check if app was opened from notification
  static String? getNotificationPayload() {
    // This will be called from Android side
    // For now, we'll handle it through the method channel
    return null;
  }
}
