// services/order_notification_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/order_tracking_repository.dart';
import '../utils/order_notification_policy.dart';
import '../utils/product_image_url.dart';
import 'native_notification_service.dart';

class OrderNotificationService {
  static const String _notificationsKey = 'order_notifications';
  static const String _unreadCountKey = 'unread_notification_count';

  // Audio player for notification sounds

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
        'items': await _resolveItems(
          orderData['id']?.toString() ??
              orderData['transaction_id']?.toString() ??
              '',
          orderData['items'] as List<dynamic>? ??
              orderData['order_items'] as List<dynamic>?,
        ),
      };

      // Update count immediately for fast badge updates
      await _addNotificationOptimized(notification);

      // Notify the provider about the new order notification
      if (_onBadgeUpdate != null) {
        _onBadgeUpdate!(await getUnreadCount());
      }

      await _persistOrderForBackgroundTracking(orderData);

      // Always show system notification; in-app SnackBar is deferred until the user
      // leaves the post-checkout confirmation page.
      try {
        await NativeNotificationService.ensureSystemNotificationsEnabled(
          requestIfNeeded: true,
        );
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

  static String _guestOrderUpdatesHint({
    required String phone,
    required String email,
  }) {
    final hasPhone = phone.isNotEmpty;
    final hasEmail = email.isNotEmpty;
    if (hasPhone && hasEmail) {
      return ' Updates go to $phone and $email.';
    }
    if (hasPhone) return ' Text updates go to $phone.';
    if (hasEmail) return ' Email updates go to $email.';
    return ' Updates will be sent by text and email.';
  }

  /// One system notification for guests — no in-app inbox (SMS/email off-app).
  static Future<void> createGuestOrderPlacedNotification(
    Map<String, dynamic> orderData,
  ) async {
    try {
      await _persistOrderForBackgroundTracking(orderData);

      final orderRef = orderData['order_number']?.toString() ??
          orderData['id']?.toString() ??
          '';
      final phone = orderData['contact_number']?.toString().trim() ?? '';
      final email = orderData['email']?.toString().trim() ?? '';
      final updateHint = _guestOrderUpdatesHint(phone: phone, email: email);

      await NativeNotificationService.ensureSystemNotificationsEnabled(
        requestIfNeeded: true,
      );
      await NativeNotificationService.showNotification(
        title: 'Order placed',
        body: orderRef.isEmpty
            ? 'Your order is confirmed.$updateHint'
            : 'Order #$orderRef placed.$updateHint',
        payload: json.encode({
          'type': 'order_placed',
          'order_id': orderData['id']?.toString() ?? '',
          'order_number': orderRef,
          'status': orderData['status'] ?? 'Order Placed',
          'total_amount': orderData['total_amount'] ?? '0.00',
          'payment_method': orderData['payment_method'] ?? 'Unknown',
          'items': orderData['items'] ?? [],
          'created_at':
              orderData['created_at'] ?? DateTime.now().toIso8601String(),
          'is_guest': true,
        }),
      );

      debugPrint('📱 Guest order placed notification shown');
    } catch (e) {
      debugPrint('Error creating guest order placed notification: $e');
    }
  }

  static Future<void> _persistOrderForBackgroundTracking(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString('user_orders');
      final List<Map<String, dynamic>> existing = [];
      if (existingJson != null) {
        final list = json.decode(existingJson) as List<dynamic>?;
        if (list != null) {
          for (final o in list) {
            existing.add(Map<String, dynamic>.from(o));
          }
        }
      }
      final orderMap = Map<String, dynamic>.from(orderData);
      final id = orderMap['id']?.toString() ??
          orderMap['transaction_id']?.toString() ??
          '';
      if (id.isEmpty) return;

      orderMap['delivery_id'] = id;
      final byId = <String, Map<String, dynamic>>{};
      for (final o in existing) {
        final k = o['delivery_id']?.toString() ??
            o['transaction_id']?.toString() ??
            o['id']?.toString() ??
            '';
        if (k.isNotEmpty) byId[k] = o;
      }
      byId[id] = orderMap;
      await prefs.setString('user_orders', json.encode(byId.values.toList()));
    } catch (_) {}
  }

  /// In-app list + system notification when the store confirms the order.
  static Future<void> createOrderConfirmedNotification({
    required String orderId,
    required String orderNumber,
    String? totalAmount,
    List<dynamic>? items,
  }) async {
    final ref =
        orderNumber.isNotEmpty ? orderNumber : (orderId.isNotEmpty ? orderId : '');
    await createOrderStatusNotification(
      orderId: orderId,
      orderNumber: orderNumber,
      status: 'Order Confirmed',
      title: 'Order Confirmed!',
      message: ref.isEmpty
          ? 'Your order has been confirmed and is being prepared.'
          : 'Your order #$ref has been confirmed and is being prepared.',
      totalAmount: totalAmount,
      items: items,
    );
  }

  /// Create a notification for order status/tracking stage changes.
  /// Call this for every stage: Order Placed, Confirmed, Ready for Dispatch, Out for Delivery, Delivered, Cancelled.
  static Future<void> createOrderStatusNotification({
    required String orderId,
    required String orderNumber,
    required String status,
    required String title,
    required String message,
    String? totalAmount,
    List<dynamic>? items,
  }) async {
    try {
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'order_status',
        'title': title,
        'message': message,
        'order_id': orderId,
        'order_number': orderNumber,
        'status': status,
        'total_amount': totalAmount != null ? _formatAmount(totalAmount) : '',
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
        'icon': _getStatusIcon(status),
        'color': _getStatusColor(status),
        'items': await _resolveItems(orderId, items),
      };

      await _addNotificationOptimized(notification);

      await OrderTrackingRepositoryImpl().saveStatusHint(
        status: status,
        orderId: orderId,
        orderNumber: orderNumber,
      );

      if (_onBadgeUpdate != null) {
        _onBadgeUpdate!(await getUnreadCount());
      }

      if (OrderNotificationPolicy.shouldShowSystemPush(
        type: 'order_status',
        status: status,
      )) {
        try {
          await NativeNotificationService.ensureSystemNotificationsEnabled(
            requestIfNeeded: true,
          );
          await NativeNotificationService.showNotification(
            title: title,
            body: message,
            payload: json.encode({
              'type': 'order_status',
              'order_id': orderId,
              'order_number': orderNumber,
              'status': status,
            }),
          );
        } catch (e) {
          debugPrint('Error showing order status system notification: $e');
        }
      } else {
        debugPrint('📱 In-app only (no push) for status: $status');
      }

      debugPrint('📱 Order status notification created: $status');
    } catch (e) {
      debugPrint('Error creating order status notification: $e');
    }
  }

  static String _getStatusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('placed') || s.contains('pending')) return 'shopping_cart';
    if (s.contains('confirm') || s.contains('paid') || s.contains('process')) {
      return 'verified';
    }
    if (s.contains('ship') || s.contains('delivery') || s.contains('out for')) {
      return 'local_shipping';
    }
    if (s.contains('delivered')) return 'check_circle';
    if (s.contains('cancel')) return 'cancel';
    return 'info';
  }

  static String _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('delivered')) return 'green';
    if (s.contains('cancel')) return 'red';
    if (s.contains('ship') || s.contains('delivery')) return 'blue';
    return 'orange';
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
      final shouldBumpUnread = await _upsertNotification(notification);
      if (!shouldBumpUnread) {
        debugPrint('📱 Notification deduped — badge unchanged');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentUnreadCount = prefs.getInt(_unreadCountKey) ?? 0;
      final newUnreadCount = currentUnreadCount + 1;
      await prefs.setInt(_unreadCountKey, newUnreadCount);

      if (_onBadgeUpdate != null) {
        _onBadgeUpdate!(newUnreadCount);
      }

      debugPrint('📱 Badge updated immediately: $newUnreadCount');
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  /// Inserts or updates an existing row for the same order + status bucket.
  /// Returns `true` when the unread badge should increase.
  static Future<bool> _upsertNotification(
      Map<String, dynamic> notification) async {
    try {
      final notifications = await getNotifications();
      final incomingKey = OrderNotificationPolicy.dedupeKey(notification);

      final existingIndex = notifications.indexWhere(
        (n) => OrderNotificationPolicy.dedupeKey(n) == incomingKey,
      );

      if (existingIndex >= 0) {
        final existing = Map<String, dynamic>.from(notifications[existingIndex]);
        final wasRead = existing['is_read'] == true;

        notifications[existingIndex] = {
          ...existing,
          ...notification,
          'id': existing['id'],
          'is_read': wasRead,
          'timestamp': notification['timestamp'],
        };

        await _saveNotifications(notifications);
        debugPrint('📱 Updated existing notification for $incomingKey');
        return false;
      }

      notifications.insert(0, notification);
      if (notifications.length > 50) {
        notifications.removeRange(50, notifications.length);
      }

      await _saveNotifications(notifications);
      return true;
    } catch (e) {
      debugPrint('Error upserting notification: $e');
      return true;
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

  /// Normalize line items so UI can show every product image reliably.
  static List<Map<String, dynamic>> normalizeNotificationItems(
    List<dynamic>? raw,
  ) {
    if (raw == null || raw.isEmpty) return [];
    final normalized = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      final image = coerceProductImageSource(
        m['product_img'] ??
            m['imageUrl'] ??
            m['image'] ??
            m['image_url'] ??
            m['product_image'] ??
            m['product_image_url'],
      );
      final name =
          m['product_name']?.toString() ?? m['name']?.toString() ?? 'Item';
      final qty = m['qty'] ?? m['quantity'] ?? 1;
      normalized.add({
        ...m,
        'name': name,
        'product_name': name,
        'quantity': qty,
        'qty': qty,
        'imageUrl': image,
        'product_img': image,
      });
    }
    return normalized;
  }

  static Future<List<Map<String, dynamic>>> _resolveItems(
    String orderId,
    List<dynamic>? items,
  ) async {
    var normalized = normalizeNotificationItems(items);
    if (normalized.isNotEmpty || orderId.isEmpty) return normalized;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString('user_orders');
      if (existingJson == null) return normalized;

      final list = json.decode(existingJson) as List<dynamic>?;
      if (list == null) return normalized;

      for (final entry in list) {
        if (entry is! Map) continue;
        final order = Map<String, dynamic>.from(entry);
        final ids = <String>{
          order['delivery_id']?.toString() ?? '',
          order['transaction_id']?.toString() ?? '',
          order['id']?.toString() ?? '',
          order['order_number']?.toString() ?? '',
        }..removeWhere((v) => v.isEmpty);
        if (!ids.contains(orderId)) continue;

        normalized = normalizeNotificationItems(
          order['items'] as List<dynamic>? ??
              order['order_items'] as List<dynamic>?,
        );
        if (normalized.isNotEmpty) return normalized;
      }
    } catch (e) {
      debugPrint('Error resolving notification items from cache: $e');
    }
    return normalized;
  }

  /// Generate order message with purchased items
  static String _generateOrderMessage(Map<String, dynamic> orderData) {
    final orderNumber = orderData['order_number'] ?? orderData['id'] ?? '';
    final items = orderData['items'] as List<dynamic>? ?? [];

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
      return 'Your order #$orderNumber for ${itemNames.first} has been placed and is being processed.';
    } else if (itemNames.length <= 3) {
      final itemList = itemNames.join(', ');
      return 'Your order #$orderNumber for $itemList has been placed and is being processed.';
    } else {
      final firstItems = itemNames.take(2).join(', ');
      final remainingCount = itemNames.length - 2;
      return 'Your order #$orderNumber for $firstItems and $remainingCount more items has been placed and is being processed.';
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
        final formatted = 'GHS${parsedAmount.toStringAsFixed(2)}';
        debugPrint('📱 Formatted amount: "$formatted"');
        return formatted;
      }
    } catch (e) {
      debugPrint('Error parsing amount: $e');
    }

    final fallback = 'GHS$amount';
    debugPrint('📱 Fallback amount: "$fallback"');
    return fallback;
  }
}
