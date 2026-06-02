// pages/bottomnav.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_routes.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_nav_badge_icon.dart';
import 'homepage.dart' as home;
import 'categories.dart';
import 'cart.dart';
import 'profile.dart';
import 'pharmacists.dart';
import 'storelocation.dart';
import '../providers/notification_provider.dart';
import '../services/order_notification_service.dart';
import 'notifications.dart';
import '../utils/app_error_utils.dart';

class CustomBottomNav extends StatefulWidget {
  final int initialIndex;
  final GlobalKey? tourMenuKey;
  final GlobalKey? tourShopKey;

  const CustomBottomNav({
    super.key,
    this.initialIndex = 0,
    this.tourMenuKey,
    this.tourShopKey,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with TickerProviderStateMixin {
  late int _selectedIndex;
  bool _isNavigating = false;
  bool _disposed = false;
  late AnimationController _centerButtonController;
  late Animation<double> _centerButtonScaleAnimation;
  late Animation<double> _centerButtonRotationAnimation;

  // Animation controllers for each nav item
  late Map<int, AnimationController> _navItemControllers;
  late Map<int, Animation<double>> _navItemScaleAnimations;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkLoginStatus();

    // Initialize center button animation
    _centerButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _centerButtonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _centerButtonController,
      curve: Curves.easeInOut,
    ));

    _centerButtonRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.25,
    ).animate(CurvedAnimation(
      parent: _centerButtonController,
      curve: Curves.easeInOut,
    ));

    // Initialize nav item animations (0: Home, 1: Cart, 3: Categories, 4: Profile)
    _navItemControllers = {};
    _navItemScaleAnimations = {};

