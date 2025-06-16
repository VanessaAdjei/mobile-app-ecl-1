// pages/profilescreen.dart
import 'package:eclapp/pages/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Cart.dart';
import 'auth_service.dart';
import 'bottomnav.dart';
import 'loggedout.dart';
import 'homepage.dart';
import 'AppBackButton.dart';
import '../widgets/cart_icon_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingUserName = false;
  String _userName = "User";
  String _userEmail = "No email available";
  String _phoneNumber = "";

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _userNameController;
  late TextEditingController _userEmailController;
  late TextEditingController _phoneNumberController;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: _userName);
    _userEmailController = TextEditingController(text: _userEmail);
    _phoneNumberController = TextEditingController(text: _phoneNumber);
    _loadUserData();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _userEmailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<bool> _checkAndRequestGalleryPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.photos.isGranted) {
        return true;
      }

      final status = await Permission.photos.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      return true;
    }
    return false;
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

  Future<void> _pickImage() async {
    final hasPermission = await _checkAndRequestGalleryPermission();

    if (!hasPermission) {
      if (await Permission.photos.isPermanentlyDenied) {
        // Show dialog explaining why permission is needed
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Permission Required"),
            content: Text(
                "We need gallery access to let you choose profile pictures"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: Text("Open Settings"),
              ),
            ],
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    File savedImage =
                        await _saveImageToLocalStorage(File(image.path));
                    setState(() {
                      _profileImage = savedImage;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    File savedImage =
                        await _saveImageToLocalStorage(File(image.path));
                    setState(() {
                      _profileImage = savedImage;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> _saveImageToLocalStorage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final savedImagePath = "${directory.path}/profile_image.png";
    final File savedImage = await imageFile.copy(savedImagePath);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', savedImagePath);
    return savedImage;
  }

  Future<void> _loadProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedImagePath = prefs.getString('profile_image_path');
    if (savedImagePath != null && await File(savedImagePath).exists()) {
      setState(() {
        _profileImage = File(savedImagePath);
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();

      setState(() {
        _userName = userData?['name'] ?? "User";
        _userEmail = userData?['email'] ?? "No email available";
        _phoneNumber = userData?['phone'] ?? "";

        _userNameController.text = _userName;
        _userEmailController.text = _userEmail;
        _phoneNumberController.text = _phoneNumber;
      });
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        _userName = "User";
        _userEmail = "No email available";
        _phoneNumber = "";
      });
    }
  }

  Future<void> _saveUserData() async {
    try {
      await AuthService.saveUserDetails(
        _userNameController.text,
        _userEmail,
        _phoneNumber,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );

      setState(() {
        _userName = _userNameController.text;
        _isEditingUserName = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          backgroundColor: Colors.green.shade700,
          elevation: 0,
          centerTitle: true,
          titleSpacing: 0,
          leading: AppBackButton(
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
          title: const Text(
            'My Profile',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          actions: [
            CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildProfileDetails(),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 30, bottom: 30),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : const AssetImage("assets/images/default_avatar.png")
                            as ImageProvider,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 20, color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              _userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _userEmail,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Personal Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildEditableField(
            icon: Icons.person,
            label: "Full Name",
            controller: _userNameController,
            isEditable: true,
            isEditing: _isEditingUserName,
            onToggleEdit: () {
              setState(() {
                _isEditingUserName = !_isEditingUserName;
                if (!_isEditingUserName) {
                  _saveUserData();
                }
              });
            },
          ),
          const Divider(height: 30),
          _buildInfoField(
            icon: Icons.email,
            label: "Email",
            value: _userEmail,
          ),
          const Divider(height: 30),
          _buildInfoField(
            icon: Icons.phone,
            label: "Phone Number",
            value: _phoneNumber.isEmpty ? "Not provided" : _phoneNumber,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _showLogoutDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Logout",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditable,
    required bool isEditing,
    required VoidCallback onToggleEdit,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green.shade700),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              isEditing
                  ? TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Text(
                      controller.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ],
          ),
        ),
        if (isEditable)
          IconButton(
            icon: Icon(
              isEditing ? Icons.check : Icons.edit,
              color: Colors.green.shade700,
            ),
            onPressed: onToggleEdit,
          ),
      ],
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green.shade700),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
