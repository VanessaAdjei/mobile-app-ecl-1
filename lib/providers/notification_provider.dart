// pages/notification_provider.dart
import 'package:flutter/material.dart';
import '../services/order_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _hasShownSnackbar = false;
  int _newOrderCount = 0;
  int _lastShownUnreadCount = 0; // Track the unread count that was last shown
  bool _isDisposed = false;

  int get unreadCount => _unreadCount;
  bool get hasShownSnackbar => _hasShownSnackbar;
  int get newOrderCount => _newOrderCount;

  // Check if we should show snackbar (only if count increased)
  bool shouldShowSnackbar(int currentUnreadCount) {
    // Only show if:
    // 1. There are unread notifications
    // 2. The count has increased since last shown (new notifications)
    // 3. We haven't already shown a snackbar for this count or higher
    final shouldShow = currentUnreadCount > 0 &&
        currentUnreadCount > _lastShownUnreadCount &&
        !_hasShownSnackbar;

    // If we've already shown for this count or higher, never show again
    if (_hasShownSnackbar && currentUnreadCount <= _lastShownUnreadCount) {
      return false;
    }

    return shouldShow;
  }

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

    // If all notifications are read, reset tracking
    if (_unreadCount == 0) {
      resetOnNotificationsRead();
    }

    notifyListeners();
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    await _loadNewOrderCount();

    // Reset tracking since all notifications are read
    resetOnNotificationsRead();

    notifyListeners();
  }

  Future<void> markNotificationsAsViewed() async {
    await OrderNotificationService.markAllAsRead();
    await _loadUnreadCount();
    await _loadNewOrderCount();

    // Reset tracking since notifications are viewed
    resetOnNotificationsRead();

    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    await OrderNotificationService.clearAllNotifications();
    await _loadUnreadCount();
    await _loadNewOrderCount();
  }

  void notifyNewNotification() {
    debugPrint(
        '📱 NotificationProvider: New notification created, updating count immediately...');

    // Update count immediately for fast badge updates
    _unreadCount++;
    notifyListeners();

    _loadUnreadCount();
    _loadNewOrderCount();
  }

  void notifyNewOrderNotification() {
    _unreadCount++;
    _newOrderCount++;
    notifyListeners();

    _loadUnreadCount();
    _loadNewOrderCount();
  }

  void updateBadgeCount(int newCount) {
    if (_unreadCount != newCount) {
      _unreadCount = newCount;
      notifyListeners();
    }
  }

  Future<void> forceRefresh() async {
    await _loadUnreadCount();
    await _loadNewOrderCount();
  }

  /// Mark snackbar as shown globally with the current unread count
  void markSnackbarAsShown(int unreadCount) {
    _hasShownSnackbar = true;
    _lastShownUnreadCount = unreadCount; // Remember the count that was shown
    notifyListeners();
  }

  /// Reset snackbar flag (but keep the last shown count to prevent re-showing same notifications)
  void resetSnackbarFlag() {
    _hasShownSnackbar = false;
    // Don't reset _lastShownUnreadCount - we want to remember what was shown
    notifyListeners();
  }

  /// Reset everything when notifications are read
  void resetOnNotificationsRead() {
    _hasShownSnackbar = false;
    _lastShownUnreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
