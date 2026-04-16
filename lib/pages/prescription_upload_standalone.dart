// pages/prescription_upload_standalone.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
            const SizedBox(height: 20),

            // Form section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.upload_file_rounded,
                          color: Color(0xFF4CAF50),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Upload your prescription',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPrescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        elevation: 4,
                        shadowColor: Color(0xFF4CAF50).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F9F7), Color(0xFFE8F5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
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
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 8),
          Text(
            'STEP $number',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
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
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, color: Color(0xFF4CAF50), size: 22),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (isOptional)
              Container(
                margin: EdgeInsets.only(left: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: image == null ? Colors.grey.shade50 : Colors.transparent,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Color(0xFF4CAF50),
                            size: 20,
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
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF4CAF50).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 36,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to upload',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoItem(
            Icons.local_shipping_outlined,
            'Fast Delivery',
            'Quick delivery within 24 hours',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
          _buildInfoItem(
            Icons.verified_user_outlined,
            'Secure Process',
            'Your privacy and data are protected',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
          _buildInfoItem(
            Icons.support_agent_outlined,
            '24/7 Support',
            'Our team is here to help anytime',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
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