    for (int i = 0; i < 5; i++) {
      if (i != 2) {
        // Skip index 2 (center button)
        _navItemControllers[i] = AnimationController(
          duration: const Duration(milliseconds: 250),
          vsync: this,
        );

        _navItemScaleAnimations[i] = Tween<double>(
          begin: 1.0,
          end: 0.75,
        ).animate(CurvedAnimation(
          parent: _navItemControllers[i]!,
          curve: Curves.easeInOut,
        ));
      }
    }

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
    _centerButtonController.dispose();
    // Dispose all nav item controllers
    for (var controller in _navItemControllers.values) {
      controller.dispose();
    }
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
    int? itemIndex,
  }) {
    // Get animation for this item if it exists
    final animation = itemIndex != null && itemIndex != 2
        ? _navItemScaleAnimations[itemIndex]
        : null;

    Widget iconWidget;

    if (child != null) {
      // For icons with custom children (badges), apply opacity animation
      iconWidget = AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isSelected ? 1.0 : 0.7,
        child: child,
      );
    } else {
      // For simple icons, the BottomNavigationBar's selectedItemColor handles it
      iconWidget = Icon(icon);
    }

    // Wrap with scale animation if available
    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: animation.value,
            child: iconWidget,
          );
        },
      );
    }

    return iconWidget;
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

      // Disable "new notifications" popups; keep unread badge/count updates only.
      if (unreadCount == 0) {
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
          isScrollControlled: true,
          enableDrag: true,
          isDismissible: true,
          useSafeArea: true,
          builder: (BuildContext context) {
            return _AnimatedBottomSheet(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.apps_rounded,
                                color: Color(0xFF15803D),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    'Choose what you want to do',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMenuOption(
                                    context,
                                    icon: Icons.upload_file_rounded,
                                    title: 'Upload',
                                    subtitle: 'Prescription',
                                    color: Colors.purple.shade600,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.prescriptionUpload,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMenuOption(
                                    context,
                                    icon: Icons.medical_services_rounded,
                                    title: 'Pharmacist',
                                    subtitle: 'Consultation',
                                    color: Colors.green.shade600,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.pharmacists,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMenuOption(
                                    context,
                                    icon: Icons.location_on_rounded,
                                    title: 'Locator',
                                    subtitle: 'Retail outlets',
                                    color: Colors.blue.shade600,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.storeSelection,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMenuOption(
                                    context,
                                    icon: Icons.contact_support_rounded,
                                    title: 'Contact',
                                    subtitle: 'Support team',
                                    color: Colors.orange.shade600,
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showContactOptions(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      } catch (e, st) {
        debugPrint('BottomNav: menu sheet error: $e\n$st');
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    const String phoneNumber1 = '0302908674';
    const String phoneNumber2 = '0302908675';
    const String whatsapp = '0508411184';
    const String email = 'commerce@ecl.com.gh';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _AnimatedBottomSheet(
          child: Container(
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
                          subtitle: '0302908674, 0302908675',
                          color: Colors.green.shade600,
                          onTap: () async {
                            Navigator.pop(context);
                            // Show dialog to pick which number to call
                            final selected = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.phone),
                                      title: const Text('Call 0302908674'),
                                      onTap: () =>
                                          Navigator.pop(ctx, phoneNumber1),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.phone),
                                      title: const Text('Call 0302908675'),
                                      onTap: () =>
                                          Navigator.pop(ctx, phoneNumber2),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.phone),
                                      title: const Text(
                                          'Call 0508411184 (WhatsApp)'),
                                      onTap: () => Navigator.pop(ctx, whatsapp),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (selected != null) {
                              _launchPhoneDialer(selected);
                            }
                          },
                        ),
                        const Divider(height: 1),
                        _buildContactOption(
                          context,
                          icon: Icons.message_rounded,
                          title: 'WhatsApp',
                          subtitle: '0508411184 - Chat instantly',
                          color: const Color(0xFF25D366),
                          onTap: () {
                            Navigator.pop(context);
                            _launchWhatsApp(whatsapp,
                                "Hello! I need help with the ECL app. Can you assist me?");
                          },
                        ),
                        const Divider(height: 1),
                        _buildContactOption(
                          context,
                          icon: Icons.email_rounded,
                          title: 'Email Us',
                          subtitle: email,
                          color: Colors.blue.shade600,
                          onTap: () {
                            Navigator.pop(context);
                            _launchEmail(email, 'ECL App Support & Inquiry');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.05),
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
          AppErrorUtils.showSnack(
              context, 'WhatsApp is not installed on your device');
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
          AppErrorUtils.showSnack(
              context, 'No email app found on your device');
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

    // Animate the tapped item (except center button which has its own animation)
    if (index != 2 && _navItemControllers.containsKey(index)) {
      final controller = _navItemControllers[index]!;
      controller.forward().then((_) {
        controller.reverse();
      });
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
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.home,
              );
            } else {
              debugPrint('Already on home page, staying put');
            }
            break;
          case 1:
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.cart,
            );
            break;
          case 2:
            break;
          case 3:
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.categoryPage,
            );
            break;
          case 4:
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.profile,
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
                  unselectedItemColor: Colors.white.withValues(alpha: 0.7),
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
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  items: [
                    BottomNavigationBarItem(
                      icon: _buildIconWithGlow(
                        icon: Icons.home_rounded,
                        isSelected: _selectedIndex == 0,
                        itemIndex: 0,
                      ),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildIconWithGlow(
                        icon: Icons.shopping_cart_rounded,
                        isSelected: _selectedIndex == 1,
                        itemIndex: 1,
                        child: const CartNavBadgeIcon(),
                      ),
                      label: 'Cart',
                    ),
                    BottomNavigationBarItem(
                      icon: SizedBox.shrink(),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: widget.tourShopKey != null
                          ? KeyedSubtree(
                              key: widget.tourShopKey,
                              child: _buildIconWithGlow(
                                icon: Icons.grid_view_rounded,
                                isSelected: _selectedIndex == 3,
                                itemIndex: 3,
                              ),
                            )
                          : _buildIconWithGlow(
                              icon: Icons.grid_view_rounded,
                              isSelected: _selectedIndex == 3,
                              itemIndex: 3,
                            ),
                      label: 'Shop',
                    ),
                    BottomNavigationBarItem(
                      icon: Consumer<NotificationProvider>(
                        builder: (context, notificationProvider, child) {
                          return _buildIconWithGlow(
                            icon: Icons.person_rounded,
                            isSelected: _selectedIndex == 4,
                            itemIndex: 4,
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
                                                .withValues(alpha: 0.5),
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
          // Floating center button with fluid design and animation
          Positioned(
            left: 0,
            right: 0,
            top: -28,
            child: Center(
              child: AnimatedBuilder(
                animation: _centerButtonController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _centerButtonScaleAnimation.value,
                    child: Transform.rotate(
                      angle: _centerButtonRotationAnimation.value,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: InkWell(
                          onTap: () {
                            debugPrint('🔍 CENTER BUTTON TAPPED ===');
                            if (mounted && !_disposed && context.mounted) {
                              // Animate button press
                              _centerButtonController.forward().then((_) {
                                _centerButtonController.reverse();
                              });
                              // Show menu after a short delay
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                if (mounted && !_disposed && context.mounted) {
                                  _onItemTapped(2);
                                }
                              });
                            } else {
                              debugPrint('🔍 CONTEXT NOT AVAILABLE ===');
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          splashColor:
                              const Color(0xFF20AF67).withValues(alpha: 0.2),
                          highlightColor:
                              const Color(0xFF20AF67).withValues(alpha: 0.1),
                          child: Container(
                            key: widget.tourMenuKey,
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.98),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF20AF67)
                                      .withValues(alpha: 0.3),
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
                                    const Color(0xFF20AF67)
                                        .withValues(alpha: 0.1),
                                    const Color(0xFF20AF67)
                                        .withValues(alpha: 0.05),
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
                  );
                },
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

// Animated bottom sheet wrapper for smooth animations
class _AnimatedBottomSheet extends StatefulWidget {
  final Widget child;

  const _AnimatedBottomSheet({required this.child});

  @override
  State<_AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<_AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
