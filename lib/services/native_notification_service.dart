// services/native_notification_service.dart
// services/native_notification_service.dart
// services/native_notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('ecl_notifications');

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

      debugPrint('📱 Native: Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing native notification service: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      // Don't throw the error, just log it and continue
      debugPrint('📱 Native: Continuing without native notifications...');
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
      payload: 'test',
    );
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
