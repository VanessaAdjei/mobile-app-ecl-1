// pages/notification_provider.dart
import 'package:flutter/material.dart';
import '../services/order_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _hasShownSnackbar = false;

  int get unreadCount => _unreadCount;
  bool get hasShownSnackbar => _hasShownSnackbar;

  /// Initialize the provider and load the current unread count
  Future<void> initialize() async {
    debugPrint('📱 NotificationProvider: Initializing...');
    await _loadUnreadCount();
    debugPrint(
        '📱 NotificationProvider: Initialized with $_unreadCount unread notifications');
  }

  /// Load the current unread count from storage
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

  /// Refresh the unread count
  Future<void> refreshUnreadCount() async {
    await _loadUnreadCount();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await OrderNotificationService.markAsRead(notificationId);
    await _loadUnreadCount();
    notifyListeners();
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    notifyListeners();
  }

  /// Mark notifications as read when user actually views them
  Future<void> markNotificationsAsViewed() async {
    // Only mark as read if user actually opened the notifications page
    // This ensures the badge stays until user actually reads them
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await OrderNotificationService.clearAllNotifications();
    await _loadUnreadCount();
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
