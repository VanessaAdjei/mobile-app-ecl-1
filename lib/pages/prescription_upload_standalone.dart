// pages/prescription_upload_standalone.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/prescription_service.dart';
import '../services/auth_service.dart';
import '../pages/app_back_button.dart';
import '../pages/prescription_history.dart';
import '../utils/app_error_utils.dart';
import '../utils/prescription_image_picker.dart';

class PrescriptionUploadStandalone extends StatefulWidget {
  const PrescriptionUploadStandalone({super.key});

  @override
  State<PrescriptionUploadStandalone> createState() =>
      _PrescriptionUploadStandaloneState();
}

class _PrescriptionUploadStandaloneState
    extends State<PrescriptionUploadStandalone> {
  bool _authChecked = false;

  bool _isValidImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  bool _isValidImageSize(File file) {
    return file.lengthSync() <= 10 * 1024 * 1024;
  }

  Future<bool> _assignImageFile({
    required String path,
    required void Function(File file) onAccepted,
    required String label,
  }) async {
    if (!_isValidImageFile(path)) {
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          '$label must be a JPG or PNG image.',
        );
      }
      return false;
    }
    final file = File(path);
    if (!_isValidImageSize(file)) {
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          '$label exceeds 10MB. Choose a smaller image.',
        );
      }
      return false;
    }
    onAccepted(file);
    return true;
  }

  void _openSamplePrescriptionPreview(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sample Prescription',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.asset(
                    'assets/images/sample_prescription.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: 430,
                    errorBuilder: (_, __, ___) => Container(
                      height: 280,
                      color: isDark
                          ? const Color(0xFF0B1220)
                          : const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF20AF67).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Icon(Icons.lock_outline,
                      color: Color(0xFF20AF67), size: 38),
                ),
                const SizedBox(height: 22),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You must sign in to upload a prescription. Please sign in to continue.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20AF67),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop('signin');
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF20AF67), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop('home');
                    },
                    child: const Text(
                      'Go Back Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF20AF67),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;

      if (action == 'signin') {
        await Navigator.of(context).pushNamed(
          AppRoutes.signIn,
          arguments: {'returnTo': AppRoutes.prescriptionUpload},
        );
        if (!mounted) return;
        if (!await AuthService.isLoggedIn()) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          return;
        }
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        return;
      }
    }

    if (mounted) {
      setState(() => _authChecked = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData != null) {
        if (mounted) {
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _emailController.text = userData['email'] ?? '';
            _phoneController.text = userData['phone'] ?? '';
          });
        }
      }
    } catch (e) {
      // Optionally handle error
    }
  }

  File? _selectedImage;
  File? _brandImage;
  final PrescriptionService _prescriptionService = PrescriptionService();
  bool _isSubmitting = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedCountryCode = '+233';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _chooseFromGallery() async {
    try {
      final pickedFile = await PrescriptionImagePicker.pickFromGallery();
      if (pickedFile == null || !mounted) return;
      final accepted = await _assignImageFile(
        path: pickedFile.path,
        label: 'Prescription image',
        onAccepted: (file) => setState(() => _selectedImage = file),
      );
      if (accepted && mounted) {
        AppErrorUtils.showSnack(
          context,
          'Prescription image added.',
          isError: false,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Error selecting image: $e');
      if (!mounted) return;
      final message = switch (e.code) {
        'photo_access_denied' =>
          'Allow photo access in Settings to choose an image.',
        'gallery_pick_failed' =>
          e.message ?? 'Could not read that image. Try Camera instead.',
        _ => 'Failed to add prescription image.',
      };
      AppErrorUtils.showSnack(context, message);
    } catch (e) {
      debugPrint('Error selecting image: $e');
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Failed to add prescription image.');
      }
    }
  }

  void _scanPrescription() async {
    if (!mounted) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20AF67).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scan tips',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tips List
              Column(
                children: [
                  _buildTipItem(
                    icon: Icons.light_mode,
                    title: 'Good lighting',
                    description: 'Use natural light or bright area',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.crop_free,
                    title: 'Keep flat',
                    description: 'Place document on even surface',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.block,
                    title: 'No shadows',
                    description: 'Avoid glare and reflections',
                  ),
                  const SizedBox(height: 10),
                  _buildTipItem(
                    icon: Icons.format_color_text,
                    title: 'All text visible',
                    description: 'Include complete prescription text',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20AF67),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Open Camera',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldOpen == true && mounted) {
      await _pickFromCamera();
    }
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF20AF67)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final pickedFile = await PrescriptionImagePicker.pickFromCamera();
      if (pickedFile == null || !mounted) return;
      final accepted = await _assignImageFile(
        path: pickedFile.path,
        label: 'Prescription image',
        onAccepted: (file) => setState(() => _selectedImage = file),
      );
      if (accepted && mounted) {
        AppErrorUtils.showSnack(
          context,
          'Prescription image added.',
          isError: false,
        );
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Failed to capture prescription image.');
      }
    }
  }

  Future<void> _pickBrandImageFromGallery() async {
    try {
      final pickedFile = await PrescriptionImagePicker.pickFromGallery();
      if (pickedFile == null || !mounted) return;
      await _assignImageFile(
        path: pickedFile.path,
        label: 'Brand photo',
        onAccepted: (file) => setState(() => _brandImage = file),
      );
    } catch (e) {
      debugPrint('Error selecting brand image: $e');
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Failed to add brand photo.');
      }
    }
  }

  Future<void> _pickBrandImageFromCamera() async {
    try {
      final pickedFile = await PrescriptionImagePicker.pickFromCamera();
      if (pickedFile == null || !mounted) return;
      await _assignImageFile(
        path: pickedFile.path,
        label: 'Brand photo',
        onAccepted: (file) => setState(() => _brandImage = file),
      );
    } catch (e) {
      debugPrint('Error capturing brand image: $e');
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Failed to capture brand photo.');
      }
    }
  }

  Future<void> _openBrandImagePicker(bool isDark) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20AF67).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Color(0xFF20AF67),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Brand or medicine photo',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Photo of the pack, bottle, or label you prefer (optional)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SheetActionTile(
                    icon: Icons.photo_library_outlined,
                    title: 'From Gallery',
                    subtitle: 'Select a product photo from your phone',
                    isDark: isDark,
                    onTap: () => Navigator.pop(ctx, 'gallery'),
                  ),
                  const SizedBox(height: 10),
                  _SheetActionTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Take a photo',
                    subtitle: 'Capture the brand or packaging now',
                    isDark: isDark,
                    isPrimary: true,
                    onTap: () => Navigator.pop(ctx, 'camera'),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (option == 'gallery') await _pickBrandImageFromGallery();
    if (option == 'camera') await _pickBrandImageFromCamera();
  }

  String _prescriptionResponseErrorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) {
            parts.add(v.first.toString());
          } else if (v != null) {
            parts.add(v.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
      final message = body['message'] ?? body['error'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }
    return 'Failed to submit prescription ($statusCode)';
  }

  void _logPrescriptionApiToConsole(String label, dynamic payload) {
    String body;
    try {
      body = const JsonEncoder.withIndent('  ').convert(payload);
    } catch (_) {
      body = payload.toString();
    }
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📤 PRESCRIPTION API: $label');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint(body);
    debugPrint('═══════════════════════════════════════════════════════');
  }

  Future<void> _submitPrescription() async {
    if (_selectedImage == null) return;

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      AppErrorUtils.showSnack(context, 'Please fill in all required fields');
      return;
    }

    if (!await AuthService.isLoggedIn()) {
      AppErrorUtils.showSnack(
        context,
        'Please sign in to upload a prescription.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Unable to process prescription upload');
      }

      final fields = <String, String>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': '$_selectedCountryCode${_phoneController.text.trim()}',
      };
      if (_noteController.text.trim().isNotEmpty) {
        fields['note'] = _noteController.text.trim();
      }

      _logPrescriptionApiToConsole(
        'POST /create-precription (request)',
        {
          'method': 'POST',
          'headers': {
            'Authorization': 'Bearer ***',
            'Accept': 'application/json',
          },
          'fields': fields,
          'files': [
            {'field': 'file', 'path': _selectedImage!.path},
            if (_brandImage != null)
              {'field': 'med_file', 'path': _brandImage!.path},
          ],
        },
      );

      final result = await _prescriptionService.uploadPrescription(
        authToken: token,
        filePath: _selectedImage!.path,
        medFilePath: _brandImage?.path,
        fields: fields,
      );

      if (result.error != null) {
        throw result.error!;
      }

      final responseBody = result.body ?? result.rawBody;
      final ok = _prescriptionService.uploadSucceeded(result);
      _logPrescriptionApiToConsole(
        'POST /create-precription (response ${result.statusCode})',
        {
          'status_code': result.statusCode,
          'body': responseBody,
        },
      );

      if (ok) {
        await _prescriptionService.recordSuccessfulUpload(result);
        if (mounted) {
          PrescriptionHistoryScreen.invalidateCache();
          AppErrorUtils.showSnack(
            context,
            '✓ Prescription submitted successfully',
            isError: false,
            duration: const Duration(seconds: 2),
          );
          await Navigator.of(context).pushReplacementNamed(
            AppRoutes.prescriptionHistory,
          );
        }
      } else if (result.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      } else if (result.statusCode == 413) {
        throw Exception('File size too large. Maximum size is 10MB.');
      } else {
        throw Exception(
          _prescriptionResponseErrorMessage(responseBody, result.statusCode),
        );
      }
    } catch (e) {
      _logPrescriptionApiToConsole(
        'POST /create-precription (error)',
        {'success': false, 'message': e.toString()},
      );
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          AppErrorUtils.userMessage(e, fallback: 'Failed to submit prescription'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildPageHeader() {
    final top = MediaQuery.paddingOf(context).top;
    return ClipPath(
      clipper: _PrescriptionUploadWaveClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(10, top + 8, 14, 26),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF062A12),
              Color(0xFF0D3D18),
              AppColors.accent,
              Color(0xFF2E7D32),
            ],
            stops: [0.0, 0.28, 0.62, 1.0],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackButtonUtils.simple(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload prescription',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a clear photo for pharmacist review',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secure · Reviewed by a pharmacist',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.medication_liquid_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_authChecked) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7F4),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF20AF67)),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F7F4),
      body: Column(
        children: [
          _buildPageHeader(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20AF67).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF20AF67).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFF20AF67),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add your details, your prescription image, and optionally a photo of the medicine brand you prefer.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildField(
                    isDark,
                    label: 'Full name',
                    controller: _nameController,
                    hint: 'Enter your name',
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    isDark,
                    label: 'Email',
                    controller: _emailController,
                    hint: 'your.email@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildPhoneField(isDark),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sample prescription',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use a clear photo like this. Include patient name, date, medication, and prescriber signature.',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _openSamplePrescriptionPreview(isDark),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/images/sample_prescription.png',
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: 200,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 200,
                                    color: isDark
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFF8FAFC),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade400,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Tap to expand',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Prescription Image',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedImage != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _selectedImage = null),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    )
                  else
                    _buildUploadBox(isDark, false, () async {
                      final option = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF111827)
                                    : Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 10, 18, 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20AF67)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.file_upload_outlined,
                                        color: Color(0xFF20AF67),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Add Prescription',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Choose how you want to upload your file',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _SheetActionTile(
                                      icon: Icons.photo_library_outlined,
                                      title: 'From Gallery',
                                      subtitle:
                                          'Select an image from your phone',
                                      isDark: isDark,
                                      onTap: () =>
                                          Navigator.pop(ctx, 'gallery'),
                                    ),
                                    const SizedBox(height: 10),
                                    _SheetActionTile(
                                      icon: Icons.camera_alt_outlined,
                                      title: 'Scan with Camera',
                                      subtitle: 'Take a photo now',
                                      isDark: isDark,
                                      isPrimary: true,
                                      onTap: () => Navigator.pop(ctx, 'camera'),
                                    ),
                                    const SizedBox(height: 14),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                      if (option == 'gallery') _chooseFromGallery();
                      if (option == 'camera') _scanPrescription();
                    }),
                  const SizedBox(height: 20),
                  Text(
                    'Preferred brand (optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can upload a picture of the product box, bottle, or label for the medicine you want.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_brandImage != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _brandImage!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _brandImage = null),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Remove brand photo'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    )
                  else
                    _buildUploadBox(
                      isDark,
                      false,
                      () => _openBrandImagePicker(isDark),
                      emptyTitle: 'Add brand photo',
                      emptyIcon: Icons.add_photo_alternate_outlined,
                    ),
                  const SizedBox(height: 14),
                  _buildField(
                    isDark,
                    label: 'Notes (optional)',
                    controller: _noteController,
                    hint:
                        'Allergies, instructions, preferred medicine name, or anything else we should know…',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : (_selectedImage != null
                              ? _submitPrescription
                              : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20AF67),
                        disabledBackgroundColor: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSubmitting
                                ? Icons.hourglass_top_rounded
                                : Icons.cloud_upload_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isSubmitting ? 'Uploading...' : 'Submit',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildField(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF20AF67),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor:
                isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(10),
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
              ),
              child: Text(
                '+233',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '123456789',
                  hintStyle: TextStyle(fontSize: 12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF20AF67),
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF8FAFC),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadBox(
    bool isDark,
    bool isSelected,
    VoidCallback onTap, {
    String emptyTitle = 'Add file',
    IconData emptyIcon = Icons.cloud_upload_outlined,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? const Color(0xFF20AF67)
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : emptyIcon,
              size: 28,
              color:
                  isSelected ? const Color(0xFF20AF67) : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              isSelected ? 'File selected' : emptyTitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (!isSelected)
              Text(
                'JPG, PNG • Max 10MB',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionUploadWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 14);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 4,
      size.width,
      size.height - 14,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPrimary
        ? const Color(0xFF20AF67).withValues(alpha: 0.45)
        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300);
    final tileColor = isPrimary
        ? const Color(0xFF20AF67).withValues(alpha: 0.10)
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: tileColor,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF20AF67).withValues(
                  alpha: isPrimary ? 0.2 : 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF20AF67)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}
