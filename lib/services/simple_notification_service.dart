// services/simple_notification_service.dart
// services/simple_notification_service.dart

import 'package:flutter/foundation.dart';

class SimpleNotificationService {
  /// Show a simple notification (currently just logs for debugging)
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      debugPrint('📱 Simple: Attempting to show notification: $title');
      debugPrint('📱 Simple: Notification body: $body');
      debugPrint('📱 Simple: Notification payload: $payload');

      // For now, just log the notification
      // In a real implementation, this would show a system notification
      debugPrint(
          '📱 Simple: Notification logged successfully (system notification would appear here)');
    } catch (e) {
      debugPrint('Error showing simple notification: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
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
}
