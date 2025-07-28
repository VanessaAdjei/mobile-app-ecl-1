// pages/prescription.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'homepage.dart';
import 'package:dotted_border/dotted_border.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:eclapp/widgets/error_display.dart';

class PrescriptionUploadPage extends StatefulWidget {
  final Map<String, dynamic>? item;
  final String token;

  const PrescriptionUploadPage({
    super.key,
    this.item,
    required this.token,
  });

  @override
  State<PrescriptionUploadPage> createState() => _PrescriptionUploadPageState();
}

class _PrescriptionUploadPageState extends State<PrescriptionUploadPage> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  void _chooseFromGallery() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Selecting image from gallery...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Optimize image size
        maxHeight: 1080,
        imageQuality: 85, // Reduce quality slightly for better performance
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final int fileSize = imageFile.lengthSync();
        debugPrint(
            '🔍 Selected image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

        if (fileSize <= 10 * 1024 * 1024) {
          setState(() {
            _selectedImage = imageFile;
          });
          _showConfirmationSnackbar("Prescription uploaded successfully!");
        } else {
          _showConfirmationSnackbar("File exceeds 10MB and was not added.");
        }
      } else {
        _showConfirmationSnackbar("No image selected.");
      }
    } catch (e) {
      debugPrint('🔍 Error selecting image: $e');
      _showConfirmationSnackbar("Failed to upload image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _chooseFromCamera() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Capturing image from camera...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // Optimize image size
        maxHeight: 1080,
        imageQuality: 85, // Reduce quality slightly for better performance
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final int fileSize = imageFile.lengthSync();
        debugPrint('🔍 Captured image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
        
        if (fileSize <= 10 * 1024 * 1024) {
          setState(() {
            _selectedImage = imageFile;
          });
          _showConfirmationSnackbar("Prescription uploaded successfully!");
        } else {
          _showConfirmationSnackbar("File exceeds 10MB and was not added.");
        }
      } else {
        _showConfirmationSnackbar("No image captured.");
      }
    } catch (e) {
      debugPrint('🔍 Error capturing image: $e');
      _showConfirmationSnackbar("Failed to capture image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmationSnackbar(String message) {
    if (mounted) {
      SnackBarUtils.showSuccess(context, message);
    }
  }

  void _showFullImageDialog(BuildContext context, dynamic image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image is File
                  ? Image.file(image, fit: BoxFit.contain)
                  : Image.asset(image, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemDetails() {
    if (widget.item == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  "Prescription Required",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.item!['product']['thumbnail'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.item!['product']['thumbnail'],
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item!['product']['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GHS ${widget.item!['price'] ?? '0.00'}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.item!['batch_no'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Batch: ${widget.item!['batch_no']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitPrescription() async {
    if (_selectedImage != null) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        debugPrint('🔍 Starting prescription upload...');
        // Verify token is valid
        if (widget.token.isEmpty) {
          throw Exception('Please log in to upload a prescription');
        }

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/create-precription'),
        );

        // Add headers
        request.headers['Authorization'] = 'Bearer ${widget.token}';
        request.headers['Accept'] = 'application/json';

        // Add file to request
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedImage!.path,
          ),
        );

        // Add batch number if available
        if (widget.item != null && widget.item!['batch_no'] != null) {
          request.fields['batch_no'] = widget.item!['batch_no'];
        }

        // Add product ID if available
        if (widget.item != null &&
            widget.item!['product'] != null &&
            widget.item!['product']['id'] != null) {
          request.fields['product_id'] =
              widget.item!['product']['id'].toString();
        }

        // Send request with timeout
        debugPrint('🔍 Uploading prescription to server...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timed out. Please try again.');
          },
        );

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          debugPrint('🔍 Upload response: ${data['status']}');
          if (data['status'] == 'success') {
            debugPrint('🔍 Prescription uploaded successfully');
            if (mounted) {
              SnackBarUtils.showSuccess(
                  context, 'Prescription uploaded successfully');
              Navigator.pop(context);
            }
          } else {
            throw Exception(data['message'] ?? 'Failed to upload prescription');
          }
        } else if (response.statusCode == 401) {
          throw Exception('Your session has expired. Please log in again.');
        } else if (response.statusCode == 413) {
          throw Exception('File size too large. Maximum size is 10MB.');
        } else {
          throw Exception(
              'Failed to upload prescription: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
              context, 'Failed to upload prescription: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  void _deleteImage() {
    setState(() {
      _selectedImage = null;
    });
    _showConfirmationSnackbar("Image deleted successfully!");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          },
        ),
        title: Column(
          children: [
            Text(
              'Upload Prescription',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Get your medicines delivered',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.item != null)
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms),
                        SlideEffect(
                            duration: 400.ms,
                            begin: const Offset(0, 0.1),
                            end: Offset.zero)
                      ],
                      child: _buildItemDetails(),
                    ),
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                          duration: 400.ms,
                          begin: const Offset(0, 0.1),
                          end: Offset.zero)
                    ],
                    child: _buildUploadArea(theme),
                  ),
                  const SizedBox(height: 18),
                  if (_selectedImage != null)
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms),
                        SlideEffect(
                            duration: 400.ms,
                            begin: const Offset(0, 0.1),
                            end: Offset.zero)
                      ],
                      child: _buildImagePreview(),
                    ),
                  const SizedBox(height: 18),
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                          duration: 400.ms,
                          begin: const Offset(0, 0.1),
                          end: Offset.zero)
                    ],
                    child: _buildSubmitButton(),
                  ),
                  const SizedBox(height: 24),
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                          duration: 400.ms,
                          begin: const Offset(0, 0.1),
                          end: Offset.zero)
                    ],
                    child: _buildRequirementsCard(),
                  ),
                  const SizedBox(height: 16),
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                          duration: 400.ms,
                          begin: const Offset(0, 0.1),
                          end: Offset.zero)
                    ],
                    child: _buildSamplePrescriptionCard(),
                  ),
                  const SizedBox(height: 16),
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                          duration: 400.ms,
                          begin: const Offset(0, 0.1),
                          end: Offset.zero)
                    ],
                    child: _buildWarningCard(),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Processing image...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor ?? Colors.green.shade50,
    );
  }

  Widget _buildUploadArea(ThemeData theme) {
    return GestureDetector(
      onTap: _isLoading ? null : _showUploadOptions,
      child: DottedBorder(
        color: Colors.green.shade700,
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        dashPattern: const [8, 4],
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload,
                    size: 40, color: Colors.green.shade700),
                const SizedBox(height: 10),
                Text(
                  "Tap to upload prescription",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Supported: JPG, PNG, Max 10MB",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green.shade700),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _chooseFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.green.shade700),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _chooseFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showFullImageDialog(context, _selectedImage!),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _deleteImage,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = _selectedImage != null && !_isLoading && !_isSubmitting;
    final gradient = isEnabled
        ? LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final iconColor = isEnabled ? Colors.white : Colors.grey.shade300;
    final textColor = isEnabled ? Colors.white : Colors.grey.shade300;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isEnabled
                  ? Colors.green.withValues(alpha: 0.18)
                  : Colors.grey.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: isEnabled ? _submitPrescription : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  Icons.send,
                  color: iconColor,
                  size: 28,
                ),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              _isSubmitting ? "Uploading..." : "Submit Prescription",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.pressed) && isEnabled) {
                  return Colors.green.shade900.withValues(alpha: 0.18);
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text("Prescription Requirements",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.green.shade700)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _infoChip("Doctor Details", Icons.person),
              _infoChip("Date of Prescription", Icons.date_range),
              _infoChip("Patient Details", Icons.account_circle),
              _infoChip("Medicine Details", Icons.medication),
              _infoChip("Max File Size: 10MB", Icons.upload_file),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, IconData icon) =>
      Chip(label: Text(text), avatar: Icon(icon, color: Colors.green.shade700));

  Widget _buildSamplePrescriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Sample Prescription",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showFullImageDialog(
                  context, "assets/images/prescriptionsample.png"),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    "assets/images/prescriptionsample.png",
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Our pharmacist will dispense medicines only if the prescription is valid & meets all government regulations.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
