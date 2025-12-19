// pages/delivery_page.dart
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:eclapp/pages/map_picker_page.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  DeliveryPageState createState() => DeliveryPageState();
}

class DeliveryPageState extends State<DeliveryPage> {
  String deliveryOption = 'delivery';
  double deliveryFee = 0.00;
  double? _distanceKm; // actual distance in km from closest store
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // where on the map they picked
  double? _latitude;
  double? _longitude;
  bool _isGeocoding = false;

  // how long delivery will take (from the api)
  String? _apiDeliveryTime;

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

  // data for pickup locations (regions, cities, stores)
  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> stores = [];
  bool isLoadingRegions = false;
  bool isLoadingCities = false;
  bool isLoadingStores = false;

  // cache this stuff so we dont have to load it every time
  final Map<int, List<Map<String, dynamic>>> _citiesCache = {};
  final Map<int, List<Map<String, dynamic>>> _storesCache = {};

  // what they picked for pickup
  Map<String, dynamic>? selectedRegion;
  Map<String, dynamic>? selectedCity;
  Map<String, dynamic>? selectedPickupSite;

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
    _loadRegions(); // load regions when the page starts
  }

  // turn an address into map coordinates
  Future<void> _getCoordinatesFromAddress(String address) async {
    if (address.trim().isEmpty) return;

    setState(() {
      _isGeocoding = true;
    });

    try {
      // Clean the address - remove Google Plus Codes and other problematic characters
      String cleanAddress = address.trim();

      // Remove Google Plus Codes (like HRXF+F4X)
      cleanAddress =
          cleanAddress.replaceAll(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{3}'), '');

      // Remove extra commas and clean up
      cleanAddress = cleanAddress.replaceAll(RegExp(r',+'), ',');
      cleanAddress = cleanAddress.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');

      // add city and region to the address so it works better
      final fullAddress =
          '${cleanAddress}, ${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';

      print('🌍 [GEOCODING] Starting geocoding process...');
      print('📍 [GEOCODING] Original address: "$address"');
      print('📍 [GEOCODING] Cleaned address: "$cleanAddress"');
      print('📍 [GEOCODING] Full address to geocode: "$fullAddress"');
      print('🏙️ [GEOCODING] City: ${_cityController.text.trim()}');
      print('🏛️ [GEOCODING] Region: ${_regionController.text.trim()}');
      print(
          '🔄 [GEOCODING] Previous coordinates: Lat: ${_latitude ?? "None"}, Lng: ${_longitude ?? "None"}');

      final locations = await locationFromAddress(fullAddress);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final oldLat = _latitude;
        final oldLng = _longitude;

        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });

        print('✅ [GEOCODING] SUCCESS! New coordinates obtained:');
        print('   📍 New Latitude: ${_latitude}');
        print('   📍 New Longitude: ${_longitude}');
        print('   📍 New coordinates: (${_latitude}, ${_longitude})');

        // print the geocoding stuff so we can see what we got
        print('🗺️ [MAP COORDINATES] ===== GEOCODING RESPONSE DETAILS =====');
        print('🗺️ [MAP COORDINATES] Location object: $location');
        print('🗺️ [MAP COORDINATES] Latitude: ${location.latitude}');
        print('🗺️ [MAP COORDINATES] Longitude: ${location.longitude}');
        print('🗺️ [MAP COORDINATES] ======================================');

        // Do reverse geocoding to get full address with place name
        await _getAddressFromCoordinates(_latitude!, _longitude!);

        // Fetch delivery time from API with new coordinates
        _fetchDeliveryTimeFromAPI();

        if (oldLat != null && oldLng != null) {
          print('   📍 Previous coordinates: ($oldLat, $oldLng)');
          print(
              '   📍 Coordinates changed: ${oldLat != _latitude || oldLng != _longitude ? "YES" : "NO"}');
        }

        // Also log to debug for Flutter inspector
        debugPrint(
            '✅ Coordinates obtained: Lat: ${_latitude}, Lng: ${_longitude}');
      } else {
        print(
            '⚠️ [GEOCODING] No coordinates found for address: "$fullAddress"');

        // if the full address didnt work, try just city and region
        print('🔄 [GEOCODING] Trying fallback with just city and region...');
        try {
          final fallbackAddress =
              '${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';
          final fallbackLocations = await locationFromAddress(fallbackAddress);

          if (fallbackLocations.isNotEmpty) {
            final location = fallbackLocations.first;
            setState(() {
              _latitude = location.latitude;
              _longitude = location.longitude;
            });
            print(
                '✅ [GEOCODING] Fallback SUCCESS! Using city center coordinates: (${_latitude}, ${_longitude})');

            // Do reverse geocoding to get full address with place name
            await _getAddressFromCoordinates(_latitude!, _longitude!);
          } else {
            print('❌ [GEOCODING] Fallback also failed for: "$fallbackAddress"');
          }
        } catch (fallbackError) {
          print('❌ [GEOCODING] Fallback error: $fallbackError');
        }

        debugPrint('⚠️ No coordinates found for address: $fullAddress');
      }
    } catch (e) {
      print('❌ [GEOCODING] ERROR occurred: $e');
      print('❌ [GEOCODING] Error type: ${e.runtimeType}');

      // try again with just city and region
      print('🔄 [GEOCODING] Trying fallback after error...');
      try {
        final fallbackAddress =
            '${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';
        final fallbackLocations = await locationFromAddress(fallbackAddress);

        if (fallbackLocations.isNotEmpty) {
          final location = fallbackLocations.first;
          setState(() {
            _latitude = location.latitude;
            _longitude = location.longitude;
          });
          print(
              '✅ [GEOCODING] Fallback SUCCESS after error! Using city center: (${_latitude}, ${_longitude})');

          // Do reverse geocoding to get full address with place name
          await _getAddressFromCoordinates(_latitude!, _longitude!);
        }
      } catch (fallbackError) {
        print('❌ [GEOCODING] Fallback also failed: $fallbackError');
      }

      debugPrint('❌ Geocoding error: $e');
    } finally {
      setState(() {
        _isGeocoding = false;
      });
      print('🔄 [GEOCODING] Geocoding process completed');
    }
  }

  Future<void> _loadUserData() async {
    try {
      // load basic user data first so the ui shows up fast
      await _loadBasicUserData();
      // check if theyre logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return;
      }

      // if theyre logged in, get their saved address from the api
      // use a short timeout so it doesnt hang
      try {
        final deliveryResult = await DeliveryService.getLastDeliveryInfo()
            .timeout(const Duration(
                seconds: 8)); // 8 second timeout for faster failure

        if (deliveryResult['success'] &&
            deliveryResult['data'] != null &&
            mounted) {
          final deliveryData = deliveryResult['data'];
          setState(() {
            // fill in the form with their saved address
            _nameController.text = deliveryData['name'] ?? '';
            _emailController.text = deliveryData['email'] ?? '';
            _phoneController.text = deliveryData['phone'] ?? '';

            // set delivery or pickup - use shipping_type if we have it
            deliveryOption = (deliveryData['delivery_option'] ??
                    deliveryData['shipping_type'] ??
                    'delivery')
                .toLowerCase();

            // fill in the delivery address fields
            if (deliveryOption == 'delivery') {
              _regionController.text = deliveryData['region'] ?? '';
              _cityController.text = deliveryData['city'] ?? '';
              _addressController.text = deliveryData['address'] ?? '';
              _updateDeliveryFee();

              // get map coordinates for the address we just filled in
              if (deliveryData['address'] != null &&
                  deliveryData['address'].toString().isNotEmpty) {
                print(
                    '🔄 [PRE-FILL] Address pre-filled, getting coordinates...');
                // wait a tiny bit to make sure all fields are filled
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _getCoordinatesFromAddress(deliveryData['address']);
                  }
                });
              }
            } else if (deliveryOption == 'pickup') {
              selectedRegion = deliveryData['pickup_region'];
              selectedCity = deliveryData['pickup_city'];
              // Use pickup_location as fallback for pickup_site
              selectedPickupSite = deliveryData['pickup_site'] ??
                  deliveryData['pickup_location'];
            }

            // fill in the notes field
            _notesController.text = deliveryData['notes'] ?? '';
          });
        } else {
          if (deliveryResult['message'] != null) {}
        }
      } catch (apiError) {
        // api failed but we already got the basic user data, so its ok
      }
    } catch (e) {
      // if loading failed, just start with empty fields
    }
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
      debugPrint('Error in delivery page: $e');
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

  // scroll to where the error is so they can see it
  void _scrollToError(GlobalKey key, {String? errorType}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (key.currentContext != null && mounted) {
        try {
          Scrollable.ensureVisible(
            key.currentContext!,
            alignment: 0.3, // Slightly higher alignment for better visibility
            duration: Duration(milliseconds: 600), // Slightly longer duration
            curve: Curves.easeInOutCubic, // Smoother curve
          );
        } catch (e) {
          debugPrint('Error scrolling to $errorType: $e');
        }
      }
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // nice header at the top
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
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // header with back button and title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            BackButtonUtils.withConfirmation(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              title: 'Leave Delivery',
                              message:
                                  'Are you sure you want to leave the delivery page? Your information will be saved.',
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
                      // progress bar showing how far they are
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
                              if (deliveryOption == 'pickup')
                                Animate(
                                  key: pickupSectionKey,
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

                              // only show notes field if they chose delivery
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
      bottomNavigationBar: CustomBottomNav(initialIndex: 1),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 50,
      height: 1,
      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 2,
            ),
            shape: BoxShape.circle,
            boxShadow: isCompleted || isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
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
                  color: Colors.black.withValues(alpha: 0.05),
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
                    color: Colors.green.withValues(alpha: 0.1),
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

  Widget _buildPickupForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
            // region dropdown
            _buildPickupDropdown(
              label: 'Select Region',
              value: selectedRegion,
              items: regions.map((region) {
                return DropdownMenuItem(
                  value: region,
                  child: Text(
                    region['description'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
              isLoading: isLoadingRegions,
            ),
            if (selectedRegion != null) ...[
              const SizedBox(height: 16),
              // city dropdown
              _buildPickupDropdown(
                label: 'Select City',
                value: selectedCity,
                items: cities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(
                      city['description'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                isLoading: isLoadingCities,
              ),
            ],
            if (selectedCity != null) ...[
              const SizedBox(height: 16),
              // pickup site dropdown
              _buildPickupDropdown(
                label: 'Select Pickup Site',
                value: selectedPickupSite,
                items: stores.map((store) {
                  return DropdownMenuItem(
                    value: store,
                    child: Text(
                      store['description'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPickupSite = value;
                  });
                },
                isLoading: isLoadingStores,
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
    required Map<String, dynamic>? value,
    required List<DropdownMenuItem<Map<String, dynamic>>> items,
    required Function(Map<String, dynamic>?) onChanged,
    bool isLoading = false,
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
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: _highlightPickupField ? Colors.red : Colors.grey[300]!,
              width: _highlightPickupField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _highlightPickupField ? Colors.red.shade50 : Colors.grey[50],
          ),
          child: DropdownButtonFormField<Map<String, dynamic>>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _highlightPickupField
                                ? Colors.red
                                : (Colors.grey[600] ?? Colors.grey),
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.location_on_outlined,
                      color:
                          _highlightPickupField ? Colors.red : Colors.grey[600],
                    ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text(
              isLoading
                  ? 'Loading...'
                  : (items.isEmpty ? 'No options available' : label),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            items: items,
            onChanged: isLoading
                ? null
                : (Map<String, dynamic>? newValue) {
                    onChanged(newValue);
                    // stop highlighting when they pick something
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
            isExpanded: true,
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            // name, phone, email fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Personal Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // name input field
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
                ],
              ),
            ),

            // Only show location section for delivery option
            if (deliveryOption == 'delivery') ...[
              const SizedBox(height: 20),

              // Location Information Header
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.green[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DELIVERY LOCATION',
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

              // Location Fields Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Map Picker Button - Now at the top as primary method
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade500,
                            Colors.green.shade600
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade300.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showMapPicker(),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Pick Location on Map',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Location Status Display
                    if (_addressController.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Location Confirmed',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _addressController.text,
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
      mainAxisSize: MainAxisSize.min,
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

  // Read-only field for location data from reverse geocoding
  Widget _buildReadOnlyField({
    required GlobalKey key,
    required String label,
    required IconData icon,
    required String value,
    required bool isHighlighted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? Colors.red : Colors.grey[300]!,
              width: isHighlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isHighlighted ? Colors.red.shade50 : Colors.grey[100],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isHighlighted ? Colors.red : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: value.contains('Select location')
                        ? Colors.grey[500]
                        : Colors.grey[800],
                    fontSize: 14,
                    fontStyle: value.contains('Select location')
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fetchDeliveryTimeFromAPI() async {
    if (_latitude == null || _longitude == null) {
      return;
    }

    try {
      print('🚀 [DELIVERY] Fetching delivery time from API...');
      print('   📍 Coordinates: ($_latitude, $_longitude)');

      final result = await DeliveryService.saveDeliveryInfo(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text,
        deliveryOption: 'delivery',
        region: _regionController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        notes: '',
        pickupRegion: null,
        pickupCity: null,
        pickupSite: null,
        lat: _latitude,
        lng: _longitude,
      );

      print('🗺️ [MAP API RESPONSE] ===== COMPLETE API RESPONSE =====');
      print('🗺️ [MAP API RESPONSE] Raw response: $result');
      print('🗺️ [MAP API RESPONSE] Response type: ${result.runtimeType}');
      print('🗺️ [MAP API RESPONSE] Success: ${result['success']}');

      if (result['data'] != null) {
        print('🗺️ [MAP API RESPONSE] Data: ${result['data']}');
      }

      final closestStore = result['closest_store'];

      // If the API gave us a distance like "4.2 km", use that to compute the fee
      if (closestStore != null) {
        final distanceText = closestStore['distance_text']?.toString();
        print('🗺️ [MAP API RESPONSE] Closest store: $closestStore');
        print('🗺️ [MAP API RESPONSE] distance_text: $distanceText');

        if (distanceText != null) {
          final match = RegExp(r'([\d\.]+)').firstMatch(distanceText);
          if (match != null) {
            final parsedKm = double.tryParse(match.group(1)!);
            if (parsedKm != null) {
              final fee =
                  DeliveryService.calculateDeliveryFeeByDistance(parsedKm);
              print(
                  '📦 Calculated delivery fee from actual distance ($parsedKm km): $fee');
              if (mounted) {
                setState(() {
                  deliveryFee = fee;
                  _distanceKm = parsedKm;
                });
              }
            }
          }
        }
      }

      if (result['estimated_delivery_time'] != null &&
          closestStore != null &&
          closestStore['duration_text'] != null) {
        final durationText = closestStore['duration_text'];
        setState(() {
          _apiDeliveryTime = durationText;
        });
      }
    } catch (e) {
      print('❌ [DELIVERY] Error fetching delivery time/fee from API: $e');
    }
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
              '$currentLength/$maxLength',
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
              color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.green.withValues(alpha: 0.3),
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
                _scrollToError(nameSectionKey, errorType: 'name');
              }

              // Validate email
              if (_emailController.text.trim().isEmpty) {
                setState(() {
                  _highlightEmailField = true;
                  isValid = false;
                });
                _scrollToError(emailSectionKey, errorType: 'email');
              } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(_emailController.text.trim())) {
                setState(() {
                  _highlightEmailField = true;
                  isValid = false;
                });
                _scrollToError(emailSectionKey, errorType: 'email');
              }

              // Validate region
              if (deliveryOption == 'delivery' &&
                  _regionController.text.trim().isEmpty) {
                setState(() {
                  _highlightRegionField = true;
                  isValid = false;
                });
                _scrollToError(regionSectionKey, errorType: 'region');
              }

              // Validate city
              if (deliveryOption == 'delivery' &&
                  _cityController.text.trim().isEmpty) {
                setState(() {
                  _highlightCityField = true;
                  isValid = false;
                });
                _scrollToError(citySectionKey, errorType: 'city');
              }

              // Validate address
              if (deliveryOption == 'delivery' &&
                  _addressController.text.trim().isEmpty) {
                setState(() {
                  _highlightAddressField = true;
                  isValid = false;
                });
                _scrollToError(addressSectionKey, errorType: 'address');
              }

              // Validate phone number
              if (_phoneController.text.isEmpty) {
                setState(() {
                  _highlightPhoneField = true;
                  isValid = false;
                });
                _scrollToError(phoneSectionKey, errorType: 'phone');
              } else if (_phoneController.text.length != 10) {
                setState(() {
                  _highlightPhoneField = true;
                  isValid = false;
                });
                _scrollToError(phoneSectionKey, errorType: 'phone');
              }

              // Validate pickup fields
              if (deliveryOption == 'pickup') {
                if (selectedRegion == null ||
                    selectedCity == null ||
                    selectedPickupSite == null) {
                  setState(() {
                    _highlightPickupField = true;
                    isValid = false;
                  });
                  _scrollToError(pickupSectionKey, errorType: 'pickup');
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
                // Always save delivery information to API, even for guests
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
                      (deliveryOption == 'pickup' && selectedRegion != null)
                          ? selectedRegion!['description']
                          : null,
                  pickupCity:
                      (deliveryOption == 'pickup' && selectedCity != null)
                          ? selectedCity!['description']
                          : null,
                  pickupSite:
                      (deliveryOption == 'pickup' && selectedPickupSite != null)
                          ? selectedPickupSite!['description']
                          : null,
                  lat: _latitude,
                  lng: _longitude,
                );

                if (!saveResult['success']) {
                  // Continue with order even if API save fails (removed warning SnackBar)
                  _proceedToPayment();
                  return;
                }

                // Extract delivery time from API response if available
                if (saveResult['closest_store'] != null &&
                    saveResult['closest_store']['duration_text'] != null) {
                  _apiDeliveryTime =
                      saveResult['closest_store']['duration_text'];
                  print(
                      '🚀 [DELIVERY] API delivery time extracted: $_apiDeliveryTime');
                } else {
                  print('⚠️ [DELIVERY] No duration_text found in API response');
                  _apiDeliveryTime = null;
                }

                // Show success message at the top of the screen
                if (mounted) {
                  OverlayEntry overlayEntry = OverlayEntry(
                    builder: (context) => Positioned(
                      top: MediaQuery.of(context).padding.top +
                          16, // Top with safe area padding
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
                                color: Colors.black.withValues(alpha: 0.2),
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
                    if (mounted) {
                      overlayEntry.remove();
                    }
                  });
                }

                // Navigate to payment page with delivery details
                _proceedToPayment();
              } catch (e) {
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
          ? '${selectedPickupSite!['description']}, ${selectedCity!['description']}, ${selectedRegion!['description']}'
          : '${selectedCity?['description'] ?? 'Selected'}, ${selectedRegion?['description'] ?? 'Location'}';
      deliveryAddress = 'Pickup at $pickupLocation';
    }

    // Navigate to payment page with delivery details
    debugPrint(
        '[DEBUG] Passing guestEmail to PaymentPage: "${_emailController.text.trim()}"');

    // Log coordinates being passed to payment page
    if (_latitude != null && _longitude != null) {
      print(
          '🚀 [DELIVERY] ===== EXACT COORDINATES PASSED TO PAYMENT PAGE =====');
      print('🚀 [DELIVERY] 🎯 FINAL COORDINATES FOR PAYMENT:');
      print('   📍 Latitude: $_latitude');
      print('   📍 Longitude: $_longitude');
      print('   📍 Full coordinates: ($_latitude, $_longitude)');
      print(
          '   📍 Coordinates type: ${_latitude.runtimeType}, ${_longitude.runtimeType}');
      print(
          '   📍 Coordinates precision: ${_latitude?.toStringAsFixed(8)}, ${_longitude?.toStringAsFixed(8)}');
      print('🚀 [DELIVERY] ======================================');
    } else {
      print('⚠️ [DELIVERY] No coordinates available to pass to PaymentPage');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          deliveryAddress: deliveryAddress,
          contactNumber: _phoneController.text,
          deliveryOption: deliveryOption,
          guestEmail: _emailController.text.trim(),
          lat: _latitude,
          lng: _longitude,
          estimatedDeliveryTime: _apiDeliveryTime,
          distanceKm: _distanceKm,
          deliveryFee: deliveryFee,
        ),
      ),
    );
  }

  /// Show map picker to select exact location
  void _showMapPicker() async {
    double initialLat = 5.5600; // Default to Accra
    double initialLng = -0.2057;

    // First, try to get fresh coordinates from the current address if available
    if (_addressController.text.trim().isNotEmpty) {
      print('🗺️ [MAP PICKER] ===== STARTING FRESH GEOCODING =====');
      print(
          '🗺️ [MAP PICKER] Current address field text: "${_addressController.text}"');
      print('🗺️ [MAP PICKER] Current city: "${_cityController.text}"');
      print('🗺️ [MAP PICKER] Current region: "${_regionController.text}"');
      print(
          '🗺️ [MAP PICKER] Previous stored coordinates: ($_latitude, $_longitude)');

      try {
        // Clear any old coordinates first
        setState(() {
          _latitude = null;
          _longitude = null;
        });

        // Clean the address - remove Google Plus Codes and other problematic characters
        String cleanAddress = _addressController.text.trim();

        // Remove Google Plus Codes (like HRXF+F4X)
        cleanAddress =
            cleanAddress.replaceAll(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{3}'), '');

        // Remove extra commas and clean up
        cleanAddress = cleanAddress.replaceAll(RegExp(r',+'), ',');
        cleanAddress =
            cleanAddress.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');

        // Get coordinates directly without updating the state first
        final fullAddress =
            '${cleanAddress}, ${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';
        print(
            '🗺️ [MAP PICKER] Original address: "${_addressController.text}"');
        print('🗺️ [MAP PICKER] Cleaned address: "$cleanAddress"');
        print('🗺️ [MAP PICKER] Full address for geocoding: "$fullAddress"');

        final locations = await locationFromAddress(fullAddress);

        if (locations.isNotEmpty) {
          final location = locations.first;
          initialLat = location.latitude;
          initialLng = location.longitude;

          print(
              '🗺️ [MAP PICKER] ✅ SUCCESS! Fresh coordinates obtained: ($initialLat, $initialLng)');

          // Update the state for future use
          setState(() {
            _latitude = initialLat;
            _longitude = initialLng;
          });

          print(
              '🗺️ [MAP PICKER] State updated with new coordinates: ($_latitude, $_longitude)');

          // Fetch delivery time from API with new coordinates
          _fetchDeliveryTimeFromAPI();

          // Force a small delay to ensure iOS processes the coordinate update
          await Future.delayed(const Duration(milliseconds: 200));

          print(
              '🗺️ [MAP PICKER] After delay - coordinates: ($initialLat, $initialLng)');
        } else {
          print(
              '🗺️ [MAP PICKER] ⚠️ No coordinates found for address: "$fullAddress"');
          print('🗺️ [MAP PICKER] Falling back to stored coordinates...');
          // Use stored coordinates if available
          if (_latitude != null && _longitude != null) {
            initialLat = _latitude!;
            initialLng = _longitude!;
            print(
                '🗺️ [MAP PICKER] Using stored coordinates: ($initialLat, $initialLng)');
          }
        }
      } catch (e) {
        print('🗺️ [MAP PICKER] ❌ Error getting coordinates from address: $e');
        print('🗺️ [MAP PICKER] Falling back to stored coordinates...');
        // Use stored coordinates if available
        if (_latitude != null && _longitude != null) {
          initialLat = _latitude!;
          initialLng = _longitude!;
          print(
              '🗺️ [MAP PICKER] Using stored coordinates: ($initialLat, $initialLng)');
        }
      }
    } else {
      // No address entered, use stored coordinates if available
      if (_latitude != null && _longitude != null) {
        initialLat = _latitude!;
        initialLng = _longitude!;
        print(
            '🗺️ [MAP PICKER] No address entered, using stored coordinates: ($initialLat, $initialLng)');
      } else {
        print(
            '🗺️ [MAP PICKER] No address entered, using default coordinates: ($initialLat, $initialLng)');
      }
    }

    print('🗺️ [MAP PICKER] ===== FINAL RESULT =====');
    print(
        '🗺️ [MAP PICKER] Map will open at coordinates: ($initialLat, $initialLng)');
    print('🗺️ [MAP PICKER] ========================');

    // iOS-specific debugging
    print('🗺️ [MAP PICKER] [iOS DEBUG] About to open MapPickerPage with:');
    print('🗺️ [MAP PICKER] [iOS DEBUG] - initialLatitude: $initialLat');
    print('🗺️ [MAP PICKER] [iOS DEBUG] - initialLongitude: $initialLng');
    print(
        '🗺️ [MAP PICKER] [iOS DEBUG] - Data type check: ${initialLat.runtimeType}, ${initialLng.runtimeType}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          onLocationSelected: (double lat, double lng, String? address) {
            setState(() {
              _latitude = lat;
              _longitude = lng;
            });

            print(
                '🗺️ [MAP PICKER] ===== EXACT LOCATION SELECTED FROM MAP =====');
            print('🗺️ [MAP PICKER] 🎯 PRECISE COORDINATES SELECTED:');
            print('   📍 Latitude: $lat');
            print('   📍 Longitude: $lng');
            print('   📍 Full coordinates: ($lat, $lng)');
            print('   📍 Address from map picker: $address');
            print(
                '   📍 Coordinates type: ${lat.runtimeType}, ${lng.runtimeType}');
            print(
                '   📍 Coordinates precision: ${lat.toStringAsFixed(8)}, ${lng.toStringAsFixed(8)}');
            print('🗺️ [MAP PICKER] 📍 STORED IN STATE:');
            print('   📍 Stored Latitude: $_latitude');
            print('   📍 Stored Longitude: $_longitude');
            print('   📍 Stored coordinates: ($_latitude, $_longitude)');
            print('🗺️ [MAP PICKER] ======================================');

            // If address was provided from map picker (from Places API), use it
            // Otherwise, do reverse geocoding
            if (address != null &&
                address.isNotEmpty &&
                address != 'Unknown location' &&
                address != 'Address not found') {
              // Use the address from map picker (which includes the place name from Places API)
              setState(() {
                _addressController.text = address;
              });
              print('🗺️ [MAP PICKER] Using address from map picker: $address');
            } else {
              // Fallback to reverse geocoding if no address provided
              _getAddressFromCoordinates(lat, lng);
            }
          },
        ),
      ),
    );
  }

  /// Get address from coordinates using reverse geocoding
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      print(
          '🔄 [REVERSE GEOCODING] Getting address from coordinates: ($lat, $lng)');

      final placemarks = await placemarkFromCoordinates(lat, lng);

      // 🗺️ [REVERSE GEOCODING RESPONSE] Log the complete response
      print('🗺️ [REVERSE GEOCODING RESPONSE] ===== COMPLETE RESPONSE =====');
      print('🗺️ [REVERSE GEOCODING RESPONSE] Raw placemarks: $placemarks');
      print(
          '🗺️ [REVERSE GEOCODING RESPONSE] Placemarks count: ${placemarks.length}');

      if (placemarks.isNotEmpty) {
        // Try to pick the most human-friendly placemark:
        // prefer one whose name looks like a real place (e.g. "Stanbic Heights")
        // instead of a plus code like "HRXF+F4X" or just numbers like "3".
        Placemark placemark = placemarks.first;
        for (final p in placemarks) {
          if (_isValidPlaceName(p.name)) {
            placemark = p;
            break;
          }
        }

        // Log detailed placemark information
        print('🗺️ [REVERSE GEOCODING RESPONSE] First placemark: $placemark');
        print('🗺️ [REVERSE GEOCODING RESPONSE] Street: ${placemark.street}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Sub-locality: ${placemark.subLocality}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Locality: ${placemark.locality}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Administrative area: ${placemark.administrativeArea}');
        print('🗺️ [REVERSE GEOCODING RESPONSE] Country: ${placemark.country}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Postal code: ${placemark.postalCode}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] ISO country code: ${placemark.isoCountryCode}');
        print('🗺️ [REVERSE GEOCODING RESPONSE] Name: ${placemark.name}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Thoroughfare: ${placemark.thoroughfare}');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] Sub-thoroughfare: ${placemark.subThoroughfare}');

        // Build a readable address prioritizing place name
        final address = _buildReadableAddressFromPlacemark(placemark);

        print('✅ [REVERSE GEOCODING] Address found: $address');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] ======================================');

        // Update all location fields with the found data from reverse geocoding
        if (mounted) {
          setState(() {
            // Update region with administrative area
            if (placemark.administrativeArea != null &&
                placemark.administrativeArea!.isNotEmpty) {
              _regionController.text = placemark.administrativeArea!;
              print(
                  '🗺️ [REVERSE GEOCODING] Updated region: ${placemark.administrativeArea}');
            }

            // Update city with locality
            if (placemark.locality != null && placemark.locality!.isNotEmpty) {
              _cityController.text = placemark.locality!;
              print(
                  '🗺️ [REVERSE GEOCODING] Updated city: ${placemark.locality}');
            }

            // Update address field with the readable address
            _addressController.text = address.trim();
            print('🗺️ [REVERSE GEOCODING] Updated address: $address');

            // Update delivery fee since region/city changed
            _updateDeliveryFee();
          });
        }
      } else {
        print(
            '⚠️ [REVERSE GEOCODING] No address found for coordinates: ($lat, $lng)');
        print(
            '🗺️ [REVERSE GEOCODING RESPONSE] ======================================');
      }
    } catch (e) {
      print('❌ [REVERSE GEOCODING] Error: $e');
      print('❌ [REVERSE GEOCODING] Error type: ${e.runtimeType}');
      print(
          '🗺️ [REVERSE GEOCODING RESPONSE] ======================================');
    }
  }

  /// Check if a name looks like a real place name (not a Plus Code or just numbers)
  bool _isValidPlaceName(String? name) {
    if (name == null || name.isEmpty) return false;

    final trimmed = name.trim();

    // Reject Plus Codes (e.g., "HRXF+F4X") - they have + and are short alphanumeric
    if (trimmed.contains('+') &&
        trimmed.length <= 15 &&
        RegExp(r'^[A-Z0-9]+\+[A-Z0-9]+$').hasMatch(trimmed)) {
      return false;
    }

    // Reject if it's just numbers (but allow numbers with letters like "3rd Street")
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;

    // Reject very short names (but allow 3+ characters)
    if (trimmed.length < 3) return false;

    // Must contain at least one letter to be a real place name
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) return false;

    return true;
  }

  /// Build a readable address from placemark, combining multiple components
  /// Returns a complete address string with place name, street number, and street name
  String _buildReadableAddressFromPlacemark(Placemark placemark) {
    List<String> addressParts = [];
    String? placeName;

    // Get place name first if available and valid
    if (_isValidPlaceName(placemark.name)) {
      placeName = placemark.name;
    }

    // Add sub-thoroughfare (street number) if available
    if (placemark.subThoroughfare != null &&
        placemark.subThoroughfare!.isNotEmpty &&
        placemark.subThoroughfare != placeName) {
      addressParts.add(placemark.subThoroughfare!);
    }

    // Add thoroughfare (street name) if available
    if (placemark.thoroughfare != null &&
        placemark.thoroughfare!.isNotEmpty &&
        placemark.thoroughfare != placeName) {
      addressParts.add(placemark.thoroughfare!);
    }

    // Build the address: place name first, then street address
    if (placeName != null && addressParts.isNotEmpty) {
      String streetAddress = addressParts.join(' ');
      // Only add place name if it's not already in the street address
      if (!streetAddress.toLowerCase().contains(placeName.toLowerCase())) {
        return '$placeName, $streetAddress';
      }
      return '$placeName, $streetAddress';
    }

    // If we have street components but no place name, use street address
    if (addressParts.isNotEmpty) {
      return addressParts.join(' ');
    }

    // If we have place name but no street, use place name
    if (placeName != null) {
      return placeName;
    }

    // Fallback: Use street if available
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      return placemark.street!;
    }

    // Fallback: Use sub-locality (neighborhood/area)
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      return placemark.subLocality!;
    }

    // Fallback: Use locality (city)
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      return placemark.locality!;
    }

    // Fallback: Use administrative area (region)
    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      return placemark.administrativeArea!;
    }

    // Fallback: Return unknown if nothing is available
    return 'Unknown location';
  }

  /// Load regions from API
  Future<void> _loadRegions() async {
    if (!mounted) return;
    setState(() {
      isLoadingRegions = true;
    });

    try {
      final result = await DeliveryService.getRegions()
          .timeout(const Duration(seconds: 5)); // Reduced timeout
      if (result['success'] && mounted) {
        if (!mounted) return;
        try {
          setState(() {
            // Deduplicate regions by description to prevent dropdown errors
            final rawRegions = List<Map<String, dynamic>>.from(result['data']);
            final uniqueRegions = <String, Map<String, dynamic>>{};

            print('🔍 [REGIONS] Processing ${rawRegions.length} raw regions');

            for (final region in rawRegions) {
              try {
                final description = region['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueRegions.containsKey(description)) {
                  uniqueRegions[description] = region;
                } else if (description.isNotEmpty) {
                  print(
                      '⚠️ [REGIONS] Duplicate region description found: "$description"');
                }
              } catch (e) {
                print('⚠️ [REGIONS] Error processing region: $e');
                continue;
              }
            }

            final allRegions = uniqueRegions.values.toList();

            // Filter to only show Greater Accra, Ashanti, and Western regions
            final allowedRegionNames = [
              'greater accra',
              'ashanti',
              'western',
              'accra', // Also allow "Accra" as it might be named differently
            ];

            final filteredRegions = allRegions.where((region) {
              final regionName =
                  (region['description'] ?? '').toString().toLowerCase().trim();
              final isAllowed = allowedRegionNames
                  .any((allowed) => regionName.contains(allowed));

              if (!isAllowed) {
                print(
                    '❌ [REGIONS] Region filtered out: "$regionName" (original: "${region['description']}")');
              } else {
                print(
                    '✅ [REGIONS] Region allowed: "$regionName" (original: "${region['description']}")');
              }

              return isAllowed;
            }).toList();

            regions = filteredRegions;
            print(
                '✅ [REGIONS] Filtered to ${regions.length} regions (from ${allRegions.length} total)');
            print(
                '📋 [REGIONS] Allowed regions: ${regions.map((r) => r['description']).toList()}');
            isLoadingRegions = false;

            // Validate pre-filled region value after regions are loaded
            if (_regionController.text.isNotEmpty) {
              final regionExists = regions
                  .any((r) => r['description'] == _regionController.text);
              if (!regionExists) {
                // Clear invalid region value to prevent dropdown errors
                _regionController.clear();
                print(
                    '⚠️ [REGIONS] Pre-filled region "${_regionController.text}" not found in regions list, cleared');
              }
            }
          });
        } catch (e) {
          print('❌ [REGIONS] Error setting regions state: $e');
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
          .timeout(const Duration(seconds: 3)); // Faster timeout
      if (result['success'] && mounted) {
        final citiesData = List<Map<String, dynamic>>.from(result['data']);
        if (!mounted) return;
        try {
          setState(() {
            // Deduplicate cities by description to prevent dropdown errors
            final uniqueCities = <String, Map<String, dynamic>>{};

            print('🔍 [CITIES] Processing ${citiesData.length} raw cities');

            for (final city in citiesData) {
              try {
                final description = city['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueCities.containsKey(description)) {
                  uniqueCities[description] = city;
                } else if (description.isNotEmpty) {
                  print(
                      '⚠️ [CITIES] Duplicate city description found: "$description"');
                }
              } catch (e) {
                print('⚠️ [CITIES] Error processing city: $e');
                continue;
              }
            }

            cities = uniqueCities.values.toList();
            print('✅ [CITIES] Deduplicated to ${cities.length} unique cities');
            _citiesCache[regionId] =
                uniqueCities.values.toList(); // Cache the deduplicated result
            isLoadingCities = false;

            // Validate pre-filled city value after cities are loaded
            if (_cityController.text.isNotEmpty) {
              final cityExists =
                  cities.any((c) => c['description'] == _cityController.text);
              if (!cityExists) {
                // Clear invalid city value to prevent dropdown errors
                _cityController.clear();
                print(
                    '⚠️ [CITIES] Pre-filled city "${_cityController.text}" not found in cities list, cleared');
              }
            }
          });
        } catch (e) {
          print('❌ [CITIES] Error setting cities state: $e');
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
          .timeout(const Duration(seconds: 3)); // Faster timeout
      if (result['success'] && mounted) {
        final storesData = List<Map<String, dynamic>>.from(result['data']);
        if (!mounted) return;
        try {
          setState(() {
            // Deduplicate stores by description to prevent dropdown errors
            final uniqueStores = <String, Map<String, dynamic>>{};

            print('🔍 [STORES] Processing ${storesData.length} raw stores');

            for (final store in storesData) {
              try {
                final description = store['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueStores.containsKey(description)) {
                  uniqueStores[description] = store;
                } else if (description.isNotEmpty) {
                  print(
                      '⚠️ [STORES] Duplicate store description found: "$description"');
                }
              } catch (e) {
                print('⚠️ [STORES] Error processing store: $e');
                continue;
              }
            }

            stores = uniqueStores.values.toList();
            print('✅ [STORES] Deduplicated to ${stores.length} unique stores');
            _storesCache[cityId] =
                uniqueStores.values.toList(); // Cache the deduplicated result
            isLoadingStores = false;

            // Validate pre-filled pickup site value after stores are loaded
            if (selectedPickupSite != null) {
              final storeExists =
                  stores.any((s) => s['id'] == selectedPickupSite!['id']);
              if (!storeExists) {
                // Clear invalid pickup site value to prevent dropdown errors
                selectedPickupSite = null;
                print(
                    '⚠️ [STORES] Pre-filled pickup site not found in stores list, cleared');
              }
            }
          });
        } catch (e) {
          print('❌ [STORES] Error setting stores state: $e');
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
