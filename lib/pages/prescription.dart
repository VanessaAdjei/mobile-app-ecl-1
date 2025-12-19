// pages/prescription.dart
// page where users upload their prescription images
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eclapp/widgets/error_display.dart';
import '../config/api_config.dart';

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

  // check if the file is a valid image type
  bool _isValidImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  // pick image from phone gallery
  void _chooseFromGallery() async {
    setState(() => _isLoading = true);
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

  // take a photo with the camera
  void _chooseFromCamera() async {
    setState(() => _isLoading = true);
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
                  color: Colors.red[600],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Invalid File Type',
                  style: TextStyle(
                    color: Colors.red[700],
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

  // show the product details if we have an item
  Widget _buildItemDetails() {
    if (widget.item == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.item!['product']['thumbnail'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.item!['product']['thumbnail'],
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image_not_supported,
                        color: Colors.grey.shade400, size: 24),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'GHS ${widget.item!['price'] ?? '0.00'}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medical_services_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Prescription',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // upload the prescription image to the server
  void _submitPrescription() async {
    if (_selectedImage != null) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        debugPrint('🔍 Starting prescription upload...');
        // make sure theyre logged in
        if (widget.token.isEmpty) {
          throw Exception('Please log in to upload a prescription');
        }

        // create the multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.createPrescription)),
        );

        // add auth headers
        request.headers['Authorization'] = 'Bearer ${widget.token}';
        request.headers['Accept'] = 'application/json';

        // add the image file
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedImage!.path,
          ),
        );

        // add batch number if we have it
        if (widget.item != null && widget.item!['batch_no'] != null) {
          request.fields['batch_no'] = widget.item!['batch_no'];
        }

        // add product id if we have it
        if (widget.item != null &&
            widget.item!['product'] != null &&
            widget.item!['product']['id'] != null) {
          request.fields['product_id'] =
              widget.item!['product']['id'].toString();
        }

        // send it with a timeout
        debugPrint('🔍 Uploading prescription ...');
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

  // remove the selected image
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            if (_selectedImage != null) {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade600, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Leave Upload?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your uploaded prescription will be lost.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Leave'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.upload_file_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Upload Prescription',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.item != null) ...[
              _buildItemDetails(),
              const SizedBox(height: 12),
            ],
            _buildUploadArea(theme),
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              _buildImagePreview(),
            ],
            const SizedBox(height: 16),
            _buildSubmitButton(),
            const SizedBox(height: 16),
            _buildRequirementsCard(),
            const SizedBox(height: 12),
            _buildSamplePrescriptionCard(),
            const SizedBox(height: 12),
            _buildWarningCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // the area where you tap to upload
  Widget _buildUploadArea(ThemeData theme) {
    return GestureDetector(
      onTap: _isLoading ? null : _showUploadOptions,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.shade400,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade100,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Colors.red.shade700,
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.upload_file_rounded,
                          size: 28, color: Colors.red.shade800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Tap to upload prescription",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "JPG, PNG • Max 10MB",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUploadOption(
                      icon: Icons.photo_library_rounded,
                      title: 'Choose from Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _chooseFromGallery();
                      },
                    ),
                    const Divider(height: 1),
                    _buildUploadOption(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take a Photo',
                      onTap: () {
                        Navigator.pop(context);
                        _chooseFromCamera();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.red.shade800, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade900,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  // show a preview of the selected image
  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => _showFullImageDialog(context, _selectedImage!),
              child: Image.file(
                _selectedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
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
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // the submit button
  Widget _buildSubmitButton() {
    final isEnabled = _selectedImage != null && !_isLoading && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isEnabled ? _submitPrescription : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? Colors.red.shade600 : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _isSubmitting ? "Uploading..." : "Submit Prescription",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                "Requirements",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoChip("Doctor Details", Icons.person_outline_rounded),
              _buildInfoChip("Date", Icons.calendar_today_rounded),
              _buildInfoChip("Patient Details", Icons.person_rounded),
              _buildInfoChip("Medicine Details", Icons.medication_rounded),
              _buildInfoChip("Max 10MB", Icons.upload_file_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.green.shade700, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplePrescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_rounded, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                "Sample Prescription",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showFullImageDialog(
                context, "assets/images/prescriptionsample.png"),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  "assets/images/prescriptionsample.png",
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Our pharmacist will dispense medicines only if the prescription is valid & meets all government regulations.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
