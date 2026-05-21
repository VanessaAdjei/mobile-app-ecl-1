// pages/profile.dart

import 'package:eclapp/pages/loggedout.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/providers/theme_provider.dart';
import 'package:eclapp/services/wishlist_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'bottomnav.dart';
import '../config/app_routes.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../providers/cart_provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<Profile> with TickerProviderStateMixin {
  String _userName = "User";
  String _userEmail = "No email available";
  bool _userLoggedIn = false;
  late AnimationController _contentAnimationController;
  late Animation<double> _contentAnimation;
  final ScrollController _scrollController = ScrollController();
  int? _wishlistCount; // Cache wishlist count to allow refresh

  @override
  void initState() {
    super.initState();

    // set up the animations
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutQuart,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentAnimationController.forward();
    });
  }

  Future<void> _initializeUserData() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() {
        _userLoggedIn = loggedIn;
      });
      if (loggedIn) {
        await _loadUserData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userName = userData?['name'] ?? "User";
        _userEmail = userData?['email'] ?? "No email available";
      });
    } catch (e) {
      debugPrint('Error loading user data in profile: $e');
      if (!mounted) return;
      setState(() {
        _userName = "User";
        _userEmail = "No email available";
      });
    }
  }

  void _navigateTo(String routeName, {Map<String, dynamic>? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments).then((_) {
      if (routeName == AppRoutes.wishlist && mounted) {
        _refreshWishlistCount();
      }
    });
  }

  Future<void> _refreshWishlistCount() async {
    if (!mounted) return;
    try {
      final count =
          await WishlistService.instance.getWishlistCount(useCache: false);
      if (mounted) {
        setState(() {
          _wishlistCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing wishlist count: $e');
    }
  }

  void _navigateToRefillPage() {
    Navigator.pushNamed(context, AppRoutes.refill);
  }

  void _showLogoutDialog() {
    if (!mounted) return;

    // Store context reference before showing dialog
    final currentContext = context;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Confirm Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to logout from your account?",
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () async {
                // get the providers before we do async stuff
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                bool logoutSuccess = false;
                String? errorMsg;
                try {
                  debugPrint(' Starting logout process');
                  await AuthService.logout();
                  debugPrint(' AuthService.logout() completed');
                  try {
                    await authProvider.logout();
                    debugPrint('🔍 Profile: authProvider.logout() completed');
                  } catch (e) {
                    debugPrint('🔍 Profile: authProvider.logout() error: $e');
                    // ignore this error, we dont care
                  }
                  await cartProvider.handleUserLogout();
                  debugPrint(
                      '🔍 Profile: cartProvider.handleUserLogout() completed');
                  userProvider.clearUserData();
                  debugPrint(
                      '🔍 Profile: userProvider.clearUserData() completed');
                  logoutSuccess = true;
                  debugPrint('🔍 Profile: Logout successful');
                } catch (e) {
                  debugPrint('🔍 Profile: Logout error: $e');
                  errorMsg = 'Error during logout: ${e.toString()}';
                }
                if (!mounted) return;

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }

                await Future.delayed(Duration(milliseconds: 100));

                if (!mounted) return;

                if (logoutSuccess) {
                  debugPrint('🔍 Profile: Setting userLoggedIn to false');
                  setState(() {
                    _userLoggedIn = false;
                  });

                  if (mounted) {
                    debugPrint('🔍 Profile: Starting navigation delay');
                    await Future.delayed(Duration(milliseconds: 200));
                    if (mounted) {
                      debugPrint('🔍 Profile: Navigating to LoggedOutScreen');
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => LoggedOutScreen()),
                        (route) => false,
                      );
                      debugPrint('🔍 Profile: Navigation completed');
                    } else {
                      debugPrint('🔍 Profile: Widget not mounted after delay');
                    }
                  } else {
                    debugPrint('🔍 Profile: Widget not mounted before delay');
                  }
                } else if (errorMsg != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  // go to login page
  void _handleLogin() {
    Navigator.pushNamed(
      context,
      AppRoutes.signIn,
      arguments: {'returnTo': '/profile'},
    );
  }

  void _showSignInRequiredDialog(BuildContext context, {String? feature}) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade200,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign In Required',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This feature is only for signed up users.\nSign in to upload a prescription, get refillable drugs, and track your order.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(
                              color: Colors.green.shade700, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            AppRoutes.signIn,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shadowColor: Colors.green.shade200,
                        ),
                        child: Text(
                          'Sign In',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = isDark ? Colors.green.shade400 : Colors.green.shade700;
    final backgroundColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F6FB);
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          EclExpandableSliverAppBar(
            toolbarTitle: 'Profile',
            heroTitle: 'Profile',
            heroSubtitle: 'Manage your account and preferences',
            centerTitle: false,
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            },
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CartIconButton(
                    iconColor: Colors.white,
                    iconSize: 22,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),

          // all the profile stuff
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _contentAnimation.value)),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // profile header with name and email - more fluid design
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF334155)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF7FAFF), Color(0xFFEEF6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.14),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.12),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // the profile picture circle - more minimal
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 48,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userLoggedIn ? _userName : "Guest User",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _userLoggedIn
                            ? Text(
                                _userEmail,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                              )
                            : GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.signIn,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          primaryColor.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Sign in to continue",
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  // "Account" section title - more fluid
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      "Your Account",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                  // all the profile menu options
                  _buildEnhancedProfileOption(
                    context,
                    Icons.person_outline,
                    "Profile Information",
                    "View your profile details",
                    _userLoggedIn
                        ? () => _navigateTo(AppRoutes.profileScreen)
                        : () => _showSignInRequiredDialog(context,
                            feature: 'profile information'),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    0,
                  ),
                  Selector<NotificationProvider, Map<String, int>>(
                    selector: (context, provider) => {
                      'unreadCount': provider.unreadCount,
                      'newOrderCount': provider.newOrderCount,
                    },
                    builder: (context, counts, child) {
                      return _buildEnhancedProfileOption(
                        context,
                        Icons.notifications_outlined,
                        "Notifications",
                        "Manage your notifications",
                        _userLoggedIn
                            ? () {
                                // dont mark all as read, let them read notifications themselves
                                _navigateTo(AppRoutes.notifications);
                              }
                            : () => _showSignInRequiredDialog(context,
                                feature: 'notifications'),
                        Colors.orange.shade600,
                        cardColor,
                        textColor,
                        subtextColor,
                        primaryColor,
                        1,
                        badgeCount: counts['unreadCount'],
                        badgeColor: counts['newOrderCount']! > 0
                            ? Colors.blue
                            : Colors.orange,
                      );
                    },
                  ),
                  // wishlist menu option
                  FutureBuilder<int>(
                    future: _wishlistCount != null
                        ? Future.value(_wishlistCount!)
                        : WishlistService.instance
                            .getWishlistCount(useCache: false),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _wishlistCount = snapshot.data;
                      }
                      final wishlistCount =
                          snapshot.data ?? _wishlistCount ?? 0;
                      return _buildEnhancedProfileOption(
                        context,
                        Icons.favorite_outline,
                        "My Wishlist",
                        "View your saved products",
                        () => _navigateTo(AppRoutes.wishlist),
                        primaryColor,
                        cardColor,
                        textColor,
                        subtextColor,
                        primaryColor,
                        1,
                        badgeCount: wishlistCount > 0 ? wishlistCount : null,
                        badgeColor: primaryColor,
                      );
                    },
                  ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.upload_file_outlined,
                    "Uploaded Prescriptions",
                    "View your uploaded prescriptions",
                    _userLoggedIn
                        ? () => _navigateTo(AppRoutes.prescriptionHistory)
                        : () => _showSignInRequiredDialog(context,
                            feature: 'uploaded prescriptions'),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    2,
                  ),
                  // _buildEnhancedProfileOption(
                  //   context,
                  //   Icons.medical_services_outlined,
                  //   "Upload Prescription",
                  //   "Upload your prescription directly",
                  //   () => _navigateTo(AppRoutes.prescriptionUpload),
                  //   Colors.blue.shade700,
                  //   cardColor,
                  //   textColor,
                  //   subtextColor,
                  //   Colors.blue.shade700,
                  //   3,
                  // ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.refresh,
                    "Refill Medicines",
                    "Browse and reorder your refillable medications",
                    _userLoggedIn
                        ? () => _navigateToRefillPage()
                        : () => _showSignInRequiredDialog(context,
                            feature: 'refill medicines'),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    4,
                  ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.shopping_bag_outlined,
                    "Purchases",
                    "View your order history",
                    _userLoggedIn
                        ? () => _navigateTo(AppRoutes.purchases)
                        : () => _showSignInRequiredDialog(context,
                            feature: 'order tracking and purchases'),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    5,
                  ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.account_balance_wallet,
                    "My Wallet",
                    "Manage your wallet and transactions",
                    _userLoggedIn
                        ? () => _navigateTo(AppRoutes.wallet)
                        : () => _showSignInRequiredDialog(context,
                            feature: 'wallet'),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    6,
                  ),
                  const SizedBox(height: 12),
                  // ernest friday option - turned off for now
                  // Consumer<PromotionalEventProvider>(
                  //   builder: (context, promotionalProvider, child) {
                  //     // only show this on fridays
                  //     if (promotionalProvider.isErnestFridayActive) {
                  //       return _buildEnhancedProfileOption(
                  //         context,
                  //         Icons.local_fire_department,
                  //         "Ernest Friday",
                  //         "Slashed prices every Friday",
                  //         () => _navigateTo(const ErnestFridayPage()),
                  //         Colors.orange.shade600,
                  //         cardColor,
                  //         textColor,
                  //         subtextColor,
                  //         5,
                  //       );
                  //     }
                  //     return const SizedBox.shrink();
                  //   },
                  // ),
                  if (!_userLoggedIn)
                    _buildEnhancedProfileOption(
                      context,
                      Icons.login,
                      "Sign In",
                      "Access your account and manage orders",
                      _handleLogin,
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      primaryColor,
                      10,
                    ),

                  const SizedBox(height: 30),

                  // Support Section Header - more fluid
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Text(
                      "Support & Information",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                  // Enhanced Support Options

                  // _buildEnhancedProfileOption(
                  //   context,
                  //   Icons.info_outline,
                  //   "About Us",
                  //   "Learn more about our company",
                  //   () => _navigateTo(AppRoutes.aboutUs),
                  //   primaryColor,
                  //   cardColor,
                  //   textColor,
                  //   subtextColor,
                  //   primaryColor,
                  //   8,
                  // ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.description_outlined,
                    "Terms and Conditions",
                    "Read our terms of service",
                    () => _navigateTo(AppRoutes.termsAndConditions),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    9,
                  ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.privacy_tip_outlined,
                    "Privacy Policy",
                    "Read how we handle your data",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    ),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    10,
                  ),
                  _buildEnhancedProfileOption(
                    context,
                    Icons.assignment_return_outlined,
                    "Return & Refund Policy",
                    "View our return policy",
                    () => _navigateTo(AppRoutes.returnPolicy),
                    primaryColor,
                    cardColor,
                    textColor,
                    subtextColor,
                    primaryColor,
                    11,
                  ),

                  if (_userLoggedIn) ...[
                    const SizedBox(height: 20),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.logout,
                      "Logout",
                      "Sign out from your account",
                      _showLogoutDialog,
                      Colors.red.shade700,
                      cardColor,
                      textColor,
                      subtextColor,
                      primaryColor,
                      12,
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 4),
    );
  }

  Widget _buildEnhancedProfileOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color iconColor,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color primaryColor,
    int index, {
    int? badgeCount,
    Color? badgeColor,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 45)),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.07),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: subtextColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (badgeCount != null && badgeCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor ?? Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: subtextColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
