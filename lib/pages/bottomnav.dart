// pages/bottomnav.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'cartprovider.dart';
import 'homepage.dart' as home;
import 'categories.dart';
import 'cart.dart';
import 'profile.dart';
import 'pharmacists.dart';
import 'storelocation.dart';
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
      if (mounted && !_disposed) {
        _checkForNewNotifications();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.refreshLoginStatus();
  }

  bool _isOnHomePage() {
    try {
      // check route name first
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null) {
        final routeName = currentRoute.settings.name;
        if (routeName == '/home') {
          return true;
        }
      }

      // check if we're at the root (cant go back)
      if (Navigator.of(context).canPop() == false) {
        return true;
      }

      // check current page by looking at the context
      final currentPage =
          context.findAncestorWidgetOfExactType<home.HomePage>();
      if (currentPage != null) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking if on home page: $e');
      return false;
    }
  }

  // check if we're currently on a specific page type
  bool _isOnPage<T extends Widget>() {
    try {
      final currentPage = context.findAncestorWidgetOfExactType<T>();
      return currentPage != null;
    } catch (e) {
      debugPrint('Error checking if on page: $e');
      return false;
    }
  }

  // Build icon with subtle active indicator when selected
  Widget _buildIconWithGlow({
    required IconData icon,
    required bool isSelected,
    Widget? child,
  }) {
    // Simple color intensity change - brighter white when selected
    // The BottomNavigationBar handles the base color, we just enhance visibility
    if (child != null) {
      // For icons with custom children (badges), apply opacity animation
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isSelected ? 1.0 : 0.7,
        child: child,
      );
    }

    // For simple icons, the BottomNavigationBar's selectedItemColor handles it
    // We just return the icon - the color is controlled by the nav bar
    return Icon(icon);
  }

  // get the name of the current page (for debugging)
  String _getCurrentPageName() {
    try {
      if (_isOnHomePage()) return 'HomePage';
      if (_isOnPage<Cart>()) return 'Cart';
      if (_isOnPage<CategoryPage>()) return 'CategoryPage';
      if (_isOnPage<Profile>()) return 'Profile';
      return 'Unknown';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> _checkForNewNotifications() async {
    if (!mounted || _disposed) return;

    try {
      final unreadCount =
          await OrderNotificationService.getCurrentUnreadCount();

      if (!mounted || _disposed) return;

      // use NotificationProvider to check if snackbar should be shown
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      // only show snackbar if there are NEW unread notifications (count increased)
      if (mounted &&
          !_disposed &&
          notificationProvider.shouldShowSnackbar(unreadCount)) {
        // mark as shown globally with the current unread count
        notificationProvider.markSnackbarAsShown(unreadCount);

        // Use post frame callback to show snackbar safely
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _disposed || !context.mounted) return;

          final scaffoldMessenger = ScaffoldMessenger.of(context);

          // Clear any existing snackbars first, then show new one
          scaffoldMessenger.clearSnackBars();

          // Show the snackbar
          scaffoldMessenger.showSnackBar(
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
                  // Hide snackbar immediately when View is pressed
                  scaffoldMessenger.hideCurrentSnackBar();

                  // check if widget is still mounted before navigating
                  if (mounted && !_disposed && context.mounted) {
                    // reset the notification tracking since they're viewing notifications
                    notificationProvider.resetOnNotificationsRead();

                    // go directly to notifications page and scroll to top
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(
                          scrollToTop: true,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        });
      } else if (unreadCount == 0) {
        // if there are no unread notifications, reset everything
        notificationProvider.resetOnNotificationsRead();
      }
    } catch (e) {
      debugPrint('Error checking for new notifications: $e');
    }
  }

  void _showPlusMenu(BuildContext context) {
    // Check if already navigating to prevent multiple calls
    if (_isNavigating) {
      debugPrint('🔍 ALREADY NAVIGATING - IGNORING PLUS MENU ===');
      return;
    }

    // Defer showing the bottom sheet until after the current frame
    // to avoid Navigator lock issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed || !context.mounted) return;

      try {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuOption(
                            context,
                            icon: Icons.medical_services_rounded,
                            title: 'Meet your pharmacist',
                            subtitle: 'Chat or schedule a consultation',
                            color: Colors.green.shade600,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PharmacistsPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildMenuOption(
                            context,
                            icon: Icons.location_on_rounded,
                            title: 'Locate a store',
                            subtitle: 'See nearby branches on the map',
                            color: Colors.blue.shade600,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const StoreSelectionPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildMenuOption(
                            context,
                            icon: Icons.contact_support_rounded,
                            title: 'Contact us',
                            subtitle: 'Call or email customer care',
                            color: Colors.orange.shade600,
                            onTap: () {
                              Navigator.pop(context);
                              _showContactOptions(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } catch (e) {
        debugPrint('🔍 ERROR SHOWING PLUS MENU: $e ===');
      }
    });
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.1,
                  colors: [
                    color.withOpacity(0.18),
                    color.withOpacity(0.05),
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    const String phoneNumber = '+233508411184';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildContactOption(
                        context,
                        icon: Icons.phone_rounded,
                        title: 'Call Us',
                        subtitle: 'Speak directly with our team',
                        color: Colors.green.shade600,
                        onTap: () {
                          Navigator.pop(context);
                          _launchPhoneDialer(phoneNumber);
                        },
                      ),
                      const Divider(height: 1),
                      _buildContactOption(
                        context,
                        icon: Icons.message_rounded,
                        title: 'WhatsApp',
                        subtitle: 'Chat with us instantly',
                        color: const Color(0xFF25D366),
                        onTap: () {
                          Navigator.pop(context);
                          _launchWhatsApp(phoneNumber,
                              "Hello! I need help with the ECL app. Can you assist me?");
                        },
                      ),
                      const Divider(height: 1),
                      _buildContactOption(
                        context,
                        icon: Icons.email_rounded,
                        title: 'Email Us',
                        subtitle: 'Send us a detailed message',
                        color: Colors.blue.shade600,
                        onTap: () {
                          Navigator.pop(context);
                          _launchEmail('support@ernestchemists.com',
                              'ECL App Support & Inquiry');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.1,
                  colors: [
                    color.withOpacity(0.18),
                    color.withOpacity(0.05),
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhoneDialer(String phoneNumber) async {
    if (!mounted || _disposed) return;

    final permissionStatus = await Permission.phone.request();

    if (!mounted || _disposed) return;

    if (permissionStatus.isGranted) {
      final String formattedPhoneNumber = 'tel:$phoneNumber';
      if (await canLaunchUrl(Uri.parse(formattedPhoneNumber))) {
        await launchUrl(Uri.parse(formattedPhoneNumber));
      }
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    if (phoneNumber.isEmpty || message.isEmpty) {
      return;
    }

    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+$phoneNumber';
    }

    final String encodedMessage = Uri.encodeComponent(message);
    final String whatsappUrl =
        'https://wa.me/$phoneNumber?text=$encodedMessage';

    try {
      final Uri uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on your device'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  Future<void> _launchEmail(String email, String subject) async {
    try {
      const String emailBody =
          'Hello,\n\nI would like to contact Ernest Chemists Limited for support.\n\nBest regards,';
      final Uri emailUri = Uri.parse(
          'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}');
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No email app found on your device'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  void _onItemTapped(int index) {
    debugPrint('🔍 BOTTOM NAV TAPPED ===');
    debugPrint('Index: $index');
    debugPrint('Current Index: $_selectedIndex');
    debugPrint('Current Page: ${_getCurrentPageName()}');

    // Clear any snackbars when user navigates
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    // prevent multiple rapid taps
    if (_isNavigating) {
      debugPrint('🔍 ALREADY NAVIGATING - IGNORING TAP ===');
      return;
    }

    // Special handling for plus icon (index 2) - show menu and return
    if (index == 2) {
      debugPrint('🔍 PLUS BUTTON TAPPED - SHOWING MENU ===');
      _showPlusMenu(context);
      return; // Don't proceed with navigation logic
    }

    // Check if we're already on the selected page
    // For home button (index 0), check if we're already on home page
    // For other buttons, check if we're already on that page
    if (index == _selectedIndex) {
      if (index == 0) {
        // home button: check if we're already on home page
        if (_isOnHomePage()) {
          debugPrint('🔍 ALREADY ON HOME PAGE - STAYING PUT ===');
          return;
        }
      } else {
        // other buttons: check if we're already on the target page
        switch (index) {
          case 1: // Cart
            if (_isOnPage<Cart>()) {
              debugPrint('🔍 ALREADY ON CART PAGE - STAYING PUT ===');
              return;
            }
            break;
          case 2: // Plus icon - no page check needed
            // Plus icon action will be handled in switch statement
            break;
          case 3: // Categories
            if (_isOnPage<CategoryPage>()) {
              debugPrint('🔍 ALREADY ON CATEGORIES PAGE - STAYING PUT ===');
              return;
            }
            break;
          case 4: // Profile
            if (_isOnPage<Profile>()) {
              debugPrint('🔍 ALREADY ON PROFILE PAGE - STAYING PUT ===');
              return;
            }
            break;
        }
      }
    }

    // set navigating flag
    _isNavigating = true;

    // Update state immediately (synchronously) - safe in tap handler
    setState(() {
      _selectedIndex = index;
    });

    // Use Future.microtask instead of addPostFrameCallback to avoid frame conflicts
    // This defers navigation to the next event loop iteration, after the current frame
    Future.microtask(() {
      if (!mounted || _disposed || !context.mounted) {
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
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CategoryPage(),
              ),
            );
            break;
          case 4:
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
        // Reset navigating flag
        if (mounted && !_disposed) {
          _isNavigating = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final iconSize = screenWidth * 0.05;
    final fontSize = screenWidth * 0.025;

    final finalIconSize = iconSize.clamp(16.0, 20.0);
    final finalFontSize = fontSize.clamp(7.0, 10.0);

    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main navigation bar with curved notch
          Container(
            constraints: BoxConstraints(
              minHeight: 68.0,
              maxHeight: 88.0,
            ),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipPath(
              clipper: _NotchedBottomNavClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 4),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white.withOpacity(0.7),
                  elevation: 0,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedFontSize: finalFontSize,
                  unselectedFontSize: finalFontSize,
                  iconSize: finalIconSize,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedLabelStyle: TextStyle(
                    fontSize: finalFontSize,
                    height: 0.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: finalFontSize,
                    height: 0.5,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  items: [
                    BottomNavigationBarItem(
                      icon: _buildIconWithGlow(
                        icon: Icons.home_rounded,
                        isSelected: _selectedIndex == 0,
                      ),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildIconWithGlow(
                        icon: Icons.shopping_cart_rounded,
                        isSelected: _selectedIndex == 1,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(Icons.shopping_cart_rounded),
                            if (cart.totalItems > 0)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
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
                      ),
                      label: 'Cart',
                    ),
                    BottomNavigationBarItem(
                      icon: SizedBox.shrink(),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildIconWithGlow(
                        icon: Icons.grid_view_rounded,
                        isSelected: _selectedIndex == 3,
                      ),
                      label: 'Categories',
                    ),
                    BottomNavigationBarItem(
                      icon: Consumer<NotificationProvider>(
                        builder: (context, notificationProvider, child) {
                          return _buildIconWithGlow(
                            icon: Icons.person_rounded,
                            isSelected: _selectedIndex == 4,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(Icons.person_rounded),
                                if (notificationProvider.unreadCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color:
                                            notificationProvider.newOrderCount >
                                                    0
                                                ? Colors.blue
                                                : Colors.orange,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (notificationProvider
                                                            .newOrderCount >
                                                        0
                                                    ? Colors.blue
                                                    : Colors.orange)
                                                .withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
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
                            ),
                          );
                        },
                      ),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Floating center button with fluid design
          Positioned(
            left: 0,
            right: 0,
            top: -28,
            child: Center(
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    debugPrint('🔍 CENTER BUTTON TAPPED ===');
                    if (mounted && !_disposed && context.mounted) {
                      _onItemTapped(2);
                    } else {
                      debugPrint('🔍 CONTEXT NOT AVAILABLE ===');
                    }
                  },
                  borderRadius: BorderRadius.circular(30),
                  splashColor: const Color(0xFF20AF67).withValues(alpha: 0.2),
                  highlightColor:
                      const Color(0xFF20AF67).withValues(alpha: 0.1),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.98),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF20AF67).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF20AF67).withOpacity(0.1),
                            const Color(0xFF20AF67).withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.apps_rounded,
                        color: Color(0xFF20AF67),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom clipper for curved notch in bottom nav
class _NotchedBottomNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final notchRadius = 35.0;
    final notchHeight = 20.0;

    // Start from top left
    path.moveTo(0, 0);

    // Line to start of left curve
    path.lineTo(centerX - notchRadius - 15, 0);

    // Left curve going down
    path.quadraticBezierTo(
      centerX - notchRadius - 5,
      0,
      centerX - notchRadius,
      notchHeight * 0.3,
    );

    // Bottom curve of notch
    path.arcToPoint(
      Offset(centerX + notchRadius, notchHeight * 0.3),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    // Right curve going up
    path.quadraticBezierTo(
      centerX + notchRadius + 5,
      0,
      centerX + notchRadius + 15,
      0,
    );

    // Complete the rectangle
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
