// pages/prescription_upload_standalone.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import 'signinpage.dart';

class PrescriptionUploadStandalone extends StatefulWidget {
  const PrescriptionUploadStandalone({super.key});

  @override
  State<PrescriptionUploadStandalone> createState() =>
      _PrescriptionUploadStandaloneState();
}

class _PrescriptionUploadStandaloneState
    extends State<PrescriptionUploadStandalone> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkLoginStatus();
  }

  File? _prescriptionImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isLoggedIn = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedDeliveryOption = 'delivery';
  String _selectedCountryCode = '+233';

  // Pickup location variables
  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> stores = [];
  Map<String, dynamic>? selectedRegion;
  Map<String, dynamic>? selectedCity;
  Map<String, dynamic>? selectedPickupSite;
  bool isLoadingRegions = false;
  bool isLoadingCities = false;
  bool isLoadingStores = false;

  // Cache for cities and stores
  final Map<int, List<Map<String, dynamic>>> _citiesCache = {};
  final Map<int, List<Map<String, dynamic>>> _storesCache = {};

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadRegions();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
    });

    if (!isLoggedIn) {
      // Show dialog and redirect to sign in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginRequiredDialog();
      });
    } else {
      // Fetch and populate user details
      _loadUserDetails();
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData != null && mounted) {
        setState(() {
          if (userData['name'] != null &&
              userData['name'].toString().isNotEmpty) {
            _nameController.text = userData['name'].toString();
          }
          if (userData['email'] != null &&
              userData['email'].toString().isNotEmpty) {
            _emailController.text = userData['email'].toString();
          }
          if (userData['phone'] != null &&
              userData['phone'].toString().isNotEmpty) {
            String phone = userData['phone'].toString();
            // Remove country code if present
            if (phone.startsWith('+233')) {
              phone = phone.substring(4);
            } else if (phone.startsWith('233')) {
              phone = phone.substring(3);
            } else if (phone.startsWith('0')) {
              phone = phone.substring(1);
            }
            _phoneController.text = phone;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user details: $e');
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Login Required',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need to be logged in to upload a prescription. Please sign in to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(
                      onSuccess: () {
                        // After successful login, navigate back to prescription upload
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PrescriptionUploadStandalone(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPrescriptionImage() async {
    if (!_isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _prescriptionImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPrescription() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _prescriptionImage == null) {
      _showErrorDialog(
        'Missing Information',
        'Please fill in all required fields and upload your prescription image.',
      );
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showErrorDialog(
        'Invalid Email',
        'Please enter a valid email address.',
      );
      return;
    }

    // Validate phone number
    if (_phoneController.text.trim().length < 9) {
      _showErrorDialog(
        'Invalid Phone Number',
        'Please enter a valid phone number.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Check file size (5MB limit)
      final fileSize = await _prescriptionImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showErrorDialog(
          'File Too Large',
          'Image size must be less than 5MB. Please compress or choose a smaller image.',
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final userId = await AuthService.getCurrentUserID();
      final token = await AuthService.getBearerToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/create-precription'),
      );

      // Add Authorization header if available
      if (token != null) {
        request.headers['Authorization'] = token;
      }
      // Debug print the Authorization header
      print('=== /create-precription REQUEST HEADERS ===');
      print(request.headers);
      print('=== /create-precription TOKEN ===');
      print(token);

      // Add form fields
      request.fields['name'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['phone'] =
          '$_selectedCountryCode${_phoneController.text.trim()}';
      request.fields['delivery_option'] = _selectedDeliveryOption;
      request.fields['note'] = _noteController.text.trim();
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      // Add prescription image
      try {
        request.files.add(
          await http.MultipartFile.fromPath(
            'prescription',
            _prescriptionImage!.path,
          ),
        );
      } catch (e) {
        _showErrorDialog(
          'Image Error',
          'Failed to process the image. Please try selecting a different image.',
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      final responseData = await response.stream.bytesToString();
      // Print the raw API response to the terminal for debugging
      // ignore: avoid_print
      print('API /create-prescription response:');
      print(responseData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else if (response.statusCode == 401) {
        _showErrorDialog(
          'Authentication Error',
          'Your session has expired. Please log in again.',
        );
      } else if (response.statusCode == 413) {
        _showErrorDialog(
          'File Too Large',
          'The uploaded file is too large. Please choose a smaller image.',
        );
      } else if (response.statusCode == 422) {
        _showErrorDialog(
          'Invalid Data',
          'Please check your information and try again.',
        );
      } else if (response.statusCode >= 500) {
        _showErrorDialog(
          'Server Error',
          'Our server is experiencing issues. Please try again later.',
        );
      } else {
        String errorMessage = 'Failed to upload prescription';
        try {
          final jsonResponse = json.decode(responseData);
          if (jsonResponse['message'] != null) {
            errorMessage = jsonResponse['message'];
          }
        } catch (_) {
          // Use default error message
        }
        _showErrorDialog('Upload Failed', errorMessage);
      }
    } on SocketException {
      _showErrorDialog(
        'No Internet Connection',
        'Please check your internet connection and try again.',
      );
    } on TimeoutException {
      _showErrorDialog(
        'Request Timeout',
        'The request took too long. Please check your connection and try again.',
      );
    } on FormatException {
      _showErrorDialog(
        'Invalid Response',
        'Received an invalid response from the server. Please try again.',
      );
    } catch (e) {
      debugPrint('Prescription upload error: $e');
      _showErrorDialog(
        'Upload Error',
        'An unexpected error occurred. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Success!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your prescription has been uploaded successfully. We\'ll review it and contact you soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Clear form
                _nameController.clear();
                _emailController.clear();
                _phoneController.clear();
                _noteController.clear();
                setState(() {
                  _prescriptionImage = null;
                });
              },
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Color(0xFF4CAF50),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Upload Prescription',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section with icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Easy Prescription Upload',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload and we\'ll handle the rest',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Form section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upload Prescription - First to make it primary
                  _buildUploadSection(
                    title: 'Upload Prescription',
                    isOptional: false,
                    image: _prescriptionImage,
                    onTap: _pickPrescriptionImage,
                  ),
                  const SizedBox(height: 20),

                  // Full name
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Full name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 15),

                  // Email
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),

                  // Phone with country code
                  _buildPhoneField(),
                  const SizedBox(height: 20),

                  // Pick up or Delivery
                  _buildDropdown(),
                  const SizedBox(height: 20),

                  // Note
                  _buildNoteField(),
                  const SizedBox(height: 30),

                  // Submit button
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4CAF50).withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPrescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Submit Prescription',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Bottom info section
            _buildBottomInfo(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: Color(0xFF4CAF50), size: 22),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountryCode,
              items: [
                DropdownMenuItem(
                  value: '+233',
                  child: Row(
                    children: [
                      Image.network(
                        'https://flagcdn.com/w20/gh.png',
                        width: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.flag, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text('+233'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: '+1',
                  child: Row(
                    children: [
                      Image.network(
                        'https://flagcdn.com/w20/us.png',
                        width: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.flag, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text('+1'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: '+44',
                  child: Row(
                    children: [
                      Image.network(
                        'https://flagcdn.com/w20/gb.png',
                        width: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.flag, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text('+44'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCountryCode = value!;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Phone',
              hintStyle: TextStyle(fontSize: 15),
              prefixIcon: Icon(Icons.phone_outlined,
                  color: Color(0xFF4CAF50), size: 22),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection({
    required String title,
    required bool isOptional,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (isOptional)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: image == null ? Colors.grey.shade50 : Colors.transparent,
                border: Border.all(
                  color:
                      image == null ? Colors.grey.shade200 : Color(0xFF4CAF50),
                  width: image == null ? 2 : 3,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: image != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF4CAF50).withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4CAF50).withOpacity(0.1),
                                  Color(0xFF66BB6A).withOpacity(0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap to upload image',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'JPG, PNG (Max 5MB)',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Method',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeliveryOption,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF4CAF50)),
              style: TextStyle(fontSize: 15, color: Colors.black87),
              items: const [
                DropdownMenuItem(
                  value: 'delivery',
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 20, color: Color(0xFF4CAF50)),
                      SizedBox(width: 12),
                      Text('Delivery'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'pickup',
                  child: Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 20, color: Color(0xFF4CAF50)),
                      SizedBox(width: 12),
                      Text('Pick up'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDeliveryOption = value!;
                  // Reset pickup selections when switching to delivery
                  if (value == 'delivery') {
                    selectedRegion = null;
                    selectedCity = null;
                    selectedPickupSite = null;
                  }
                });
              },
            ),
          ),
        ),

        // Show branches when pickup is selected
        if (_selectedDeliveryOption == 'pickup') ...[
          const SizedBox(height: 16),
          // Region dropdown
          const Text(
            'Select Region',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoadingRegions
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: selectedRegion,
                      isExpanded: true,
                      hint: const Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 20, color: Color(0xFF4CAF50)),
                          SizedBox(width: 12),
                          Text('Choose a region'),
                        ],
                      ),
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: Color(0xFF4CAF50)),
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                      items: regions.map((region) {
                        return DropdownMenuItem(
                          value: region,
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 20, color: Color(0xFF4CAF50)),
                              SizedBox(width: 12),
                              Text(
                                region['description'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedRegion = value;
                          selectedCity = null;
                          selectedPickupSite = null;
                        });
                        if (value != null) {
                          _loadCities(value['id']);
                        }
                      },
                    ),
                  ),
          ),

          // City dropdown
          if (selectedRegion != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Select City',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoadingCities
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: selectedCity,
                        isExpanded: true,
                        hint: const Row(
                          children: [
                            Icon(Icons.location_city_outlined,
                                size: 20, color: Color(0xFF4CAF50)),
                            SizedBox(width: 12),
                            Text('Choose a city'),
                          ],
                        ),
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF4CAF50)),
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                        items: cities.map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Row(
                              children: [
                                Icon(Icons.location_city_outlined,
                                    size: 20, color: Color(0xFF4CAF50)),
                                SizedBox(width: 12),
                                Text(
                                  city['description'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCity = value;
                            selectedPickupSite = null;
                          });
                          if (value != null) {
                            _loadStores(value['id']);
                          }
                        },
                      ),
                    ),
            ),
          ],

          // Store/Branch dropdown
          if (selectedCity != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Select Pickup Branch',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoadingStores
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: selectedPickupSite,
                        isExpanded: true,
                        hint: const Row(
                          children: [
                            Icon(Icons.store_outlined,
                                size: 20, color: Color(0xFF4CAF50)),
                            SizedBox(width: 12),
                            Text('Choose a branch'),
                          ],
                        ),
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF4CAF50)),
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                        items: stores.map((store) {
                          return DropdownMenuItem(
                            value: store,
                            child: Row(
                              children: [
                                Icon(Icons.store_outlined,
                                    size: 20, color: Color(0xFF4CAF50)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    store['description'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPickupSite = value;
                          });
                        },
                      ),
                    ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 4,
          style: TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Any special instructions or requirements...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            contentPadding: EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'How it works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoItem(
            Icons.upload_file_rounded,
            'Upload',
            'Upload your prescription image',
            '1',
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            Icons.verified_outlined,
            'Verify',
            'Our pharmacist reviews it',
            '2',
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            Icons.local_shipping_outlined,
            'Deliver',
            'Get it delivered or pick it up',
            '3',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String title, String description, String step) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(icon, size: 22, color: Color(0xFF4CAF50)),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Load regions for pickup
  Future<void> _loadRegions() async {
    if (!mounted) return;
    setState(() {
      isLoadingRegions = true;
    });

    try {
      final result = await DeliveryService.getRegions()
          .timeout(const Duration(seconds: 5));
      if (result['success'] && mounted) {
        try {
          setState(() {
            final rawRegions = List<Map<String, dynamic>>.from(result['data']);
            final uniqueRegions = <String, Map<String, dynamic>>{};

            for (final region in rawRegions) {
              try {
                final description = region['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueRegions.containsKey(description)) {
                  uniqueRegions[description] = region;
                }
              } catch (e) {
                debugPrint('⚠️ Error processing region: $e');
                continue;
              }
            }

            final allRegions = uniqueRegions.values.toList();

            // Filter to only show Greater Accra, Ashanti, and Western regions
            final allowedRegionNames = [
              'greater accra',
              'ashanti',
              'western',
              'accra',
            ];

            final filteredRegions = allRegions.where((region) {
              final regionName =
                  (region['description'] ?? '').toString().toLowerCase().trim();
              return allowedRegionNames
                  .any((allowed) => regionName.contains(allowed));
            }).toList();

            regions = filteredRegions;
            isLoadingRegions = false;
          });
        } catch (e) {
          debugPrint('❌ Error setting regions state: $e');
          setState(() {
            regions = [];
            isLoadingRegions = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          isLoadingRegions = false;
        });
        debugPrint('Failed to load regions: ${result['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingRegions = false;
      });
      debugPrint('Error loading regions: $e');
    }
  }

  /// Load cities for selected region
  Future<void> _loadCities(int regionId) async {
    // Check cache first
    if (_citiesCache.containsKey(regionId)) {
      if (!mounted) return;
      setState(() {
        cities = _citiesCache[regionId]!;
        selectedCity = null;
        selectedPickupSite = null;
        stores = [];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      isLoadingCities = true;
      cities = [];
      stores = [];
      selectedCity = null;
      selectedPickupSite = null;
    });

    try {
      final result = await DeliveryService.getCitiesByRegion(regionId)
          .timeout(const Duration(seconds: 3));
      if (result['success'] && mounted) {
        final citiesData = List<Map<String, dynamic>>.from(result['data']);
        if (!mounted) return;
        try {
          setState(() {
            final uniqueCities = <String, Map<String, dynamic>>{};

            for (final city in citiesData) {
              try {
                final description = city['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueCities.containsKey(description)) {
                  uniqueCities[description] = city;
                }
              } catch (e) {
                debugPrint('⚠️ Error processing city: $e');
                continue;
              }
            }

            cities = uniqueCities.values.toList();
            _citiesCache[regionId] = uniqueCities.values.toList();
            isLoadingCities = false;
          });
        } catch (e) {
          debugPrint('❌ Error setting cities state: $e');
          setState(() {
            cities = [];
            isLoadingCities = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          isLoadingCities = false;
        });
        debugPrint('Failed to load cities: ${result['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingCities = false;
      });
      debugPrint('Error loading cities: $e');
    }
  }

  /// Load stores for selected city
  Future<void> _loadStores(int cityId) async {
    // Check cache first
    if (_storesCache.containsKey(cityId)) {
      if (!mounted) return;
      setState(() {
        stores = _storesCache[cityId]!;
        selectedPickupSite = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      isLoadingStores = true;
      stores = [];
      selectedPickupSite = null;
    });

    try {
      final result = await DeliveryService.getStoresByCity(cityId)
          .timeout(const Duration(seconds: 3));
      if (result['success'] && mounted) {
        final storesData = List<Map<String, dynamic>>.from(result['data']);
        if (!mounted) return;
        try {
          setState(() {
            final uniqueStores = <String, Map<String, dynamic>>{};

            for (final store in storesData) {
              try {
                final description = store['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueStores.containsKey(description)) {
                  uniqueStores[description] = store;
                }
              } catch (e) {
                debugPrint('⚠️ Error processing store: $e');
                continue;
              }
            }

            stores = uniqueStores.values.toList();
            _storesCache[cityId] = uniqueStores.values.toList();
            isLoadingStores = false;
          });
        } catch (e) {
          debugPrint('❌ Error setting stores state: $e');
          setState(() {
            stores = [];
            isLoadingStores = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          isLoadingStores = false;
        });
        debugPrint('Failed to load stores: ${result['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingStores = false;
      });
      debugPrint('Error loading stores: $e');
    }
  }
}
