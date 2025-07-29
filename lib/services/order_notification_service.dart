// services/order_notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'native_notification_service.dart';

class OrderNotificationService {
  static const String _notificationsKey = 'order_notifications';
  static const String _unreadCountKey = 'unread_notification_count';

  // Audio player for notification sounds
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Callback for immediate badge updates
  static Function(int)? _onBadgeUpdate;

  /// Set callback for immediate badge updates
  static void setBadgeUpdateCallback(Function(int) callback) {
    _onBadgeUpdate = callback;
  }

  // Initialize local notifications
  static Future<void> initializeNotifications() async {
    try {
      // Initialize the local notification service
      // Simple notification service doesn't need initialization

      // Fix any existing notifications with dollar signs
      await clearOldNotificationsWithDollarSigns();
      debugPrint('📱 Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  /// Create a notification for when an order is placed
  static Future<void> createOrderPlacedNotification(
      Map<String, dynamic> orderData) async {
    try {
      // Generate message with purchased items
      final message = _generateOrderMessage(orderData);

      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'order_placed',
        'title': 'Order Placed Successfully!',
        'message': message,
        'order_id': orderData['id']?.toString() ?? '',
        'order_number': orderData['order_number']?.toString() ??
            orderData['id']?.toString() ??
            '',
        'total_amount':
            _formatAmount(orderData['total_amount']?.toString() ?? ''),
        'status': 'Order Placed',
        'payment_method':
            orderData['payment_method']?.toString() ?? 'Online Payment',
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
        'icon': 'shopping_cart',
        'color': 'green',
        'items': orderData['items'] ?? [],
      };

      // Update count immediately for fast badge updates
      await _addNotificationOptimized(notification);

      // Show system notification
      try {
        await NativeNotificationService.showNotification(
          title: 'Order Placed Successfully! 🎉',
          body:
              'Order #${orderData['order_number']} has been placed successfully.',
          payload: json.encode({
            'type': 'order_placed',
            'order_id': orderData['id']?.toString() ?? '',
            'order_number': orderData['order_number']?.toString() ?? '',
            'status': orderData['status'] ?? 'Order Placed',
            'total_amount': orderData['total_amount'] ?? '0.00',
            'payment_method': orderData['payment_method'] ?? 'Unknown',
            'items': orderData['items'] ?? [],
            'created_at':
                orderData['created_at'] ?? DateTime.now().toIso8601String(),
          }),
        );
      } catch (e) {
        debugPrint('Error showing system notification: $e');
      }

      debugPrint('📱 Order placed notification created');
    } catch (e) {
      debugPrint('Error creating order placed notification: $e');
    }
  }

  /// Get all notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);

      if (notificationsJson != null) {
        final List<dynamic> notificationsList = json.decode(notificationsJson);
        return notificationsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications();
      return notifications
          .where((notification) => notification['is_read'] == false)
          .length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get current unread count from SharedPreferences (fast)
  static Future<int> getCurrentUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (e) {
      debugPrint('Error getting current unread count: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications.map((notification) {
        if (notification['id'] == notificationId) {
          notification['is_read'] = true;
        }
        return notification;
      }).toList();

      await _saveNotifications(updatedNotifications);
      await _updateUnreadCountOptimized();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications.map((notification) {
        notification['is_read'] = true;
        return notification;
      }).toList();

      await _saveNotifications(updatedNotifications);
      await _updateUnreadCountOptimized();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.remove(_unreadCountKey);
      debugPrint('📱 All notifications cleared');
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Clear old notifications with dollar signs and ensure proper formatting
  static Future<void> clearOldNotificationsWithDollarSigns() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = <Map<String, dynamic>>[];

      for (final notification in notifications) {
        final totalAmount = notification['total_amount']?.toString() ?? '';
        if (totalAmount.contains('\$') ||
            (!totalAmount.startsWith('GH₵') && totalAmount.isNotEmpty)) {
          // Update the amount to proper Ghanaian Cedi format
          notification['total_amount'] = _formatAmount(totalAmount);
          debugPrint(
              '📱 Updated notification amount: $totalAmount → ${notification['total_amount']}');
        }
        updatedNotifications.add(notification);
      }

      if (updatedNotifications.isNotEmpty) {
        await _saveNotifications(updatedNotifications);
        debugPrint(
            '📱 Updated ${updatedNotifications.length} notifications with proper currency format');
      }
    } catch (e) {
      debugPrint('Error updating old notifications: $e');
    }
  }

  /// Add a new notification with optimized badge updates
  static Future<void> _addNotificationOptimized(
      Map<String, dynamic> notification) async {
    try {
      // Get current unread count immediately
      final prefs = await SharedPreferences.getInstance();
      final currentUnreadCount = prefs.getInt(_unreadCountKey) ?? 0;

      // Update unread count immediately for fast badge updates
      final newUnreadCount = currentUnreadCount + 1;
      await prefs.setInt(_unreadCountKey, newUnreadCount);

      // Notify provider immediately for instant badge updates
      if (_onBadgeUpdate != null) {
        _onBadgeUpdate!(newUnreadCount);
      }

      // Add notification to list (async, but doesn't block badge update)
      _addNotificationToList(notification);

      debugPrint('📱 Badge updated immediately: $newUnreadCount');
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  /// Add notification to list (separate async operation)
  static Future<void> _addNotificationToList(
      Map<String, dynamic> notification) async {
    try {
      final notifications = await getNotifications();
      notifications.insert(0, notification); // Add to beginning

      // Keep only the last 50 notifications
      if (notifications.length > 50) {
        notifications.removeRange(50, notifications.length);
      }

      await _saveNotifications(notifications);
    } catch (e) {
      debugPrint('Error adding notification to list: $e');
    }
  }

  /// Save notifications to SharedPreferences
  static Future<void> _saveNotifications(
      List<Map<String, dynamic>> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsKey, json.encode(notifications));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Update unread count in SharedPreferences (optimized)
  static Future<void> _updateUnreadCountOptimized() async {
    try {
      final notifications = await getNotifications();
      final unreadCount = notifications
          .where((notification) => notification['is_read'] == false)
          .length;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, unreadCount);

      // Notify provider immediately
      if (_onBadgeUpdate != null) {
        _onBadgeUpdate!(unreadCount);
      }

      debugPrint('📱 Unread count updated: $unreadCount');
    } catch (e) {
      debugPrint('Error updating unread count: $e');
    }
  }

  /// Update unread count in SharedPreferences (legacy method)
  static Future<void> _updateUnreadCount() async {
    await _updateUnreadCountOptimized();
  }

  /// Generate order message with purchased items
  static String _generateOrderMessage(Map<String, dynamic> orderData) {
    final orderNumber = orderData['order_number'] ?? orderData['id'] ?? '';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final totalAmount =
        _formatAmount(orderData['total_amount']?.toString() ?? '');

    if (items.isEmpty) {
      return 'Your order #$orderNumber has been placed and is being processed.';
    }

    // Build item list
    final List<String> itemNames = [];
    for (final item in items) {
      final itemName = item['name']?.toString() ??
          item['product_name']?.toString() ??
          'Unknown Item';
      final quantity = item['quantity']?.toString() ?? '1';
      itemNames.add('$itemName (x$quantity)');
    }

    // Create message based on number of items
    if (itemNames.length == 1) {
      return 'Your order #$orderNumber for ${itemNames.first} has been placed and is being processed. Total: $totalAmount';
    } else if (itemNames.length <= 3) {
      final itemList = itemNames.join(', ');
      return 'Your order #$orderNumber for $itemList has been placed and is being processed. Total: $totalAmount';
    } else {
      final firstItems = itemNames.take(2).join(', ');
      final remainingCount = itemNames.length - 2;
      return 'Your order #$orderNumber for $firstItems and $remainingCount more items has been placed and is being processed. Total: $totalAmount';
    }
  }

  /// Format amount to Ghanaian Cedi
  static String _formatAmount(String amount) {
    if (amount.isEmpty) return '';

    debugPrint('📱 Formatting amount: "$amount"');

    // Remove any existing currency symbols and spaces
    String cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '');
    debugPrint('📱 Cleaned amount: "$cleanAmount"');

    // Try to parse as double
    try {
      double? parsedAmount = double.tryParse(cleanAmount);
      if (parsedAmount != null) {
        final formatted = 'GH₵${parsedAmount.toStringAsFixed(2)}';
        debugPrint('📱 Formatted amount: "$formatted"');
        return formatted;
      }
    } catch (e) {
      debugPrint('Error parsing amount: $e');
    }

    // If parsing fails, just add GH₵ prefix
    final fallback = 'GH₵$amount';
    debugPrint('📱 Fallback amount: "$fallback"');
    return fallback;
  }
}
