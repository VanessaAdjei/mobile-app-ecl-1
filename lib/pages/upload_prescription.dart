// pages/upload_prescription.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/product_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_back_button.dart';

import 'signinpage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UploadPrescriptionPage extends StatefulWidget {
  final Product product;

  const UploadPrescriptionPage({
    super.key,
    required this.product,
  });

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isSubmitting = false;

  // Helper method to validate file type
  bool _isValidImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  void _showFileTypeError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Invalid file type',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The file you selected is not supported.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported formats',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'JPG, JPEG or PNG',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please choose a valid image and try again.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool? _cachedLoginStatus;

  Future<bool> _checkLoginStatus() async {
    if (_cachedLoginStatus != null) {
      return _cachedLoginStatus!;
    }

    try {
      String? token;
      try {
        token = await const FlutterSecureStorage().read(key: 'auth_token');
      } on PlatformException catch (e) {
        // Suppress -34018 keychain entitlement errors silently
        if (e.code == '-34018' || e.message?.contains('34018') == true) {
          debugPrint('Keychain access error suppressed in upload_prescription');
          token = null;
        } else {
          rethrow;
        }
      } catch (e) {
        debugPrint('Error reading auth token: $e');
        token = null;
      }
      _cachedLoginStatus = token != null;
      debugPrint('🔍 Token check: ${_cachedLoginStatus! ? 'EXISTS' : 'NULL'}');
      if (_cachedLoginStatus!) {
        debugPrint('🔍 Token length: ${token!.length}');
      }
      return _cachedLoginStatus!;
    } catch (e) {
      debugPrint('🔍 Error checking login status: $e');
      _cachedLoginStatus = false;
      return false;
    }
  }

  void _clearLoginCache() {
    _cachedLoginStatus = null;
  }

  Future<void> _pickImage() async {
    final isLoggedIn = await _checkLoginStatus();
    debugPrint('🔍 Upload: Checking login status - isLoggedIn: $isLoggedIn');

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to upload a prescription'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(),
                  ),
                );
                debugPrint('🔍 Upload: SignInScreen closed');

                _clearLoginCache();
                final isLoggedIn = await _checkLoginStatus();
                debugPrint(
                    '🔍 Upload: After SignInScreen, isLoggedIn: $isLoggedIn');
                if (isLoggedIn && mounted) {
                  debugPrint(
                      '🔍 Upload: User logged in, continuing with image picker');
                  _pickImageAfterLogin();
                }
              },
            ),
          ),
        );
      }
      return;
    }

    debugPrint(
        '🔍 Upload: User already logged in, proceeding with image picker');
    _pickImageAfterLogin();
  }

  Future<void> _pickImageAfterLogin() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024, // Limit image size for better performance
        maxHeight: 1024,
      );

      if (pickedFile != null && mounted) {
        // Validate file type
        if (!_isValidImageFile(pickedFile.path)) {
          if (mounted) {
            _showFileTypeError();
          }
          return;
        }

        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _submitPrescription() async {
    final isLoggedIn = await _checkLoginStatus();
    debugPrint('🔍 Submit: Checking login status - isLoggedIn: $isLoggedIn');

    if (!isLoggedIn) {
      if (mounted) {
        // Show a simple message asking user to log in
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to submit a prescription'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () async {
                debugPrint(
                    '🔍 Submit: Opening SignInScreen without any parameters');
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(),
                  ),
                );
                debugPrint('🔍 Submit: SignInScreen closed');

                // Clear cache and check if user is now logged in
                _clearLoginCache();
                final isLoggedIn = await _checkLoginStatus();
                debugPrint(
                    '🔍 Submit: After SignInScreen, isLoggedIn: $isLoggedIn');
                if (isLoggedIn && mounted) {
                  debugPrint(
                      '🔍 Submit: User logged in, continuing with submission');
                  _submitPrescriptionAfterLogin();
                }
              },
            ),
          ),
        );
      }
      return;
    }

    debugPrint('🔍 Submit: User already logged in, proceeding with submission');
    _submitPrescriptionAfterLogin();
  }

  Future<void> _submitPrescriptionAfterLogin() async {
    if (_image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please upload a prescription first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate API call - reduced delay for better performance
    await Future.delayed(Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Navigate back after successful submission
      Navigator.pop(context);
    }
  }

  static const double _cardRadius = 14;
  static const double _fieldRadius = 12;
  static const Color _accent = Color(0xFF2E7D32);

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: BackButtonUtils.withConfirmation(
          backgroundColor: Colors.grey.shade100,
          title: 'Leave Upload',
          message:
              'Are you sure you want to leave? Your uploaded prescription will be lost.',
        ),
        title: Text(
          'Upload Prescription',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade800),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prescription required notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: _accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This product requires a prescription',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // Product card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Product'),
                  const SizedBox(height: 14),
                  Text(
                    widget.product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'GHS ${widget.product.price}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms),

            const SizedBox(height: 20),

            // Sample prescription reference (shown first so user sees what to upload)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Sample prescription'),
                  const SizedBox(height: 10),
                  Text(
                    'Use a clear photo like this. Include patient name, date, medication, and prescriber signature.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_fieldRadius),
                    child: Image.asset(
                      'assets/images/sample_prescription.png',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 220,
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        alignment: Alignment.center,
                        child: Icon(Icons.image_not_supported_rounded,
                            color: Colors.grey.shade400, size: 48),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 380.ms),

            const SizedBox(height: 20),

            // Upload card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Prescription image'),
                  const SizedBox(height: 16),

                  // Drop zone
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isUploading ? null : _pickImage,
                      borderRadius: BorderRadius.circular(_fieldRadius),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 172,
                        decoration: BoxDecoration(
                          color: _image == null
                              ? Colors.grey.shade50
                              : _accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(_fieldRadius),
                          border: Border.all(
                            color: _image == null
                                ? Colors.grey.shade300
                                : _accent.withValues(alpha: 0.4),
                            width: _image == null ? 1.5 : 2,
                          ),
                        ),
                        child: _image == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 44,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to add prescription photo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'JPG, JPEG or PNG',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  if (_isUploading) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_accent),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(_fieldRadius),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      cacheHeight: 400,
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.3),
                                            Colors.transparent,
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.2),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _accent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickImage,
                          icon: _isUploading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(_accent),
                                  ),
                                )
                              : Icon(Icons.photo_library_rounded, size: 20, color: _accent),
                          label: Text(
                            _image == null ? 'Choose image' : 'Change',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _accent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: BorderSide(color: _accent),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_fieldRadius),
                            ),
                          ),
                        ),
                      ),
                      if (_image != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitPrescription,
                            icon: _isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                            label: Text(
                              'Submit prescription',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(_fieldRadius),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 20),

            // Tips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tips',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTip('Ensure the prescription is clearly visible'),
                  _buildTip('Include doctor\'s signature and date'),
                  _buildTip('Make sure all text is readable'),
                  _buildTip('Use a current, valid prescription'),
                ],
              ),
            ).animate().fadeIn(duration: 450.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
