// services/native_notification_service.dart
// services/native_notification_service.dart
// services/native_notification_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_handler_service.dart';
import '../pages/order_tracking_page.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('ecl_notifications');
  static final GlobalKey<NavigatorState> _globalNavigatorKey =
      GlobalKey<NavigatorState>();
  static String? _pendingNotificationPayload;

  /// Initialize the notification service
  static Future<void> initialize() async {
    try {
      debugPrint('📱 Native: Initializing notification service...');

      // Test the method channel first
      debugPrint('📱 Native: Testing method channel...');
      final testResult = await _channel.invokeMethod('test');
      debugPrint('📱 Native: Test result: $testResult');

      // Request notification permissions
      final permissionResult =
          await _channel.invokeMethod('requestPermissions');
      debugPrint('📱 Native: Permission result: $permissionResult');

      // Set up method call handler for immediate notification handling
      _channel.setMethodCallHandler((call) async {
        debugPrint('📱 Native: Received method call: ${call.method}');
        if (call.method == 'onNotificationOpened') {
          final data = call.arguments as Map<String, dynamic>?;
          if (data != null) {
            final payload = data['payload'] as String?;
            final action = data['action'] as String?;
            debugPrint(
                '📱 Native: Notification opened with payload: $payload, action: $action');

            // Store the payload for later handling
            if (payload != null && payload.isNotEmpty) {
              _pendingNotificationPayload = payload;
              debugPrint(
                  '📱 Native: Stored notification payload for later handling');
            }

            // Handle the notification immediately with action (non-blocking)
            if (payload != null && payload.isNotEmpty) {
              // Use microtask for faster execution
              Future.microtask(
                  () => _handleNotificationImmediately(payload, action));
            }
          }
        }
        return null;
      });

      debugPrint('📱 Native: Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing native notification service: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      // Don't throw the error, just log it and continue
      debugPrint('📱 Native: Continuing without native notifications...');
    }
  }

  /// Handle notification immediately when app is opened from notification
  static void _handleNotificationImmediately(String payload, String? action) {
    debugPrint(
        '📱 Native: Handling notification immediately: $payload, action: $action');

    // Use a global navigator key to handle navigation
    if (_globalNavigatorKey.currentState != null) {
      // Use immediate execution for faster response
      try {
        // Handle based on action for faster routing
        if (action == 'OPEN_ORDER_TRACKING') {
          _handleOrderTrackingNavigation(payload);
        } else {
          NotificationHandlerService.handleNotificationPayload(
            _globalNavigatorKey.currentContext!,
            payload,
          );
        }
        debugPrint('📱 Native: Notification handled successfully');
      } catch (e) {
        debugPrint('📱 Native: Error handling notification: $e');
      }
    } else {
      debugPrint('📱 Native: Navigator not ready yet, storing payload');
      _pendingNotificationPayload = payload;
    }
  }

  /// Handle order tracking navigation directly for faster response
  static void _handleOrderTrackingNavigation(String payload) {
    try {
      final Map<String, dynamic> data = json.decode(payload);
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

        // Navigate directly to order tracking page
        _globalNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(
              orderDetails: orderDetails,
            ),
          ),
        );
        debugPrint('📱 Native: Direct navigation to order tracking');
      }
    } catch (e) {
      debugPrint('📱 Native: Error in direct order tracking navigation: $e');
      // Fallback to general handler
      NotificationHandlerService.handleNotificationPayload(
        _globalNavigatorKey.currentContext!,
        payload,
      );
    }
  }

  /// Show a system notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      debugPrint('📱 Native: Attempting to show notification: $title');
      debugPrint('📱 Native: Notification body: $body');

      final notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch % 2147483647;
      debugPrint('📱 Native: Using notification ID: $notificationId');

      await _channel.invokeMethod('showNotification', {
        'id': notificationId,
        'title': title,
        'body': body,
        'payload': payload,
      });

      debugPrint('📱 Native: Notification sent successfully!');
    } catch (e) {
      debugPrint('Error showing native notification: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      // Log that we're falling back to console logging
      debugPrint('📱 Native: Falling back to console logging for notification');
      debugPrint('📱 Native: Would show notification: $title - $body');
    }
  }

  /// Test notification
  static Future<void> testNotification() async {
    await showNotification(
      title: 'Test Notification 📱',
      body: 'This is a test notification from ECL Pharmacy App!',
      payload: json.encode({
        'type': 'test',
        'message': 'Test notification',
      }),
    );
  }

  /// Get notification payload when app is opened from notification
  static Future<String?> getNotificationPayload() async {
    try {
      debugPrint('📱 Native: Getting notification payload...');
      final payload = await _channel.invokeMethod('getNotificationPayload');
      debugPrint('📱 Native: Received payload: $payload');
      return payload as String?;
    } catch (e) {
      debugPrint('Error getting notification payload: $e');
      return null;
    }
  }

  /// Get the global navigator key for notification handling
  static GlobalKey<NavigatorState> get globalNavigatorKey =>
      _globalNavigatorKey;

  /// Check if there's a pending notification payload
  static String? get pendingNotificationPayload => _pendingNotificationPayload;

  /// Clear pending notification payload
  static void clearPendingNotificationPayload() {
    debugPrint('📱 Native: Clearing pending notification payload');
    _pendingNotificationPayload = null;
  }

  /// Show order placed notification
  static Future<void> showOrderPlacedNotification({
    required String orderId,
    required String orderNumber,
    required String totalAmount,
  }) async {
    await showNotification(
      title: 'Order Placed Successfully! 🎉',
      body:
          'Order #$orderNumber has been placed successfully for $totalAmount.',
      payload: json.encode({
        'type': 'order_placed',
        'order_id': orderId,
        'order_number': orderNumber,
        'total_amount': totalAmount,
      }),
    );
  }

  /// Show order status notification
  static Future<void> showOrderStatusNotification({
    required String orderId,
    required String orderNumber,
    required String status,
    required String message,
  }) async {
    await showNotification(
      title: 'Order Status Update 📦',
      body: 'Order #$orderNumber: $message',
      payload: json.encode({
        'type': 'order_status',
        'order_id': orderId,
        'order_number': orderNumber,
        'status': status,
        'message': message,
      }),
    );
  }

  /// Show delivery notification
  static Future<void> showDeliveryNotification({
    required String orderId,
    required String orderNumber,
    required String message,
  }) async {
    await showNotification(
      title: 'Delivery Update 🚚',
      body: 'Order #$orderNumber: $message',
      payload: json.encode({
        'type': 'delivery_update',
        'order_id': orderId,
        'order_number': orderNumber,
        'message': message,
      }),
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _channel.invokeMethod('cancelAllNotifications');
      debugPrint('📱 Native: All notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      final result = await _channel.invokeMethod('areNotificationsEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }
}
