// pages/prescription.dart
// Prescription upload tied to a product (from item detail / clearance).
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eclapp/widgets/error_display.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../services/prescription_service.dart';
import '../services/prescription_upload_status_service.dart';
import '../utils/app_error_utils.dart';
import 'app_back_button.dart';

class PrescriptionUploadPage extends StatefulWidget {
  final Map<String, dynamic>? item;
  final String? token;

  const PrescriptionUploadPage({
    super.key,
    this.item,
    this.token,
  });

  @override
  State<PrescriptionUploadPage> createState() => _PrescriptionUploadPageState();
}

class _PrescriptionUploadPageState extends State<PrescriptionUploadPage> {
  final PrescriptionService _prescriptionService = PrescriptionService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  File? _brandImage;
  bool _isSubmitting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final String _selectedCountryCode = '+233';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData['name']?.toString() ?? '';
          _emailController.text = userData['email']?.toString() ?? '';
          _phoneController.text = userData['phone']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  // check if the file is a valid image type
  bool _isValidImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  // pick image from phone gallery
  void _chooseFromGallery() async {
    try {
      debugPrint('🔍 Selecting image from gallery...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // make image smaller so it uploads faster
        maxHeight: 1080,
        imageQuality: 85, // reduce quality a bit so file is smaller
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // make sure its a valid image file
        if (!_isValidImageFile(pickedFile.path)) {
          _showFileTypeError();
          return;
        }

        // check the file size
        final int fileSize = imageFile.lengthSync();
        debugPrint(
            '🔍 Selected image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

        // only accept files under 10MB
        if (fileSize <= 10 * 1024 * 1024) {
          setState(() {
            _selectedImage = imageFile;
          });
          _showConfirmationSnackbar(
              "Image added. Tap Submit Prescription to send.");
        } else {
          _showConfirmationSnackbar("File exceeds 10MB and was not added.");
        }
      } else {
        _showConfirmationSnackbar("No image selected.");
      }
    } catch (e) {
      debugPrint('🔍 Error selecting image: $e');
      _showConfirmationSnackbar("Failed to add image: $e");
    }
  }

  /// Scan prescription using the camera (with optional scan tips).
  void _scanPrescription() async {
    if (!mounted) return;
    _showScanTipsThenCamera();
  }

  void _showScanTipsThenCamera() async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: AppColors.primary,
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
              _buildTipItem(
                icon: Icons.light_mode,
                title: 'Good lighting',
                description: 'Use natural light or a bright area',
              ),
              const SizedBox(height: 10),
              _buildTipItem(
                icon: Icons.crop_free,
                title: 'Keep flat',
                description: 'Place the document on an even surface',
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
                description: 'Include the complete prescription text',
              ),
              const SizedBox(height: 20),
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
                        backgroundColor: AppColors.primary,
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
      await _chooseFromCamera();
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
          Icon(icon, size: 20, color: AppColors.primary),
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

  // take a photo with the camera
  Future<void> _chooseFromCamera() async {
    try {
      debugPrint('🔍 Capturing image from camera...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // resize image so its not huge
        maxHeight: 1080,
        imageQuality: 85, // lower quality = smaller file
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // check if its a valid image
        if (!_isValidImageFile(pickedFile.path)) {
          _showFileTypeError();
          return;
        }

        // check file size
        final int fileSize = imageFile.lengthSync();
        debugPrint(
            '🔍 Captured image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

        // only accept files under 10MB
        if (fileSize <= 10 * 1024 * 1024) {
          setState(() {
            _selectedImage = imageFile;
          });
          _showConfirmationSnackbar(
              "Image added. Tap Submit Prescription to send.");
        } else {
          _showConfirmationSnackbar("File exceeds 10MB and was not added.");
        }
      } else {
        _showConfirmationSnackbar("No image captured.");
      }
    } catch (e) {
      debugPrint('🔍 Error capturing image: $e');
      _showConfirmationSnackbar("Failed to capture image: $e");
    }
  }

  void _showConfirmationSnackbar(String message) {
    if (mounted) {
      SnackBarUtils.showSuccess(context, message);
    }
  }

  void _showFileTypeError() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.green[600],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Invalid File Type',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 Supported Formats:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('• JPG (JPEG)',
                          style: TextStyle(color: Colors.blue[600])),
                      Text('• PNG', style: TextStyle(color: Colors.blue[600])),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select a valid image file and try again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it!',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _handleBack() {
    if (_selectedImage != null) {
      _showLeaveDialog();
    } else {
      Navigator.pop(context);
    }
  }

