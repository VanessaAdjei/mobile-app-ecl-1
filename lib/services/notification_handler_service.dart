// services/notification_handler_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/notifications.dart';
import 'package:eclapp/pages/order_tracking_page.dart';
import '../services/native_notification_service.dart';

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
          // Navigate immediately without delay
          _navigateToNotificationsImmediately(context);
          break;
      }
    } catch (e) {
      debugPrint('📱 Handler: Error processing payload: $e');
      _navigateToNotificationsImmediately(context);
    }
  }

  /// Handle order placed notification
  static void _handleOrderPlacedNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order placed notification');

    // Navigate to notifications page instead of order tracking page
    // Users can then choose to view order details from the notifications list
    _navigateToNotificationsImmediately(context);
  }

  /// Handle order status notification
  static void _handleOrderStatusNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling order status notification');

    // Navigate to notifications page instead of order tracking page
    // Users can then choose to view order details from the notifications list
    _navigateToNotificationsImmediately(context);
  }

  /// Handle delivery notification
  static void _handleDeliveryNotification(
      BuildContext context, Map<String, dynamic> data) {
    debugPrint('📱 Handler: Handling delivery notification');

    // Navigate to notifications page instead of order tracking page
    // Users can then choose to view order details from the notifications list
    _navigateToNotificationsImmediately(context);
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

    // Navigate to notifications page using global navigator key
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

  /// Navigate to notifications page immediately without delay
  static void _navigateToNotificationsImmediately(BuildContext context) {
    debugPrint('📱 Handler: Navigating to notifications page immediately');

    // Navigate to notifications page immediately using global navigator key
    final navigatorKey = NativeNotificationService.globalNavigatorKey;
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        ),
      );
    } else {
      debugPrint(
          '📱 Handler: Navigator not available for notifications navigation');
    }
  }

  /// Check if app was opened from notification
  static String? getNotificationPayload() {
    // This will be called from Android side
    // For now, we'll handle it through the method channel
    return null;
  }
}
