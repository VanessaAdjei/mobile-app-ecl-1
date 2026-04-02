// pages/prescription_upload_standalone.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'signinpage.dart';

class PrescriptionUploadStandalone extends StatefulWidget {
  const PrescriptionUploadStandalone({super.key});

  @override
  State<PrescriptionUploadStandalone> createState() =>
      _PrescriptionUploadStandaloneState();
}

class _PrescriptionUploadStandaloneState
    extends State<PrescriptionUploadStandalone> {
  File? _prescriptionImage;
  File? _insuranceImage;
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
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

  Future<void> _pickInsuranceImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _insuranceImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPrescription() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _prescriptionImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please fill in all required fields and upload prescription'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = await AuthService.getCurrentUserID();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/prescription-upload'),
      );

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
      request.files.add(
        await http.MultipartFile.fromPath(
          'prescription',
          _prescriptionImage!.path,
        ),
      );

      // Add insurance image if available
      if (_insuranceImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'insurance',
            _insuranceImage!.path,
          ),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prescription uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear form
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _noteController.clear();
          setState(() {
            _prescriptionImage = null;
            _insuranceImage = null;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload prescription: $responseData'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            // 4-step process header
            _buildStepHeader(),
            const SizedBox(height: 30),

            // Form section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload your prescription',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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

                  // Upload Prescription
                  _buildUploadSection(
                    title: 'Upload Prescription',
                    isOptional: false,
                    image: _prescriptionImage,
                    onTap: _pickPrescriptionImage,
                  ),
                  const SizedBox(height: 20),

                  // Upload Insurance (Optional)
                  _buildUploadSection(
                    title: 'Upload Insurance (Optional)',
                    isOptional: true,
                    image: _insuranceImage,
                    onTap: _pickInsuranceImage,
                  ),
                  const SizedBox(height: 20),

                  // Pick up or Delivery
                  _buildDropdown(),
                  const SizedBox(height: 20),

                  // Note
                  _buildNoteField(),
                  const SizedBox(height: 30),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPrescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
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

  Widget _buildStepHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(1, 'Upload a clear photo of\nyour prescription',
              Icons.description_outlined),
          _buildStep(
              2, 'Enter your contact\ndetails', Icons.edit_note_outlined),
          _buildStep(3, 'Our pharmacist reviews\nand confirms availability',
              Icons.verified_outlined),
          _buildStep(
              4,
              'We call or message you to\nfinalize payment and delivery',
              Icons.local_shipping_outlined),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey.shade700),
          const SizedBox(height: 6),
          Text(
            'STEP $number',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF4461F2), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
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
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
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
              prefixIcon:
                  Icon(Icons.phone_outlined, color: Colors.grey.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4461F2)),
              ),
              filled: true,
              fillColor: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add file',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick up or Delivery',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeliveryOption,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'delivery',
                  child: Text('Delivery'),
                ),
                DropdownMenuItem(
                  value: 'pickup',
                  child: Text('Pick up'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDeliveryOption = value!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Note',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add any additional notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4461F2)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem(
            Icons.delivery_dining_outlined,
            'STREAMLINED DELIVERY',
            'Efficient Delivery within 24\nhours for rapid service',
          ),
          Container(
            height: 70,
            width: 1,
            color: Colors.grey.shade300,
          ),
          _buildInfoItem(
            Icons.favorite_border,
            'CONSUMER APPROVAL',
            'Your convenience is our\nachievement',
          ),
          Container(
            height: 70,
            width: 1,
            color: Colors.grey.shade300,
          ),
          _buildInfoItem(
            Icons.headset_mic_outlined,
            'TOP-NOTCH SUPPORT',
            'Seek assistance? Our team is\navailable to help',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 38, color: Colors.grey.shade700),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
