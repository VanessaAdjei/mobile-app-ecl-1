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
import 'AppBackButton.dart';
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

class ProfileState extends State<Profile> {
  String _userName = "User";
  String _userEmail = "No email available";
  bool _userLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Confirm Logout",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
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
                  borderRadius: BorderRadius.circular(8),
                ),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = isDark ? Colors.green.shade400 : Colors.green.shade700;
    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.1).toInt()),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withAlpha((255 * 0.2).toInt()),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            }
          },
        ),
        title: Text(
          'Your Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((255 * 0.15).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha((255 * 0.3).toInt()),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Avatar
                  Container(
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.2).toInt()),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                      color: Colors.grey[300],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _userLoggedIn ? _userName : "Guest User",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userLoggedIn ? _userEmail : "Please sign in to continue",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withAlpha((255 * 0.9).toInt()),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Account Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    color: primaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Your Account",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Show different options based on login status
            if (_userLoggedIn) ...[
              _buildAnimatedProfileOption(
                context,
                Icons.notifications_outlined,
                "Notifications",
                "Manage your notifications",
                () => _navigateTo(NotificationsScreen()),
                primaryColor,
                cardColor,
                textColor,
                subtextColor,
                0,
              ),
              _buildAnimatedProfileOption(
                context,
                Icons.person_outline,
                "Profile Information",
                "View and edit your profile details",
                () => _navigateTo(ProfileScreen()),
                primaryColor,
                cardColor,
                textColor,
                subtextColor,
                1,
              ),
              _buildAnimatedProfileOption(
                context,
                Icons.upload_file_outlined,
                "Uploaded Prescriptions",
                "View your uploaded prescriptions",
                () => _navigateTo(PrescriptionHistoryScreen()),
                primaryColor,
                cardColor,
                textColor,
                subtextColor,
                2,
              ),
              _buildAnimatedProfileOption(
                context,
                Icons.shopping_bag_outlined,
                "Purchases",
                "View your order history",
                () => _navigateTo(PurchaseScreen()),
                primaryColor,
                cardColor,
                textColor,
                subtextColor,
                3,
              ),
            ] else ...[
              _buildAnimatedProfileOption(
                context,
                Icons.login,
                "Sign In",
                "Access your account and manage orders",
                _handleLogin,
                Colors.blue.shade400,
                cardColor,
                textColor,
                subtextColor,
                0,
              ),
            ],

            const SizedBox(height: 30),

            // Support Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.support_outlined,
                    color: primaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Support & Information",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Support Options
            _buildAnimatedProfileOption(
              context,
              Icons.info_outline,
              "About Us",
              "Learn more about our company",
              () => _navigateTo(AboutUsScreen()),
              primaryColor,
              cardColor,
              textColor,
              subtextColor,
              4,
            ),
            _buildAnimatedProfileOption(
              context,
              Icons.privacy_tip_outlined,
              "Privacy Policy",
              "Read our privacy policy",
              () => _navigateTo(PrivacyPolicyScreen()),
              primaryColor,
              cardColor,
              textColor,
              subtextColor,
              5,
            ),
            _buildAnimatedProfileOption(
              context,
              Icons.description_outlined,
              "Terms and Conditions",
              "Read our terms of service",
              () => _navigateTo(TermsAndConditionsScreen()),
              primaryColor,
              cardColor,
              textColor,
              subtextColor,
              6,
            ),

            if (_userLoggedIn) ...[
              const SizedBox(height: 30),
              _buildAnimatedProfileOption(
                context,
                Icons.logout,
                "Logout",
                "Sign out from your account",
                _showLogoutDialog,
                Colors.red.shade400,
                cardColor,
                textColor,
                subtextColor,
                7,
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        initialIndex: 3,
      ),
    );
  }

  Widget _buildAnimatedProfileOption(
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
      duration: Duration(milliseconds: 400 + (index * 100)),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).toInt()),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha((255 * 0.1).toInt()),
                      shape: BoxShape.circle,
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
                            fontWeight: FontWeight.w500,
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
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: subtextColor,
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
