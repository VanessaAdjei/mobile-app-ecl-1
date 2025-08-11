// pages/bottomnav.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cartprovider.dart';
import 'homepage.dart' as home;
import 'categories.dart';
import 'cart.dart';
import 'profile.dart';
import 'notification_provider.dart';
import '../services/order_notification_service.dart';
import 'notifications.dart';

class CustomBottomNav extends StatefulWidget {
  final int initialIndex;

  const CustomBottomNav({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  late int _selectedIndex;
  bool _isNavigating = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkLoginStatus();

    // Check for new notifications when the app becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForNewNotifications();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Don't access context during dispose - it can cause issues
    // The snackbars will be cleared automatically when the widget is disposed
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.refreshLoginStatus();
  }

  Future<void> _checkForNewNotifications() async {
    try {
      final unreadCount =
          await OrderNotificationService.getCurrentUnreadCount();

      // Use NotificationProvider to check if snackbar was already shown globally
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      // Only show snackbar if there are unread notifications AND it hasn't been shown recently
      if (unreadCount > 0 &&
          mounted &&
          !_disposed &&
          !notificationProvider.hasShownSnackbar) {
        // Clear any existing snackbars first
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }

        // Mark as shown globally
        notificationProvider.markSnackbarAsShown();

        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have $unreadCount new notification${unreadCount > 1 ? 's' : ''}!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // Check if widget is still mounted before navigating
                  if (mounted) {
                    // Reset the notification flag since user is viewing notifications
                    notificationProvider.resetSnackbarFlag();

                    // Navigate directly to notifications page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }

        // Reset flag after a delay to allow future snackbars
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && !_disposed) {
            notificationProvider.resetSnackbarFlag();
          }
        });
      } else if (unreadCount == 0) {
        // If there are no unread notifications, reset the flag immediately
        notificationProvider.resetSnackbarFlag();
      }
    } catch (e) {
      debugPrint('Error checking for new notifications: $e');
    }
  }

  void _onItemTapped(int index) async {
    debugPrint('🔍 BOTTOM NAV TAPPED ===');
    debugPrint('Index: $index');
    debugPrint('Current Index: $_selectedIndex');

    // Clear any snackbars when user navigates
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    // Prevent multiple rapid taps
    if (_isNavigating) {
      debugPrint('🔍 ALREADY NAVIGATING - IGNORING TAP ===');
      return;
    }

    // Only return early if we're actually on the same page AND it's not the home button
    // For home button (index 0), we always want to navigate regardless of current index
    // For cart button (index 1), we also want to allow navigation to go back to cart from other pages
    if (index == _selectedIndex && index != 0 && index != 1) {
      debugPrint('🔍 SAME INDEX (NOT HOME OR CART) - RETURNING ===');
      return;
    }

    // Set navigating flag
    _isNavigating = true;

    // Update the selected index first
    setState(() {
      _selectedIndex = index;
    });

    // Use a longer delay to ensure the widget tree is stable
    await Future.delayed(Duration(milliseconds: 200));

    if (!mounted) {
      _isNavigating = false;
      return;
    }

    // Use WidgetsBinding.instance.addPostFrameCallback to ensure navigation happens after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isNavigating = false;
        return;
      }

      try {
        switch (index) {
          case 0:
            debugPrint('🔍 HOME BUTTON PRESSED ===');

            if (ModalRoute.of(context)?.settings.name != '/home') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const home.HomePage(),
                  settings: const RouteSettings(name: '/home'),
                ),
              );
            } else {
              debugPrint('Already on home page, staying put');
            }
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const Cart(),
              ),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CategoryPage(),
              ),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const Profile(),
              ),
            );
            break;
        }
      } catch (e) {
        debugPrint('🔍 NAVIGATION ERROR: $e ===');
      } finally {
        // Reset navigating flag after a delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && !_disposed) {
            setState(() {
              _isNavigating = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions
    final navHeight = screenHeight * 0.09; // 9% of screen height
    final iconSize = screenWidth * 0.05; // 5% of screen width
    final fontSize = screenWidth * 0.025; // 2.5% of screen width

    // Ensure minimum and maximum values
    final finalNavHeight = navHeight.clamp(60.0, 85.0);
    final finalIconSize = iconSize.clamp(18.0, 24.0);
    final finalFontSize = fontSize.clamp(8.0, 12.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: SizedBox(
        height: finalNavHeight,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedFontSize: finalFontSize,
          unselectedFontSize: finalFontSize,
          iconSize: finalIconSize,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cart.totalItems}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.person),
                      if (notificationProvider.unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${notificationProvider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
