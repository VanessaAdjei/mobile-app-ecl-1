// pages/notification_provider.dart
import 'package:flutter/material.dart';
import '../services/order_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _hasShownSnackbar = false;
  int _newOrderCount = 0; 

  int get unreadCount => _unreadCount;
  bool get hasShownSnackbar => _hasShownSnackbar;
  int get newOrderCount => _newOrderCount; 


  Future<void> initialize() async {
    debugPrint('📱 NotificationProvider: Initializing...');
    await _loadUnreadCount();
    await _loadNewOrderCount(); 
    debugPrint(
        '📱 NotificationProvider: Initialized with $_unreadCount unread notifications, $_newOrderCount new orders');
  }


  Future<void> _loadUnreadCount() async {
    try {
      _unreadCount = await OrderNotificationService.getCurrentUnreadCount();
      debugPrint(
          '📱 NotificationProvider: Loaded $_unreadCount unread notifications');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  /// Load the count of new order notifications specifically
  Future<void> _loadNewOrderCount() async {
    try {
      final notifications = await OrderNotificationService.getNotifications();
      _newOrderCount = notifications
          .where((notification) =>
              notification['is_read'] == false &&
              notification['type'] == 'order_placed')
          .length;
      debugPrint(
          '📱 NotificationProvider: Loaded $_newOrderCount new order notifications');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading new order count: $e');
    }
  }

  /// Refresh the unread count
  Future<void> refreshUnreadCount() async {
    await _loadUnreadCount();
    await _loadNewOrderCount(); // Also refresh new order count
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await OrderNotificationService.markAsRead(notificationId);
    await _loadUnreadCount();
    await _loadNewOrderCount(); // Also refresh new order count
    notifyListeners();
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    await _loadNewOrderCount(); // Also refresh new order count
    notifyListeners();
  }


  Future<void> markNotificationsAsViewed() async {
  
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    await _loadNewOrderCount(); 
    notifyListeners();
  }


  Future<void> clearAllNotifications() async {
    await OrderNotificationService.clearAllNotifications();
    await _loadUnreadCount();
    await _loadNewOrderCount(); // Also refresh new order count
  }

  /// Notify that a new notification was created (optimized for speed)
  void notifyNewNotification() {
    debugPrint(
        '📱 NotificationProvider: New notification created, updating count immediately...');

    // Update count immediately for fast badge updates
    _unreadCount++;
    notifyListeners();

    // Then refresh from storage in background
    _loadUnreadCount();
    _loadNewOrderCount(); // Also refresh new order count
  }

  /// Notify that a new order notification was created (optimized for speed)
  void notifyNewOrderNotification() {
    debugPrint(
        '📱 NotificationProvider: New ORDER notification created, updating count immediately...');

    // Update counts immediately for fast badge updates
    _unreadCount++;
    _newOrderCount++;
    notifyListeners();

    // Then refresh from storage in background
    _loadUnreadCount();
    _loadNewOrderCount();
  }

  /// Update badge count immediately (for external calls)
  void updateBadgeCount(int newCount) {
    if (_unreadCount != newCount) {
      _unreadCount = newCount;
      notifyListeners();
      debugPrint(
          '📱 NotificationProvider: Badge count updated to $_unreadCount');
    }
  }

  /// Force refresh from storage
  Future<void> forceRefresh() async {
    await _loadUnreadCount();
    await _loadNewOrderCount(); // Also refresh new order count
  }

  /// Mark snackbar as shown globally
  void markSnackbarAsShown() {
    _hasShownSnackbar = true;
    notifyListeners();
  }

  /// Reset snackbar flag
  void resetSnackbarFlag() {
    _hasShownSnackbar = false;
    notifyListeners();
  }
}
