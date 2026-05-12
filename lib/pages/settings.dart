// pages/settings.dart
import 'dart:io';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/tandc.dart';
import 'package:eclapp/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'aboutus.dart';
import 'loggedout.dart';
import 'notifications.dart';

import 'package:eclapp/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String _userName = "User";
  String _userEmail = "No email available";
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedImagePath = prefs.getString('profile_image_path');
    if (savedImagePath != null && await File(savedImagePath).exists()) {
      setState(() {
        _profileImage = File(savedImagePath);
        _profileImagePath = savedImagePath;
      });
    }
  }

  Future<void> _loadUserData() async {
    final secureStorage = FlutterSecureStorage();
    String name = "User";
    String email = "No email available";

    try {
      name = await secureStorage.read(key: 'userName') ?? "User";
      email =
          await secureStorage.read(key: 'userEmail') ?? "No email available";
    } on PlatformException catch (e) {
      // Suppress -34018 keychain entitlement errors silently
      if (e.code == '-34018' || e.message?.contains('34018') == true) {
        debugPrint('Keychain access error suppressed in settings');
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Error loading user data in settings: $e');
    }

    setState(() {
      _userName = name;
      _userEmail = email;
    });
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Logout",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            "Are you sure you want to logout?",
            style: GoogleFonts.poppins(
              color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
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
                await AuthService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoggedOutScreen()),
                  (route) => false,
                );
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Color scheme
    final primaryColor = isDark ? Colors.green.shade400 : Colors.green.shade700;
    final backgroundColor =
        isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          EclExpandableSliverAppBar(
            toolbarTitle: 'Settings',
            heroTitle: 'Settings',
            heroSubtitle: 'Your account & preferences',
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CartIconButton(
                    iconColor: Colors.white,
                    iconSize: 24,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Profile section
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 16, bottom: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: primaryColor, width: 2),
                                  color: Colors.grey[300],
                                  image: _profileImage != null
                                      ? DecorationImage(
                                          image: FileImage(_profileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_profileImagePath != null &&
                                              File(_profileImagePath!)
                                                  .existsSync()
                                          ? DecorationImage(
                                              image: FileImage(
                                                  File(_profileImagePath!)),
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
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Profile()),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Edit Profile',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Account Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Account Settings",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: _buildSettingsCard(
                context,
                [
                  _buildAnimatedSettingOption(
                      context,
                      "Profile Information",
                      Icons.person_outline,
                      Profile(),
                      textColor,
                      primaryColor,
                      0),
                  const Divider(height: 1),
                  // _buildAnimatedSettingOption(
                  //     context,
                  //     "Change Password",
                  //     Icons.lock_outline,
                  //     ChangePasswordPage(),
                  //     textColor,
                  //     primaryColor,
                  //     1),
                ],
                cardColor,
              ),
            ),
            const SizedBox(height: 16),
            // General Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "General",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: _buildSettingsCard(
                context,
                [
                  _buildAnimatedSettingOption(
                      context,
                      "Notifications",
                      Icons.notifications_outlined,
                      NotificationsScreen(),
                      textColor,
                      primaryColor,
                      0),
                ],
                cardColor,
              ),
            ),
            const SizedBox(height: 16),
            // More Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "More",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: _buildSettingsCard(
                context,
                [
                  _buildAnimatedSettingOption(
                      context,
                      "About Us",
                      Icons.info_outline,
                      AboutUsScreen(),
                      textColor,
                      primaryColor,
                      0),
                  const Divider(height: 1),
                  _buildAnimatedSettingOption(
                      context,
                      "Privacy Statement",
                      Icons.privacy_tip_outlined,
                      PrivacyPolicyScreen(),
                      textColor,
                      primaryColor,
                      1),
                  const Divider(height: 1),
                  _buildAnimatedSettingOption(
                      context,
                      "Terms and Conditions",
                      Icons.description_outlined,
                      TermsAndConditionsScreen(),
                      textColor,
                      primaryColor,
                      2),
                ],
                cardColor,
              ),
            ),
            const SizedBox(height: 24),
            // Logout Button
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(
                    duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    "Logout",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, List<Widget> children, Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildAnimatedSettingOption(
    BuildContext context,
    String text,
    IconData icon,
    Widget destination,
    Color textColor,
    Color iconColor,
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
      child: _buildSettingOption(
        context,
        text,
        icon,
        destination,
        textColor,
        iconColor,
      ),
    );
  }

  Widget _buildSettingOption(
    BuildContext context,
    String text,
    IconData icon,
    Widget destination,
    Color textColor,
    Color iconColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