  void _showLeaveDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade600, size: 40),
              const SizedBox(height: 12),
              Text(
                'Leave upload?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your prescription image will not be saved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Stay', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Leave', style: GoogleFonts.poppins()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSamplePrescriptionPreview(bool isDark) {
    showDialog<void>(
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

  /// Product being ordered — shown when opened from item detail.
  Widget _buildItemDetails(bool isDark) {
    if (widget.item == null) return const SizedBox.shrink();

    final thumb = widget.item!['product']['thumbnail']?.toString() ?? '';
    final imageUrl =
        thumb.isNotEmpty ? ApiConfig.getImageOrStorageUrl(thumb) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 64,
                width: 64,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 64,
                  width: 64,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _productThumbPlaceholder(),
              ),
            )
          else
            _productThumbPlaceholder(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordering',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item!['product']['name'] ?? 'Unknown product',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'GHS ${widget.item!['price'] ?? '0.00'}',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFB91C1C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.medication_liquid_rounded,
                    color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  'Rx',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productThumbPlaceholder() {
    return Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.medication_outlined,
          color: Colors.grey.shade400, size: 28),
    );
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
            BackButtonUtils.custom(
              onPressed: _handleBack,
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
                    widget.item != null
                        ? 'Attach a valid prescription for this medicine'
                        : 'Send a clear photo for pharmacist review',
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
                          'Secure · Pharmacist reviewed',
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

  Future<void> _pickBrandImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() => _brandImage = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error selecting brand image: $e');
    }
  }

  Future<void> _pickBrandImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() => _brandImage = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error capturing brand image: $e');
    }
  }

  Future<void> _openBrandImagePicker(bool isDark) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
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
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
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
      ),
    );
    if (!mounted) return;
    if (option == 'gallery') await _pickBrandImageFromGallery();
    if (option == 'camera') await _pickBrandImageFromCamera();
  }

  Future<void> _openPrescriptionPicker(bool isDark) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
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
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.file_upload_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add Prescription',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how you want to upload your file',
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
                  subtitle: 'Select an image from your phone',
                  isDark: isDark,
                  onTap: () => Navigator.pop(ctx, 'gallery'),
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
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (option == 'gallery') _chooseFromGallery();
    if (option == 'camera') _scanPrescription();
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

  Future<void> _submitPrescription() async {
    if (_selectedImage == null) return;

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      AppErrorUtils.showSnack(context, 'Please fill in all required fields');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = widget.token ?? await AuthService.getToken();
      final authToken = token ?? 'guest-temp-token';
      if (authToken.isEmpty) {
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
      if (widget.item != null && widget.item!['batch_no'] != null) {
        fields['batch_no'] = widget.item!['batch_no'].toString();
      }
      if (widget.item != null &&
          widget.item!['product'] != null &&
          widget.item!['product']['id'] != null) {
        fields['product_id'] = widget.item!['product']['id'].toString();
      }

      final result = await _prescriptionService.uploadPrescription(
        authToken: authToken,
        filePath: _selectedImage!.path,
        medFilePath: _brandImage?.path,
        fields: fields,
      );

      if (_prescriptionService.uploadSucceeded(result)) {
        if (mounted) {
          await PrescriptionUploadStatusService.markUploadedFromItem(
            widget.item,
          );
          AppErrorUtils.showSnack(
            context,
            'Prescription submitted successfully',
            isError: false,
            duration: const Duration(seconds: 2),
          );
          Navigator.pop(context, true);
        }
      } else if (result.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      } else if (result.statusCode == 413) {
        throw Exception('File size too large. Maximum size is 10MB.');
      } else {
        throw Exception(
          _prescriptionResponseErrorMessage(
            result.body ?? result.rawBody,
            result.statusCode,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          AppErrorUtils.userMessage(
            e,
            fallback: 'Failed to submit prescription',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
                      if (widget.item != null) ...[
                        _buildItemDetails(isDark),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.item != null
                                    ? 'Add your details and a clear prescription for this medicine. You can also attach a brand photo if you have a preference.'
                                    : 'Add your details, your prescription image, and optionally a photo of the medicine brand you prefer.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
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
                          color:
                              isDark ? const Color(0xFF1F2937) : Colors.white,
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
                                color:
                                    isDark ? Colors.white : Colors.black87,
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
                              onTap: () =>
                                  _openSamplePrescriptionPreview(isDark),
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
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(999),
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
                                width: double.infinity,
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
                        _buildUploadBox(
                          isDark,
                          false,
                          () => _openPrescriptionPicker(isDark),
                        ),
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
                            backgroundColor: AppColors.primary,
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
            hintStyle: const TextStyle(fontSize: 12),
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
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
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
                _selectedCountryCode,
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
                  hintStyle: const TextStyle(fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
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
                ? AppColors.primary
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
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
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
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isPrimary
        ? AppColors.primary.withValues(alpha: 0.45)
        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300);
    final tileColor = isPrimary
        ? AppColors.primary.withValues(alpha: 0.1)
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
                color: AppColors.primary.withValues(
                  alpha: isPrimary ? 0.2 : 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
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
