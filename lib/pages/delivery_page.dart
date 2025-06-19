// pages/delivery_page.dart
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'AppBackButton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  _DeliveryPageState createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  String deliveryOption = 'delivery';
  double deliveryFee = 0.00;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _highlightPhoneField = false;
  bool _highlightPickupField = false;
  bool _highlightNameField = false;
  bool _highlightEmailField = false;
  bool _highlightRegionField = false;
  bool _highlightCityField = false;
  bool _highlightAddressField = false;
  final GlobalKey pickupSectionKey = GlobalKey();
  final GlobalKey phoneSectionKey = GlobalKey();
  final GlobalKey nameSectionKey = GlobalKey();
  final GlobalKey emailSectionKey = GlobalKey();
  final GlobalKey regionSectionKey = GlobalKey();
  final GlobalKey citySectionKey = GlobalKey();
  final GlobalKey addressSectionKey = GlobalKey();
  String? selectedRegion;
  String? selectedCity;
  String? selectedPickupSite;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      print('=== STARTING LOAD USER DATA ===');

      // First, immediately load basic user data for fast UI response
      await _loadBasicUserData();
      print('Basic user data loaded immediately');

      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      print('User logged in: $isLoggedIn');

      if (!isLoggedIn) {
        print('User not logged in, skipping API call');
        return;
      }

      // User is logged in, try to load delivery info from API in background
      print(
          'User is logged in, fetching delivery info from API in background...');

      // Use a shorter timeout and handle the API call asynchronously
      try {
        final deliveryResult = await DeliveryService.getLastDeliveryInfo()
            .timeout(const Duration(
                seconds: 8)); // 8 second timeout for faster failure

        print('API result success: ${deliveryResult['success']}');
        print('API result message: ${deliveryResult['message']}');
        print('API result data: ${deliveryResult['data']}');

        if (deliveryResult['success'] &&
            deliveryResult['data'] != null &&
            mounted) {
          final deliveryData = deliveryResult['data'];
          print('Setting form data from API...');
          print('Name: "${deliveryData['name']}"');
          print('Email: "${deliveryData['email']}"');
          print('Phone: "${deliveryData['phone']}"');
          print('Region: "${deliveryData['region']}"');
          print('City: "${deliveryData['city']}"');
          print('Address: "${deliveryData['address']}"');
          print('Shipping Type: "${deliveryData['shipping_type']}"');
          print('Pickup Location: "${deliveryData['pickup_location']}"');
          print('Delivery Option: "${deliveryData['delivery_option']}"');

          setState(() {
            // Pre-fill the form fields with delivery data
            _nameController.text = deliveryData['name'] ?? '';
            _emailController.text = deliveryData['email'] ?? '';
            _phoneController.text = deliveryData['phone'] ?? '';

            // Set delivery option - use shipping_type as fallback
            deliveryOption = (deliveryData['delivery_option'] ??
                    deliveryData['shipping_type'] ??
                    'delivery')
                .toLowerCase();

            // Fill delivery-specific fields
            if (deliveryOption == 'delivery') {
              print(' SETTING DELIVERY FIELDS:');
              print(
                  'Setting region controller to: "${deliveryData['region']}"');
              print('Setting city controller to: "${deliveryData['city']}"');
              print(
                  'Setting address controller to: "${deliveryData['address']}"');

              _regionController.text = deliveryData['region'] ?? '';
              _cityController.text = deliveryData['city'] ?? '';
              _addressController.text = deliveryData['address'] ?? '';
              _updateDeliveryFee();
            } else if (deliveryOption == 'pickup') {
              selectedRegion = deliveryData['pickup_region'];
              selectedCity = deliveryData['pickup_city'];
              // Use pickup_location as fallback for pickup_site
              selectedPickupSite = deliveryData['pickup_site'] ??
                  deliveryData['pickup_location'];
            }

            // Fill notes
            _notesController.text = deliveryData['notes'] ?? '';
          });

          print('Delivery information loaded from API successfully');
          print('Form fields after setState:');
          print('- Name controller: "${_nameController.text}"');
          print('- Email controller: "${_emailController.text}"');
          print('- Phone controller: "${_phoneController.text}"');
          print('- Region controller: "${_regionController.text}"');
          print('- City controller: "${_cityController.text}"');
          print('- Address controller: "${_addressController.text}"');
          print('- Delivery option: "$deliveryOption"');
          print('- Selected pickup region: "$selectedRegion"');
          print('- Selected pickup city: "$selectedCity"');
          print('- Selected pickup site: "$selectedPickupSite"');
        } else {
          print('No delivery data found from API');
          if (deliveryResult['message'] != null) {
            print(
                'Delivery info loading message: ${deliveryResult['message']}');
          }
        }
      } catch (apiError) {
        print('API error loading delivery info: $apiError');
        // API failed, but we already have basic user data loaded
        print('Continuing with basic user data only');
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Continue with empty fields if there's an error
    }
    print('=== ENDING LOAD USER DATA ===');
  }

  Future<void> _loadBasicUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();
      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading basic user data: $e');
    }
  }

  double _calculateDeliveryFee(String region, String city) {
    return DeliveryService.calculateDeliveryFee(region, city);
  }

  void _resetHighlights() {
    if (!mounted) return;
    setState(() {
      _highlightPhoneField = false;
      _highlightPickupField = false;
      _highlightNameField = false;
      _highlightEmailField = false;
      _highlightRegionField = false;
      _highlightCityField = false;
      _highlightAddressField = false;
    });
  }

  void _updateDeliveryFee() {
    if (_regionController.text.isNotEmpty && _cityController.text.isNotEmpty) {
      setState(() {
        deliveryFee =
            _calculateDeliveryFee(_regionController.text, _cityController.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // Enhanced header with better design
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0))
                ],
                child: Container(
                  padding: EdgeInsets.only(top: topPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header with back button and title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            AppBackButton(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Delivery Information',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: 48), // Balance the back button
                          ],
                        ),
                      ),
                      // Enhanced progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressStep("Cart",
                                  isActive: false, isCompleted: true, step: 1),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Delivery",
                                  isActive: true, isCompleted: false, step: 2),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Payment",
                                  isActive: false, isCompleted: false, step: 3),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Confirmation",
                                  isActive: false, isCompleted: false, step: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildDeliveryOptions(),
                              ),
                              const SizedBox(height: 20),
                              if (deliveryOption == 'delivery')
                                Animate(
                                  effects: [
                                    FadeEffect(duration: 400.ms),
                                    SlideEffect(
                                        duration: 400.ms,
                                        begin: Offset(0, 0.1),
                                        end: Offset(0, 0))
                                  ],
                                  child: _buildDeliveryInfo(),
                                ),
                              if (deliveryOption == 'pickup')
                                Animate(
                                  effects: [
                                    FadeEffect(duration: 400.ms),
                                    SlideEffect(
                                        duration: 400.ms,
                                        begin: Offset(0, 0.1),
                                        end: Offset(0, 0))
                                  ],
                                  child: _buildPickupForm(),
                                ),
                              const SizedBox(height: 20),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildContactInfo(),
                              ),
                              const SizedBox(height: 20),
                              // Only show delivery notes for delivery option
                              if (deliveryOption == 'delivery') ...[
                                Animate(
                                  effects: [
                                    FadeEffect(duration: 400.ms),
                                    SlideEffect(
                                        duration: 400.ms,
                                        begin: Offset(0, 0.1),
                                        end: Offset(0, 0))
                                  ],
                                  child: _buildDeliveryNotes(),
                                ),
                                const SizedBox(height: 20),
                              ],
                              const SizedBox(height: 24),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildOrderSummary(cart),
                              ),
                              const SizedBox(height: 32),
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildContinueButton(),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 50,
      height: 1,
      color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 2,
            ),
            shape: BoxShape.circle,
            boxShadow: isCompleted || isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight:
                isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: Colors.green[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DELIVERY METHOD',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDeliveryOptionCard(
                        title: 'Home Delivery',
                        subtitle: 'Delivered to your doorstep',
                        icon: Icons.home,
                        isSelected: deliveryOption == 'delivery',
                        onTap: () => _handleDeliveryOptionChange('delivery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDeliveryOptionCard(
                        title: 'Pickup Station',
                        subtitle: 'Collect from nearest station',
                        icon: Icons.store,
                        isSelected: deliveryOption == 'pickup',
                        onTap: () => _handleDeliveryOptionChange('pickup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color:
                    isSelected ? Colors.green.shade700 : Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color:
                    isSelected ? Colors.green.shade600 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'DELIVERY INFORMATION',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_regionController.text.isNotEmpty &&
                _cityController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DELIVERY LOCATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_addressController.text.isNotEmpty) ...[
                      Text(
                        _addressController.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '${_cityController.text}, ${_regionController.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delivery Fee: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'GHS ${deliveryFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please fill in your region and city to see delivery information',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupForm() {
    final Map<String, Map<String, List<String>>> pickupLocations = {
      'Greater Accra': {
        'Accra': [
          'Accra Mall',
          'West Hills Mall',
          'Achimota Retail Centre',
          'Osu Mall'
        ],
        'Tema': ['Tema Mall', 'Community 25 Station', 'Harbour City Mall']
      },
      'Ashanti': {
        'Kumasi': [
          'Kumasi City Mall',
          'Adum Station',
          'Asokwa Station',
          'Kejetia Market'
        ]
      },
      'Western': {
        'Takoradi': ['Takoradi Mall', 'Airport Station', 'Harbour Station']
      },
      'Eastern': {
        'Madina': ['Madina Mall', 'Madina Zongo Junction'],
        'Koforidua': ['Koforidua Station', 'Jackson Park']
      },
      'Central': {
        'Cape Coast': ['Cape Coast Mall', 'University Station'],
        'Winneba': ['Winneba Station', 'University of Education']
      },
      'Volta': {
        'Ho': ['Ho Station', 'Volta Regional Hospital'],
        'Hohoe': ['Hohoe Station', 'Central Market']
      }
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'PICKUP LOCATION',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Region Dropdown
            _buildPickupDropdown(
              label: 'Select Region',
              value: selectedRegion,
              items: pickupLocations.keys.map((region) {
                return DropdownMenuItem(
                  value: region,
                  child: Text(region),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedRegion = value;
                  selectedCity = null;
                  selectedPickupSite = null;
                });
              },
            ),
            if (selectedRegion != null) ...[
              const SizedBox(height: 16),
              // City Dropdown
              _buildPickupDropdown(
                label: 'Select City',
                value: selectedCity,
                items: pickupLocations[selectedRegion]!.keys.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCity = value;
                    selectedPickupSite = null;
                  });
                },
              ),
            ],
            if (selectedCity != null) ...[
              const SizedBox(height: 16),
              // Pickup Site Dropdown
              _buildPickupDropdown(
                label: 'Select Pickup Site',
                value: selectedPickupSite,
                items:
                    pickupLocations[selectedRegion]![selectedCity]!.map((site) {
                  return DropdownMenuItem(
                    value: site,
                    child: Text(site),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPickupSite = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            if (_highlightPickupField) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please select all required pickup location fields',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup stations are open Monday-Saturday, 9am-6pm. Please bring a valid ID for collection.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: _highlightPickupField ? Colors.red : Colors.grey[700],
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _highlightPickupField ? Colors.red : Colors.grey[300]!,
              width: _highlightPickupField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _highlightPickupField ? Colors.red.shade50 : Colors.grey[50],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: _highlightPickupField ? Colors.red : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            items: items,
            onChanged: (String? newValue) {
              onChanged(newValue);
              // Reset highlight when user makes a selection
              if (_highlightPickupField) {
                setState(() {
                  _highlightPickupField = false;
                });
              }
            },
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: _highlightPickupField ? Colors.red : Colors.grey[600],
            ),
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    bool isPhoneValid =
        _phoneController.text.length == 10 || _phoneController.text.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'CONTACT INFORMATION',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name Field
            _buildFormField(
              key: nameSectionKey,
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              isRequired: true,
              isHighlighted: _highlightNameField,
              onChanged: (value) {
                setState(() {
                  _highlightNameField = false;
                });
              },
            ),
            const SizedBox(height: 16),
            // Email Field
            _buildFormField(
              key: emailSectionKey,
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              isRequired: true,
              isHighlighted: _highlightEmailField,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                setState(() {
                  _highlightEmailField = false;
                });
              },
            ),
            const SizedBox(height: 16),
            // Phone Field
            _buildPhoneField(isPhoneValid),
            // Only show location fields for delivery option
            if (deliveryOption == 'delivery') ...[
              const SizedBox(height: 16),
              // Region Field
              _buildRegionDropdown(),
              const SizedBox(height: 16),
              // City Field
              _buildFormField(
                key: citySectionKey,
                controller: _cityController,
                label: 'City',
                icon: Icons.location_on_outlined,
                isRequired: true,
                isHighlighted: _highlightCityField,
                onChanged: (value) {
                  setState(() {
                    _highlightCityField = false;
                    _updateDeliveryFee();
                  });
                },
              ),
              const SizedBox(height: 16),
              // Address Field
              _buildFormField(
                key: addressSectionKey,
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                isRequired: true,
                isHighlighted: _highlightAddressField,
                onChanged: (value) {
                  setState(() {
                    _highlightAddressField = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required GlobalKey key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isRequired,
    required bool isHighlighted,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isHighlighted ? Colors.red : Colors.grey[700],
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isHighlighted ? Colors.red : Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey[300]!,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey[300]!,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.green[400]!,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isHighlighted ? Colors.red.shade50 : Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRegionDropdown() {
    final List<String> regions = [
      'Greater Accra',
      'Ashanti',
      'Western',
      'Eastern',
      'Central',
      'Volta',
      'Northern',
      'Upper East',
      'Upper West',
      'Bono',
      'Bono East',
      'Ahafo',
      'Savannah',
      'North East',
      'Oti',
      'Western North',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Region',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: _highlightRegionField ? Colors.red : Colors.grey[700],
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _highlightRegionField ? Colors.red : Colors.grey[300]!,
              width: _highlightRegionField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _highlightRegionField ? Colors.red.shade50 : Colors.grey[50],
          ),
          child: DropdownButtonFormField<String>(
            key: regionSectionKey,
            value: _regionController.text.isEmpty ||
                    !regions.contains(_regionController.text)
                ? null
                : _regionController.text,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.location_city_outlined,
                color: _highlightRegionField ? Colors.red : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text(
              'Select your region',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            items: regions.map((String region) {
              return DropdownMenuItem<String>(
                value: region,
                child: Text(
                  region,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _regionController.text = newValue;
                  _highlightRegionField = false;
                  _updateDeliveryFee();
                });
              }
            },
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: _highlightRegionField ? Colors.red : Colors.grey[600],
            ),
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isPhoneValid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phone Number',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: _highlightPhoneField ? Colors.red : Colors.grey[700],
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          buildCounter: (BuildContext context,
              {required int currentLength,
              required bool isFocused,
              required int? maxLength}) {
            return Text(
              '${currentLength}/$maxLength',
              style: TextStyle(
                color: currentLength == maxLength ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            );
          },
          onChanged: (value) {
            setState(() {
              _highlightPhoneField = false;
            });
          },
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('🇬🇭', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 4),
                  Text('+233', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey[300]!,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey[300]!,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.green[400]!,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                _highlightPhoneField ? Colors.red.shade50 : Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            errorText: isPhoneValid ? null : 'Phone number must be 10 digits',
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'DELIVERY NOTES',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText:
                    'Any special delivery instructions? (e.g., gate code, landmarks, etc.)',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final subtotal = cart.calculateSubtotal();
    final total = subtotal + deliveryFee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', subtotal,
                      icon: Icons.shopping_cart_outlined),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Delivery Fee', deliveryFee,
                      icon: Icons.local_shipping_outlined),
                  Divider(height: 24, thickness: 1, color: Colors.grey[300]),
                  _buildSummaryRow('TOTAL', total,
                      isHighlighted: true, icon: Icons.payment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isHighlighted = false, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: isHighlighted ? Colors.green[700] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              fontSize: isHighlighted ? 16 : 14,
              color: isHighlighted ? Colors.grey[800] : Colors.grey[700],
            ),
          ),
        ),
        Text(
          'GHS ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
            fontSize: isHighlighted ? 18 : 14,
            color: isHighlighted ? Colors.green[700] : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade600,
              Colors.green.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              bool isValid = true;

              // Validate name
              if (_nameController.text.trim().isEmpty) {
                setState(() {
                  _highlightNameField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    nameSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate email
              if (_emailController.text.trim().isEmpty) {
                setState(() {
                  _highlightEmailField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    emailSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(_emailController.text.trim())) {
                setState(() {
                  _highlightEmailField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    emailSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate region
              if (deliveryOption == 'delivery' &&
                  _regionController.text.trim().isEmpty) {
                setState(() {
                  _highlightRegionField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    regionSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate city
              if (deliveryOption == 'delivery' &&
                  _cityController.text.trim().isEmpty) {
                setState(() {
                  _highlightCityField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    citySectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate address
              if (deliveryOption == 'delivery' &&
                  _addressController.text.trim().isEmpty) {
                setState(() {
                  _highlightAddressField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    addressSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate phone number
              if (_phoneController.text.isEmpty) {
                setState(() {
                  _highlightPhoneField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    phoneSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              } else if (_phoneController.text.length != 10) {
                setState(() {
                  _highlightPhoneField = true;
                  isValid = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Scrollable.ensureVisible(
                    phoneSectionKey.currentContext!,
                    alignment: 0.5,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }

              // Validate pickup fields
              if (deliveryOption == 'pickup') {
                if (selectedRegion == null) {
                  setState(() {
                    _highlightPickupField = true;
                    isValid = false;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      pickupSectionKey.currentContext!,
                      alignment: 0.5,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  });
                } else if (selectedCity == null) {
                  setState(() {
                    _highlightPickupField = true;
                    isValid = false;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      pickupSectionKey.currentContext!,
                      alignment: 0.5,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  });
                } else if (selectedPickupSite == null) {
                  setState(() {
                    _highlightPickupField = true;
                    isValid = false;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      pickupSectionKey.currentContext!,
                      alignment: 0.5,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  });
                }
              }

              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child:
                              Text('Please fill all required fields correctly'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.all(16),
                  ),
                );
                return;
              }

              try {
                // Save delivery information to API
                print('=== STARTING API SAVE ===');
                print('User: ${_nameController.text.trim()}');
                print('Email: ${_emailController.text.trim()}');
                print('Phone: ${_phoneController.text}');
                print('Delivery Option: $deliveryOption');
                print('Shipping Type: $deliveryOption');
                if (deliveryOption == 'delivery') {
                  print('Region: ${_regionController.text.trim()}');
                  print('City: ${_cityController.text.trim()}');
                  print('Address: ${_addressController.text.trim()}');
                } else {
                  print('Pickup Region: ${selectedRegion}');
                  print('Pickup City: ${selectedCity}');
                  print('Pickup Site: ${selectedPickupSite}');
                  print('Pickup Location: ${selectedPickupSite}');
                }
                print('Notes: ${_notesController.text.trim()}');
                print('========================');

                final saveResult = await DeliveryService.saveDeliveryInfo(
                  name: _nameController.text.trim(),
                  email: _emailController.text.trim(),
                  phone: _phoneController.text,
                  deliveryOption: deliveryOption,
                  region: deliveryOption == 'delivery'
                      ? _regionController.text.trim()
                      : null,
                  city: deliveryOption == 'delivery'
                      ? _cityController.text.trim()
                      : null,
                  address: deliveryOption == 'delivery'
                      ? _addressController.text.trim()
                      : null,
                  notes: _notesController.text.trim(),
                  pickupRegion:
                      deliveryOption == 'pickup' ? selectedRegion : null,
                  pickupCity: deliveryOption == 'pickup' ? selectedCity : null,
                  pickupSite:
                      deliveryOption == 'pickup' ? selectedPickupSite : null,
                );

                print('=== API SAVE RESULT ===');
                print('Success: ${saveResult['success']}');
                print('Message: ${saveResult['message']}');
                print('Data: ${saveResult['data']}');
                print('=======================');

                if (!saveResult['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Warning: ${saveResult['message'] ?? 'Could not save delivery info, but proceeding with order'}'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: EdgeInsets.all(16),
                      duration: Duration(seconds: 3),
                    ),
                  );

                  // Continue with order even if API save fails
                  _proceedToPayment();
                  return;
                }

                // Also save to SharedPreferences for backward compatibility
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userName', _nameController.text.trim());
                await prefs.setString(
                    'userEmail', _emailController.text.trim());
                await prefs.setString('userPhoneNumber', _phoneController.text);
                await prefs.setString('delivery_option', deliveryOption);
                await prefs.setString('order_status', 'Processing');

                // Create delivery address based on option
                String deliveryAddress;
                if (deliveryOption == 'delivery') {
                  await prefs.setString(
                      'userRegion', _regionController.text.trim());
                  await prefs.setString(
                      'userCity', _cityController.text.trim());
                  await prefs.setString(
                      'userAddress', _addressController.text.trim());
                  deliveryAddress =
                      '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_regionController.text.trim()}';
                } else {
                  // For pickup, use the selected pickup location
                  String pickupLocation = selectedPickupSite != null
                      ? '$selectedPickupSite, $selectedCity, $selectedRegion'
                      : '${selectedCity ?? 'Selected'}, ${selectedRegion ?? 'Location'}';
                  deliveryAddress = 'Pickup at $pickupLocation';
                  await prefs.setString('pickup_region', selectedRegion ?? '');
                  await prefs.setString('pickup_city', selectedCity ?? '');
                  await prefs.setString(
                      'pickup_site', selectedPickupSite ?? '');
                }

                await prefs.setString('delivery_address', deliveryAddress);

                // Print saved information for verification
                print('=== Saved Delivery Information ===');
                print('Name: ${_nameController.text.trim()}');
                print('Email: ${_emailController.text.trim()}');
                print('Phone Number: ${_phoneController.text}');
                print('Delivery Option: $deliveryOption');
                print('Shipping Type: $deliveryOption');
                if (deliveryOption == 'delivery') {
                  print('Region: ${_regionController.text.trim()}');
                  print('City: ${_cityController.text.trim()}');
                  print('Address: ${_addressController.text.trim()}');
                } else {
                  print('Pickup Region: ${selectedRegion ?? 'Not selected'}');
                  print('Pickup City: ${selectedCity ?? 'Not selected'}');
                  print('Pickup Site: ${selectedPickupSite ?? 'Not selected'}');
                  print(
                      'Pickup Location: ${selectedPickupSite ?? 'Not selected'}');
                }
                print('Delivery Address: $deliveryAddress');
                print('Order Status: Processing');
                print('API Save Result: ${saveResult['message']}');
                print('===============================');

                // Show success message in the middle of the screen
                OverlayEntry overlayEntry = OverlayEntry(
                  builder: (context) => Positioned(
                    top: MediaQuery.of(context).size.height / 2 - 50,
                    left: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Delivery information saved successfully',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                Overlay.of(context).insert(overlayEntry);

                // Remove the overlay after 2 seconds
                Future.delayed(Duration(seconds: 2), () {
                  overlayEntry.remove();
                });

                // Navigate to payment page with delivery details
                _proceedToPayment();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Warning: Could not save delivery info, but proceeding with order'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.all(16),
                    duration: Duration(seconds: 3),
                  ),
                );

                // Continue with order even if there's an exception
                _proceedToPayment();
              }
            },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CONTINUE TO PAYMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDeliveryOptionChange(String option) {
    _resetHighlights();
    setState(() {
      deliveryOption = option;
    });
  }

  void _proceedToPayment() {
    // Create delivery address based on option
    String deliveryAddress;
    if (deliveryOption == 'delivery') {
      deliveryAddress =
          '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_regionController.text.trim()}';
    } else {
      // For pickup, use the selected pickup location
      String pickupLocation = selectedPickupSite != null
          ? '$selectedPickupSite, $selectedCity, $selectedRegion'
          : '${selectedCity ?? 'Selected'}, ${selectedRegion ?? 'Location'}';
      deliveryAddress = 'Pickup at $pickupLocation';
    }

    // Navigate to payment page with delivery details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          deliveryAddress: deliveryAddress,
          contactNumber: _phoneController.text,
          deliveryOption: deliveryOption,
        ),
      ),
    );
  }
}
