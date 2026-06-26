// services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  // Track shown notifications to prevent duplicates
  static final Set<String> _shownNotifications = {};
  static final Map<String, Timer> _notificationTimers = {};

  // Generate unique key for notification
  static String _getNotificationKey(String title, String message) {
    return '${title}_$message';
  }

  // Check if notification was already shown
  static bool _hasBeenShown(String key) {
    return _shownNotifications.contains(key);
  }

  // Mark notification as shown and schedule cleanup
  static void _markAsShown(String key, Duration duration) {
    _shownNotifications.add(key);

    // Cancel existing timer if any
    _notificationTimers[key]?.cancel();

    // Schedule cleanup after notification duration
    _notificationTimers[key] = Timer(duration, () {
      _shownNotifications.remove(key);
      _notificationTimers.remove(key);
    });
  }

  // Clear all shown notifications (useful for testing or reset)
  static void clearShownNotifications() {
    _shownNotifications.clear();
    for (var timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();
  }

  // Show cashback notification
  static void showCashbackNotification(double amount,
      {VoidCallback? onWalletTap}) {
    final title = '🎉 Cashback Received!';
    final message = 'You\'ve earned ₵${amount.toStringAsFixed(2)} cashback!';
    final notificationKey = _getNotificationKey(title, message);

    // Check if this notification was already shown
    if (_hasBeenShown(notificationKey)) {
      debugPrint('📱 Notification already shown: $title - $message');
      return;
    }

    final duration = Duration(seconds: 2);

    // Mark as shown
    _markAsShown(notificationKey, duration);

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Swipe down to dismiss',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        margin: EdgeInsets.only(top: 16, left: 16, right: 16),
        elevation: 8,
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
      ),
    );
  }

  // Global navigation method that doesn't rely on specific context
  static void navigateToWallet() {
    try {
      debugPrint(
          '🔍 NotificationService: Attempting global navigation to wallet...');

      // Try to find a navigator from the messenger context
      final context = _messengerKey.currentState?.context;
      if (context != null) {
        debugPrint(
            '🔍 NotificationService: Context found, attempting navigation...');

        // Try to find the nearest navigator using multiple methods
        try {
          // Method 1: Direct Navigator.of(context)
          Navigator.of(context).pushNamed('/wallet');
          debugPrint(
              '✅ NotificationService: Navigation successful via Navigator.of(context)!');
          return;
        } catch (e) {
          debugPrint('❌ NotificationService: Method 1 failed: $e');
        }

        try {
          // Method 2: Find ancestor navigator state
          final navigatorState =
              context.findAncestorStateOfType<NavigatorState>();
          if (navigatorState != null) {
            navigatorState.pushNamed('/wallet');
            debugPrint(
                '✅ NotificationService: Navigation successful via ancestor NavigatorState!');
            return;
          }
        } catch (e) {
          debugPrint('❌ NotificationService: Method 2 failed: $e');
        }

        try {
          // Method 3: Find root navigator state
          final rootNavigatorState =
              context.findRootAncestorStateOfType<NavigatorState>();
          if (rootNavigatorState != null) {
            rootNavigatorState.pushNamed('/wallet');
            debugPrint(
                '✅ NotificationService: Navigation successful via root NavigatorState!');
            return;
          }
        } catch (e) {
          debugPrint('❌ NotificationService: Method 3 failed: $e');
        }

        debugPrint('❌ NotificationService: All navigation methods failed');
      } else {
        debugPrint('❌ NotificationService: No context available');
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Global navigation failed: $e');
    }
  }

  // Show general success notification
  static void showSuccessNotification(String title, String message) {
    final notificationKey = _getNotificationKey(title, message);

    // Check if this notification was already shown
    if (_hasBeenShown(notificationKey)) {
      debugPrint('📱 Notification already shown: $title - $message');
      return;
    }

    final duration = Duration(seconds: 2);

    // Mark as shown
    _markAsShown(notificationKey, duration);

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Swipe down to dismiss',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        margin: EdgeInsets.all(16),
        elevation: 8,
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
      ),
    );
  }

  // Show error notification
  static void showErrorNotification(String title, String message) {
    final notificationKey = _getNotificationKey(title, message);

    // Check if this notification was already shown
    if (_hasBeenShown(notificationKey)) {
      debugPrint('📱 Notification already shown: $title - $message');
      return;
    }

    final duration = Duration(seconds: 2);

    // Mark as shown
    _markAsShown(notificationKey, duration);

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Swipe down to dismiss',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        margin: EdgeInsets.all(16),
        elevation: 8,
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
      ),
    );
  }
}
