// pages/profile.dart

import 'package:eclapp/pages/aboutus.dart';
import 'package:eclapp/pages/loggedout.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/pages/profilescreen.dart';
import 'package:eclapp/pages/purchases.dart';
import 'package:eclapp/pages/tandc.dart';
import 'package:eclapp/pages/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'bottomnav.dart';
import 'notifications.dart';
import 'HomePage.dart';
import 'app_back_button.dart';
import 'cartprovider.dart';
import '../main.dart';
import 'package:eclapp/pages/prescription_history.dart';
import 'package:eclapp/pages/signinpage.dart';
import '../widgets/cart_icon_button.dart';
import 'authprovider.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<Profile> with TickerProviderStateMixin {
  String _userName = "User";
  String _userEmail = "No email available";
  bool _userLoggedIn = false;
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
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
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _headerAnimationController.forward();
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
      final secureStorage = FlutterSecureStorage();
      final name = await secureStorage.read(key: 'userName');
      final email = await secureStorage.read(key: 'userEmail');
      if (!mounted) return;
      setState(() {
        _userName = name ?? "User";
        _userEmail = email ?? "No email available";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = "User";
        _userEmail = "Error loading data";
      });
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showLogoutDialog() {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
              onPressed: () => Navigator.pop(context),
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
                // Get providers before any await
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                bool logoutSuccess = false;
                String? errorMsg;
                try {
                  await AuthService.logout();
                  try {
                    await authProvider.logout();
                  } catch (e) {
                    // ignore: empty_catches
                  }
                  await cartProvider.handleUserLogout();
                  userProvider.clearUserData();
                  logoutSuccess = true;
                } catch (e) {
                  errorMsg = 'Error during logout: ${e.toString()}';
                }
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                if (logoutSuccess) {
                  setState(() {
                    _userLoggedIn = false;
                  });
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoggedOutScreen()),
                    (route) => false,
                  );
                } else if (errorMsg != null) {
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

  // Handle login navigation
  void _handleLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignInScreen(
          returnTo: '/profile',
        ),
      ),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignInScreen(
                                onSuccess: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
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
    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // Switch to Home tab instead of closing app
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: CustomScrollView(
          slivers: [
            // Enhanced App Bar
            SliverAppBar(
              expandedHeight: 60,
              floating: false,
              pinned: true,
              backgroundColor: Colors.green.shade700,
              elevation: 4,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                    ),
                  ),
                ),
                title: Text(
                  'Your Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                centerTitle: true,
              ),
              leading: AppBackButton(
                backgroundColor: Colors.white.withAlpha((255 * 0.2).toInt()),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    );
                  }
                },
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: CartIconButton(
                    iconColor: Colors.white,
                    iconSize: 22,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),

            // Profile Content
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
                    // Enhanced Profile Header
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.8),
                            primaryColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withAlpha((255 * 0.3).toInt()),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Enhanced Profile Avatar
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withAlpha((255 * 0.3).toInt()),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.grey.shade100,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _userLoggedIn ? _userName : "Guest User",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withAlpha((255 * 0.2).toInt()),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _userLoggedIn
                                  ? _userEmail
                                  : "Please sign in to continue",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // Account Section Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  primaryColor.withAlpha((255 * 0.1).toInt()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_circle_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Your Account",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Enhanced Profile Options
                    _buildEnhancedProfileOption(
                      context,
                      Icons.notifications_outlined,
                      "Notifications",
                      "Manage your notifications",
                      _userLoggedIn
                          ? () => _navigateTo(NotificationsScreen())
                          : () => _showSignInRequiredDialog(context,
                              feature: 'notifications'),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      0,
                    ),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.person_outline,
                      "Profile Information",
                      "View your profile details",
                      _userLoggedIn
                          ? () => _navigateTo(ProfileScreen())
                          : () => _showSignInRequiredDialog(context,
                              feature: 'profile information'),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      1,
                    ),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.upload_file_outlined,
                      "Uploaded Prescriptions",
                      "View your uploaded prescriptions",
                      _userLoggedIn
                          ? () => _navigateTo(PrescriptionHistoryScreen())
                          : () => _showSignInRequiredDialog(context,
                              feature: 'uploaded prescriptions'),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      2,
                    ),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.shopping_bag_outlined,
                      "Purchases",
                      "View your order history",
                      _userLoggedIn
                          ? () => _navigateTo(PurchaseScreen())
                          : () => _showSignInRequiredDialog(context,
                              feature: 'order tracking and purchases'),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      3,
                    ),
                    if (!_userLoggedIn)
                      _buildEnhancedProfileOption(
                        context,
                        Icons.login,
                        "Sign In",
                        "Access your account and manage orders",
                        _handleLogin,
                        Colors.blue.shade400,
                        cardColor,
                        textColor,
                        subtextColor,
                        4,
                      ),

                    const SizedBox(height: 30),

                    // Support Section Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  primaryColor.withAlpha((255 * 0.1).toInt()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.support_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Support & Information",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Enhanced Support Options
                    _buildEnhancedProfileOption(
                      context,
                      Icons.info_outline,
                      "About Us",
                      "Learn more about our company",
                      () => _navigateTo(AboutUsScreen()),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      5,
                    ),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.privacy_tip_outlined,
                      "Privacy Policy",
                      "Read our privacy policy",
                      () => _navigateTo(PrivacyPolicyScreen()),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      6,
                    ),
                    _buildEnhancedProfileOption(
                      context,
                      Icons.description_outlined,
                      "Terms and Conditions",
                      "Read our terms of service",
                      () => _navigateTo(TermsAndConditionsScreen()),
                      primaryColor,
                      cardColor,
                      textColor,
                      subtextColor,
                      7,
                    ),

                    if (_userLoggedIn) ...[
                      const SizedBox(height: 20),
                      _buildEnhancedProfileOption(
                        context,
                        Icons.logout,
                        "Logout",
                        "Sign out from your account",
                        _showLogoutDialog,
                        Colors.red.shade400,
                        cardColor,
                        textColor,
                        subtextColor,
                        8,
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(initialIndex: 3),
      ),
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
    int index,
  ) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 150)),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.08).toInt()),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withAlpha((255 * 0.15).toInt()),
                          iconColor.withAlpha((255 * 0.25).toInt()),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withAlpha((255 * 0.2).toInt()),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: subtextColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: subtextColor.withAlpha((255 * 0.1).toInt()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: subtextColor,
                    ),
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
