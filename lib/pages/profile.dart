// pages/profile.dart

import 'dart:io';
import 'package:eclapp/pages/aboutus.dart';
import 'package:eclapp/pages/loggedout.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/pages/profilescreen.dart';
import 'package:eclapp/pages/purchases.dart';
import 'package:eclapp/pages/settings.dart';
import 'package:eclapp/pages/tandc.dart';
import 'package:eclapp/pages/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eclapp/pages/cart.dart';
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

class Profile extends StatefulWidget {
  const Profile({
    Key? key,
  }) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  String _userName = "User";
  String _userEmail = "No email available";
  String? _profileImagePath;
  bool _userLoggedIn =
      false; // This will be updated based on actual login status

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  // Combined initialization method
  Future<void> _initializeUserData() async {
    try {
      print('Initializing profile data...');

      // First check login status
      final loggedIn = await AuthService.isLoggedIn();
      print('Login status: $loggedIn');

      setState(() {
        _userLoggedIn = loggedIn;
      });

      if (loggedIn) {
        print('User is logged in, loading user data...');
        await _loadUserData();
      } else {
        print('User is not logged in');
      }

      // Load profile image regardless of login status
      print('Loading profile image...');
      await _loadProfileImage();

      print('Profile initialization complete');
    } catch (e) {
      print('Error initializing profile: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('Loading user data...');
      final secureStorage = FlutterSecureStorage();

      final name = await secureStorage.read(key: 'userName');
      final email = await secureStorage.read(key: 'userEmail');

      print('Loaded user data - Name: $name, Email: $email');

      if (mounted) {
        setState(() {
          _userName = name ?? "User";
          _userEmail = email ?? "No email available";
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = "User";
          _userEmail = "Error loading data";
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      print('Loading profile image...');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedImagePath = prefs.getString('profile_image_path');

      if (savedImagePath != null) {
        print('Found saved image path: $savedImagePath');
        final file = File(savedImagePath);
        if (await file.exists()) {
          print('Image file exists, loading...');
          if (mounted) {
            setState(() {
              _profileImage = file;
              _profileImagePath = savedImagePath;
            });
          }
        } else {
          print('Image file does not exist');
        }
      } else {
        print('No saved image path found');
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _pickImage() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        File savedImage = await _saveImageToLocalStorage(File(image.path));
        setState(() {
          _profileImage = savedImage;
          _profileImagePath = savedImage.path;
        });
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<File> _saveImageToLocalStorage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final savedImagePath = "${directory.path}/profile_image.png";
    final File savedImage = await imageFile.copy(savedImagePath);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', savedImagePath);
    return savedImage;
  }

  void _showLogoutDialog() {
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
                try {
                  // First logout from the service
                  await AuthService.logout();

                  // Then clear all providers
                  if (mounted) {
                    await Provider.of<CartProvider>(context, listen: false)
                        .handleUserLogout();
                    Provider.of<UserProvider>(context, listen: false)
                        .clearUserData();

                    // Update local state
                    setState(() {
                      _userLoggedIn = false;
                    });

                    // Close the dialog
                    Navigator.of(context, rootNavigator: true).pop();

                    // Navigate to logged out screen
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => LoggedOutScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  print('Error during logout: $e');
                  // Show error in the current context before closing dialog
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error during logout: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
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

  // Handle navigation with login check
  void _navigateWithLoginCheck(Widget screen) {
    if (_userLoggedIn) {
      _navigateTo(screen);
    } else {
      // Show dialog or directly redirect to sign-in
      _showLoginRequiredDialog();
    }
  }

  // Show dialog informing user they need to login
  void _showLoginRequiredDialog() {
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
            "Login Required",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            "You need to sign in to access this feature. Would you like to sign in now?",
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
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(
                      returnTo: '/profile',
                      onSuccess: () {
                        // Refresh the profile page after successful login
                        setState(() {
                          _userLoggedIn = true;
                        });
                        _loadUserData();
                      },
                    ),
                  ),
                );
              },
              child: Text(
                "Sign In",
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Color scheme
    final primaryColor = isDark ? Colors.green.shade400 : Colors.green.shade700;
    final backgroundColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
          ),
        ),
        actions: [
          CartIconButton(
            iconColor: Colors.white,
            iconSize: 24,
            backgroundColor: Colors.transparent,
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
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Profile Image
                      GestureDetector(
                        onTap: _userLoggedIn ? _pickImage : null,
                        child: Container(
                          height: 130,
                          width: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                            color: Colors.grey[300],
                            image: _userLoggedIn && _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_userLoggedIn &&
                                        _profileImagePath != null &&
                                        File(_profileImagePath!).existsSync()
                                    ? DecorationImage(
                                        image:
                                            FileImage(File(_profileImagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : const DecorationImage(
                                        image: AssetImage(
                                            "assets/images/default_avatar.png"),
                                        fit: BoxFit.cover,
                                      )),
                          ),
                        ),
                      ),
                      if (_userLoggedIn)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
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
                      color: Colors.white.withOpacity(0.9),
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
              color: Colors.black.withOpacity(0.05),
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
                      color: iconColor.withOpacity(0.1),
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
