// services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get messengerKey => _messengerKey;

  // Show cashback notification
  static void showCashbackNotification(double amount,
      {VoidCallback? onWalletTap}) {
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
                      '🎉 Cashback Received!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You\'ve earned ₵${amount.toStringAsFixed(2)} cashback!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _messengerKey.currentState?.hideCurrentSnackBar();
                },
                icon: Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 5),
        margin: EdgeInsets.only(top: 16, left: 16, right: 16),
        elevation: 8,
      ),
    );
  }

  // Navigate to wallet page (fallback method)
  static void _navigateToWallet() {
    try {
      // Try to get the navigator from the messenger key context
      final context = _messengerKey.currentState?.context;
      if (context != null) {
        // Use Navigator.of(context) which is more reliable
        Navigator.of(context).pushNamed('/wallet');
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Navigation failed: $e');
      // If navigation fails, at least hide the snackbar
      _messengerKey.currentState?.hideCurrentSnackBar();
    }
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _messengerKey.currentState?.hideCurrentSnackBar();
                },
                icon: Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
        margin: EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  // Show error notification
  static void showErrorNotification(String title, String message) {
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _messengerKey.currentState?.hideCurrentSnackBar();
                },
                icon: Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
        margin: EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }
}
