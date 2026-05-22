// pages/delivery_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bottomnav.dart';
import '../providers/cart_provider.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:eclapp/pages/map_picker_page.dart';
import '../widgets/checkout_progress_stepper.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  DeliveryPageState createState() => DeliveryPageState();
}

class DeliveryPageState extends State<DeliveryPage> {
  bool _isNavigatingToNextPage = false;

  Future<T?> _pushPageOnce<T>(Route<T> route) async {
    if (!mounted || _isNavigatingToNextPage) return null;
    _isNavigatingToNextPage = true;
    try {
      return await Navigator.push<T>(context, route);
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 250));
        _isNavigatingToNextPage = false;
      }
    }
  }

  void _onAddressFieldsChanged() {
    // Only trigger if all fields are non-empty
    if (_regionController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty) {
      _updateDeliveryFee();
    }
  }

  String deliveryOption = 'delivery';
  double deliveryFee = 0.00;
  double? _distanceKm; // actual distance in km from closest store
  bool _isUpdatingDeliveryFee = false;
  bool _isProceedingToPayment = false;
  int _feeUpdateGeneration = 0;
  Future<void>? _activeDeliveryFeeRefresh;
  List<Map<String, dynamic>> _distanceStores = [];
  Future<void>? _distanceStoresLoad;
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

  /// Last server [distance_text] we priced — skips duplicate calculate-delivery-fee calls.
  String? _lastFeeDistanceText;

  String? _cachedBillingRegionLabel;
  String? _cachedBillingCityLabel;
  int? _cachedBillingRegionId;
  int? _cachedBillingCityId;

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

  bool _isOrderUrgent = false;
  bool _isUrgentFeeLoading = false;
  double? _emergencyOrderFee;

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
    _regionController.removeListener(_onAddressFieldsChanged);
    _cityController.removeListener(_onAddressFieldsChanged);
    _addressController.removeListener(_onAddressFieldsChanged);
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
    _preloadDistanceStores();
  }

  void _preloadDistanceStores() {
    _distanceStoresLoad ??= DeliveryService.getAllStores().then((result) {
      if (result['success'] == true && result['data'] is List) {
        _distanceStores = List<Map<String, dynamic>>.from(result['data']);
      }
    });
  }

  Future<List<Map<String, dynamic>>> _ensureDistanceStores() async {
    _preloadDistanceStores();
    await _distanceStoresLoad;
    return _distanceStores;
  }

  /// Applies fee from cached stores synchronously (map pick / coords already set).
  bool _tryApplyInstantDeliveryFee(double lat, double lng) {
    if (deliveryOption == 'pickup' || _distanceStores.isEmpty) return false;

    final localEstimate = DeliveryService.estimateFeeFromCoordinates(
      lat: lat,
      lng: lng,
      stores: _distanceStores,
    );
    if (localEstimate == null) return false;

    final fee = localEstimate['delivery_fee'];
    if (fee is! num) return false;

    deliveryFee = fee.toDouble();
    final km = localEstimate['distance_km'];
    if (km is num) _distanceKm = km.toDouble();
    _isUpdatingDeliveryFee = false;
    return true;
  }

  /// Local estimate after stores load (when cache was empty on map pick).
  Future<bool> _applyLocalDeliveryFeeEstimate(
    double lat,
    double lng, {
    required int generation,
  }) async {
    if (deliveryOption == 'pickup' || !mounted) return false;
    if (generation != _feeUpdateGeneration) return false;

    final stores = await _ensureDistanceStores();
    if (!mounted || generation != _feeUpdateGeneration) return false;

    final localEstimate = DeliveryService.estimateFeeFromCoordinates(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    if (localEstimate == null) return false;

    final fee = localEstimate['delivery_fee'];
    if (fee is! num) return false;

    setState(() {
      deliveryFee = fee.toDouble();
      final km = localEstimate['distance_km'];
      if (km is num) _distanceKm = km.toDouble();
      _isUpdatingDeliveryFee = false;
    });
    return true;
  }

  Future<void> _runDeliveryFeeRefresh(
    double lat,
    double lng,
    int generation,
  ) async {
    try {
      if (!_tryApplyInstantDeliveryFee(lat, lng)) {
        await _applyLocalDeliveryFeeEstimate(
          lat,
          lng,
          generation: generation,
        );
      } else if (mounted && generation == _feeUpdateGeneration) {
        setState(() {});
      }

      // Refine ETA/fee via save-billing without hiding an already-shown fee.
      await _syncDeliveryAddressToServer(generation);
    } catch (e) {
      debugPrint('❌ [DELIVERY] Fee refresh error: $e');
      await _syncDeliveryAddressToServer(generation);
    } finally {
      if (mounted && generation == _feeUpdateGeneration) {
        setState(() => _isUpdatingDeliveryFee = false);
      }
    }
  }

  /// Updates delivery fee immediately from map coords, then refines via API.
  Future<void> _refreshDeliveryFeeForCoordinates(double lat, double lng) async {
    if (deliveryOption == 'pickup' || !mounted) return;

    final generation = ++_feeUpdateGeneration;

    if (!_tryApplyInstantDeliveryFee(lat, lng) && deliveryFee <= 0) {
      setState(() => _isUpdatingDeliveryFee = true);
    } else if (mounted) {
      setState(() {});
    }

    final refresh = _runDeliveryFeeRefresh(lat, lng, generation);
    _activeDeliveryFeeRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (_activeDeliveryFeeRefresh == refresh) {
        _activeDeliveryFeeRefresh = null;
      }
    }
  }

  Future<void> _syncDeliveryAddressToServer(int generation) async {
    await _safelyCallDeliveryAPI(
      generation: generation,
      skipFeeWhenAlreadySet: false,
    );
  }

  String? _distanceTextFromSaveResult(Map<String, dynamic> result) {
    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    final text = closestStore?['distance_text']?.toString() ??
        result['distance_text']?.toString() ??
        result['data']?['distance_text']?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text.trim();
  }

  /// Applies ETA and delivery fee from a save-billing-add response.
  Future<void> _applySaveBillingSideEffects(Map<String, dynamic> result) async {
    if (result['success'] != true || !mounted) return;

    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    if (closestStore != null && closestStore['duration_text'] != null) {
      setState(() {
        _apiDeliveryTime = closestStore['duration_text']?.toString();
      });
    }

    if (deliveryOption != 'delivery') return;

    final distanceText = _distanceTextFromSaveResult(result);
    if (distanceText == null) return;

    if (distanceText == _lastFeeDistanceText && deliveryFee > 0) {
      debugPrint(
          '📦 [DELIVERY] Fee unchanged for distance "$distanceText", skipping fee API');
      return;
    }

    await _applyDeliveryFeeFromDistanceText(distanceText);
  }

  /// Fetches authoritative fee from /calculate-delivery-fee using server distance.
  Future<double?> _applyDeliveryFeeFromDistanceText(String distanceText) async {
    final trimmed = distanceText.trim();
    if (trimmed.isEmpty) return null;

    Map<String, dynamic>? feeResult =
        await DeliveryService.fetchDeliveryFeeFromApi(distanceText: trimmed);

    double? feeValue;
    double? distanceKm;

    if (feeResult != null) {
      final rawFee = feeResult['delivery_fee'];
      final rawDist = feeResult['distance'];
      if (rawFee is num) feeValue = rawFee.toDouble();
      if (rawDist is num) distanceKm = rawDist.toDouble();
    } else {
      final local =
          DeliveryService.calculateDeliveryFeeFromDistanceText(trimmed);
      if (local != null) {
        feeValue = local['fee'];
        distanceKm = local['distanceKm'];
      }
    }

    if (!mounted || feeValue == null) return null;

    double? resolvedFee;
    setState(() {
      deliveryFee = feeValue!;
      resolvedFee = deliveryFee;
      _lastFeeDistanceText = trimmed;
      if (distanceKm != null) {
        _distanceKm = distanceKm;
      }
    });
    return resolvedFee;
  }

  /// Ensures [deliveryFee] is set before payment without extra save/refresh cycles.
  Future<double> _ensureDeliveryFeeForPayment({
    Map<String, dynamic>? saveResult,
  }) async {
    if (deliveryOption == 'pickup') return 0;

    final pendingRefresh = _activeDeliveryFeeRefresh;
    if (pendingRefresh != null) {
      await pendingRefresh;
    }

    if (saveResult != null) {
      await _applySaveBillingSideEffects(saveResult);
    }
    if (deliveryFee > 0) return deliveryFee;

    if (_latitude != null && _longitude != null) {
      await _safelyCallDeliveryAPI(skipFeeWhenAlreadySet: false);
    }

    return deliveryFee;
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

        unawaited(
          _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!),
        );
        await _getAddressFromCoordinates(_latitude!, _longitude!);

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

            unawaited(
              _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!),
            );
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

          unawaited(
            _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!),
          );
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

      // Get saved address from API (works for both logged-in and guest users)
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
    // Only proceed if all fields are non-empty
    final region = _regionController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    if (region.isEmpty || city.isEmpty || address.isEmpty) {
      return;
    }
    // Start geocoding and fee calculation
    _getCoordinatesFromAddress(address);
  }

  int? _idFromLocationMap(Map<String, dynamic>? value) {
    if (value == null) return null;
    final id = int.tryParse(value['id']?.toString() ?? '');
    if (id == null || id <= 0) return null;
    return id;
  }

  /// Resolve backend region/city/store ids (save-billing-add expects numeric ids).
  Future<({int? regionId, int? cityId, int? storeId})>
      _resolveBillingLocationIds() async {
    if (deliveryOption == 'pickup') {
      return (
        regionId: _idFromLocationMap(selectedRegion),
        cityId: _idFromLocationMap(selectedCity),
        storeId: _idFromLocationMap(selectedPickupSite),
      );
    }

    final regionLabel = _regionController.text.trim();
    final cityLabel = _cityController.text.trim();
    if (regionLabel.isEmpty) {
      return (regionId: null, cityId: null, storeId: null);
    }

    if (_cachedBillingRegionId != null &&
        _cachedBillingRegionLabel == regionLabel &&
        _cachedBillingCityLabel == cityLabel) {
      return (
        regionId: _cachedBillingRegionId,
        cityId: _cachedBillingCityId,
        storeId: null,
      );
    }

    final regionRows =
        regions.map((e) => Map<String, dynamic>.from(e)).toList();
    final regionMatch =
        DeliveryService.findRegionInList(regionRows, regionLabel);
    final regionId = _idFromLocationMap(
      regionMatch != null ? Map<String, dynamic>.from(regionMatch) : null,
    );
    if (regionId == null) {
      return (regionId: null, cityId: null, storeId: null);
    }

    int? cityId;
    if (cityLabel.isNotEmpty) {
      final cityMatch =
          await DeliveryService.findCityInRegion(regionId, cityLabel);
      cityId = _idFromLocationMap(
        cityMatch != null ? Map<String, dynamic>.from(cityMatch) : null,
      );
    }

    _cachedBillingRegionLabel = regionLabel;
    _cachedBillingCityLabel = cityLabel;
    _cachedBillingRegionId = regionId;
    _cachedBillingCityId = cityId;

    return (regionId: regionId, cityId: cityId, storeId: null);
  }

  void _invalidateBillingLocationCache() {
    _cachedBillingRegionLabel = null;
    _cachedBillingCityLabel = null;
    _cachedBillingRegionId = null;
    _cachedBillingCityId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Stack(
        children: [
          Column(
            children: [
              // Header - green gradient with title and progress steps
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: const Offset(0, 0.1),
                      end: Offset.zero)
                ],
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        // Progress steps
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                          child: const CheckoutProgressStepper(
                            steps: ['Cart', 'Delivery', 'Payment', 'Confirmation'],
                            activeStep: 2,
                            completedSteps: {1},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
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
                          const SizedBox(height: 10),
                          if (deliveryOption == 'delivery') ...[
                            _buildUrgentOption(),
                            const SizedBox(height: 20),
                          ],
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
                          Selector<CartProvider, double>(
                            selector: (_, cart) =>
                                CartProvider.selectSubtotal(cart),
                            builder: (context, subtotal, _) {
                              return Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: _buildOrderSummary(subtotal: subtotal),
                              );
                            },
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
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 1),
    );
  }

  static const double _cardRadius = 18;
  static const double _fieldRadius = 12;
  static const Color _cardShadow = Color(0x0A000000);
  static const Color _accent = Color(0xFF2E7D32);

  Widget _buildDeliveryOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('How do you want to receive your order?',
              compact: false),
          const SizedBox(height: 10),
          // Segmented control
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDeliveryOptionChip(
                    label: 'Delivery',
                    icon: Icons.home_rounded,
                    isSelected: deliveryOption == 'delivery',
                    onTap: () => _handleDeliveryOptionChange('delivery'),
                  ),
                ),
                Expanded(
                  child: _buildDeliveryOptionChip(
                    label: 'Pickup',
                    icon: Icons.store_rounded,
                    isSelected: deliveryOption == 'pickup',
                    onTap: () => _handleDeliveryOptionChange('pickup'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, {bool compact = false}) {
    return Row(
      children: [
        Container(
          width: compact ? 3 : 4,
          height: compact ? 14 : 18,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 14,
              height: compact ? 1.2 : null,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickupForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Pickup location'),
          const SizedBox(height: 14),
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
                final regionId =
                    int.tryParse(value['id']?.toString() ?? '') ?? 0;
                if (regionId > 0) {
                  _loadCities(regionId);
                }
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
                  final cityId =
                      int.tryParse(value['id']?.toString() ?? '') ?? 0;
                  if (cityId > 0) {
                    _loadStores(cityId);
                  }
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
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please select region, city and pickup site',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(_fieldRadius),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pickup stations are open till 7pm, Monday to Saturday. Closed on Sundays.',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                color:
                    _highlightPickupField ? Colors.red : Colors.grey.shade700,
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
              color: _highlightPickupField ? Colors.red : Colors.grey.shade300,
              width: _highlightPickupField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(_fieldRadius),
            color: _highlightPickupField
                ? Colors.red.shade50
                : Colors.grey.shade50,
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
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.location_on_rounded,
                      color: _highlightPickupField
                          ? Colors.red
                          : Colors.grey.shade600,
                      size: 22,
                    ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            hint: Text(
              isLoading
                  ? 'Loading...'
                  : (items.isEmpty ? 'No options available' : label),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
            items: items,
            onChanged: isLoading
                ? null
                : (Map<String, dynamic>? newValue) {
                    onChanged(newValue);
                    if (_highlightPickupField) {
                      setState(() {
                        _highlightPickupField = false;
                      });
                    }
                  },
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _highlightPickupField ? Colors.red : Colors.grey.shade600,
            ),
            style: TextStyle(
              color: Colors.grey.shade800,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionLabel('Contact & address'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(_fieldRadius),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Personal details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

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
                  autofillHints: const [AutofillHints.email],
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
            const SizedBox(height: 16),
            Text(
              'Delivery location',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              key: addressSectionKey,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (_highlightRegionField ||
                        _highlightCityField ||
                        _highlightAddressField)
                    ? Colors.red.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(
                  color: (_highlightRegionField ||
                          _highlightCityField ||
                          _highlightAddressField)
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
                  width: (_highlightRegionField ||
                          _highlightCityField ||
                          _highlightAddressField)
                      ? 2
                      : 1,
                ),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showMapPicker(),
                      borderRadius: BorderRadius.circular(_fieldRadius),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(_fieldRadius),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Pick location on map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_addressController.text.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_fieldRadius),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: _accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Location confirmed',
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _addressController.text,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
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
    List<String>? autofillHints,
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
                fontSize: 13,
                color: isHighlighted ? Colors.red : Colors.grey.shade700,
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
          autofillHints: autofillHints,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isHighlighted ? Colors.red : Colors.grey.shade600,
              size: 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey.shade300,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey.shade300,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : _accent,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isHighlighted ? Colors.red.shade50 : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

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
                fontSize: 13,
                color: isHighlighted ? Colors.red : Colors.grey.shade700,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? Colors.red : Colors.grey.shade300,
              width: isHighlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(_fieldRadius),
            color: isHighlighted ? Colors.red.shade50 : Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isHighlighted ? Colors.red : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: value.contains('Select location')
                        ? Colors.grey.shade500
                        : Colors.grey.shade800,
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
    if (_latitude == null || _longitude == null || !mounted) return;
    await _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!);
  }

  Future<bool> _safelyCallDeliveryAPI({
    int? generation,
    bool skipFeeWhenAlreadySet = false,
  }) async {
    try {
      if (!mounted) return false;

      // Collect data first (before any async operations)
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text;
      final region = _regionController.text.trim();
      final city = _cityController.text.trim();
      final address = _addressController.text.trim();
      final lat = _latitude;
      final lng = _longitude;

      print('📤 Calling DeliveryService.saveDeliveryInfo...');

      final locationIds = await _resolveBillingLocationIds();

      final result = await DeliveryService.saveDeliveryInfo(
        name: name,
        email: email,
        phone: phone,
        deliveryOption: 'delivery',
        region: region,
        city: city,
        address: address,
        notes: '',
        pickupRegion: null,
        pickupCity: null,
        pickupSite: null,
        regionId: locationIds.regionId,
        cityId: locationIds.cityId,
        storeId: locationIds.storeId,
        lat: lat,
        lng: lng,
      );

      if (!mounted) {
        print('⚠️ Widget disposed, ignoring API result');
        return false;
      }

      print('📦 API Response received');
      print(json.encode(result));

      final wasSuccessful = result['success'] == true;
      if (!wasSuccessful) {
        final errorMessage = (result['message'] ?? 'Failed to save delivery information')
            .toString();
        print('❌ [DELIVERY] Save failed: $errorMessage');
        return false;
      }

      if (!skipFeeWhenAlreadySet &&
          mounted &&
          (generation == null || generation == _feeUpdateGeneration)) {
        await _applySaveBillingSideEffects(Map<String, dynamic>.from(result));
      } else if (mounted &&
          (generation == null || generation == _feeUpdateGeneration)) {
        final closestStore =
            result['closest_store'] ?? result['data']?['closest_store'];
        if (closestStore != null && closestStore['duration_text'] != null) {
          setState(() {
            _apiDeliveryTime = closestStore['duration_text']?.toString();
          });
        }
      }

      return true;
    } catch (e) {
      print('❌ Error in API call: $e');
      return false;
    }
  }

  Widget _buildPhoneField(bool isPhoneValid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phone number',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade700,
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
                color:
                    currentLength == maxLength ? _accent : Colors.grey.shade500,
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
                  Text('🇬🇭', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 4),
                  Text('+233', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade300,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade300,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : _accent,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                _highlightPhoneField ? Colors.red.shade50 : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            errorText: isPhoneValid ? null : 'Phone number must be 10 digits',
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: _cardShadow,
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
              Expanded(
                child: _buildSectionLabel('Delivery notes'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'e.g. gate code, landmarks, or special instructions',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_fieldRadius),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_fieldRadius),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_fieldRadius),
                borderSide: BorderSide(color: _accent, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentOption() {
    final isOn = _isOrderUrgent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (_isUrgentFeeLoading) return;
            setState(() {
              _isUrgentFeeLoading = true;
            });
            if (!_isOrderUrgent) {
              // Only call API when toggling ON
              final result = await DeliveryService.addXpressFee();
              if (result != null && result['xpress_fee'] != null) {
                setState(() {
                  _emergencyOrderFee = (result['xpress_fee'] is num)
                      ? (result['xpress_fee'] as num).toDouble()
                      : double.tryParse(result['xpress_fee'].toString());
                });
              } else {
                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Failed to add urgent delivery fee.'),
                          SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swipe_down_alt_rounded,
                                  color: Colors.white70, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Swipe down to dismiss',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      dismissDirection: DismissDirection.down,
                      showCloseIcon: true,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            } else {
              setState(() {
                _emergencyOrderFee = null;
              });
            }
            setState(() {
              _isOrderUrgent = !_isOrderUrgent;
              _isUrgentFeeLoading = false;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isOn ? Colors.red.withOpacity(0.06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isOn ? Colors.red.withOpacity(0.35) : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOn ? Icons.flash_on : Icons.flash_on_outlined,
                  color: isOn ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOn ? 'Urgent order' : 'Urgent or emergency',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOn ? Colors.red : Colors.black,
                        ),
                      ),
                      Text(
                        isOn
                            ? 'We will prioritize your order.'
                            : 'Tap to mark as urgent',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isUrgentFeeLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isOn)
                  const Icon(Icons.check_circle, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary({required double subtotal}) {
    final emergencyOrderFee = _emergencyOrderFee ?? 0.0;
    final effectiveDeliveryFee = deliveryOption == 'pickup' ? 0.0 : deliveryFee;
    final total = subtotal + effectiveDeliveryFee + emergencyOrderFee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Order summary'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(_fieldRadius),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', subtotal,
                    icon: Icons.shopping_cart_rounded),
                if (deliveryOption == 'delivery') ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Delivery fee',
                    effectiveDeliveryFee,
                    icon: Icons.local_shipping_rounded,
                    isLoading:
                        _isUpdatingDeliveryFee && effectiveDeliveryFee <= 0,
                  ),
                ],
                if (emergencyOrderFee > 0) ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow('Emergency Order Fee', emergencyOrderFee,
                      icon: Icons.flash_on),
                ],
                Divider(height: 28, thickness: 1, color: Colors.grey.shade300),
                _buildSummaryRow('Total', total,
                    isHighlighted: true, icon: Icons.payment_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isHighlighted = false,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: isHighlighted ? _accent : Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              fontSize: isHighlighted ? 15 : 14,
              color:
                  isHighlighted ? Colors.grey.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
              fontSize: isHighlighted ? 17 : 14,
              color: isHighlighted ? _accent : Colors.grey.shade800,
            ),
          ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(_fieldRadius),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_fieldRadius),
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
            } else if (!RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(_emailController.text.trim())) {
              setState(() {
                _highlightEmailField = true;
                isValid = false;
              });
              _scrollToError(emailSectionKey, errorType: 'email');
            }

            // Validate delivery location (region, city, address - all from map picker)
            if (deliveryOption == 'delivery' &&
                (_regionController.text.trim().isEmpty ||
                    _cityController.text.trim().isEmpty ||
                    _addressController.text.trim().isEmpty)) {
              setState(() {
                _highlightRegionField = true;
                _highlightCityField = true;
                _highlightAddressField = true;
                isValid = false;
              });
              _scrollToError(addressSectionKey, errorType: 'delivery location');
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
              // Build specific message so user knows what to fix
              String message = 'Please fix the following: ';
              final missing = <String>[];
              if (_nameController.text.trim().isEmpty) missing.add('name');
              if (_emailController.text.trim().isEmpty ||
                  !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(_emailController.text.trim())) {
                missing.add('email');
              }
              if (_phoneController.text.isEmpty ||
                  _phoneController.text.length != 10) {
                missing.add('phone (10 digits)');
              }
              if (deliveryOption == 'delivery') {
                if (_addressController.text.trim().isEmpty ||
                    _regionController.text.trim().isEmpty ||
                    _cityController.text.trim().isEmpty) {
                  missing.add('delivery address (tap "Pick location on map")');
                }
              }
              if (deliveryOption == 'pickup' &&
                  (selectedRegion == null ||
                      selectedCity == null ||
                      selectedPickupSite == null)) {
                missing.add('pickup location');
              }
              message += missing.join(', ');

              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(child: Text(message)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swipe_down_alt_rounded,
                              color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Swipe down to dismiss',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  dismissDirection: DismissDirection.down,
                  showCloseIcon: true,
                  duration: Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: EdgeInsets.all(16),
                ),
              );
              return;
            }

            try {
              setState(() => _isProceedingToPayment = true);

              // Always save delivery information to API, even for guests
              final locationIds = await _resolveBillingLocationIds();
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
                        ? selectedRegion!['description']?.toString()
                        : null,
                pickupCity: (deliveryOption == 'pickup' && selectedCity != null)
                    ? selectedCity!['description']?.toString()
                    : null,
                pickupSite:
                    (deliveryOption == 'pickup' && selectedPickupSite != null)
                        ? selectedPickupSite!['description']?.toString()
                        : null,
                regionId: locationIds.regionId,
                cityId: locationIds.cityId,
                storeId: locationIds.storeId,
                lat: _latitude,
                lng: _longitude,
              );

              await _ensureDeliveryFeeForPayment(
                saveResult: Map<String, dynamic>.from(saveResult),
              );
              debugPrint(
                  '🚀 [DELIVERY] Fee passed to payment: $deliveryFee');

              if (!mounted) return;
              _proceedToPayment();
            } catch (e) {
              if (mounted) {
                await _ensureDeliveryFeeForPayment();
                _proceedToPayment();
              }
            } finally {
              if (mounted) setState(() => _isProceedingToPayment = false);
            }
          },
          child: Center(
            child: _isProceedingToPayment
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue to payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
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
      // Urgent order applies to deliveries only.
      if (option == 'pickup') {
        _isOrderUrgent = false;
        _emergencyOrderFee = null;
      }
    });
  }

  void _proceedToPayment() {
    double? parseCoord(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    // Create delivery address based on option
    String deliveryAddress;
    double? paymentLat = _latitude;
    double? paymentLng = _longitude;
    if (deliveryOption == 'delivery') {
      deliveryAddress =
          '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_regionController.text.trim()}';
    } else {
      // For pickup, use the selected pickup location
      String pickupLocation = selectedPickupSite != null
          ? '${selectedPickupSite!['description']}, ${selectedCity!['description']}, ${selectedRegion!['description']}'
          : '${selectedCity?['description'] ?? 'Selected'}, ${selectedRegion?['description'] ?? 'Location'}';
      deliveryAddress = 'Pickup at $pickupLocation';

      // Prefer selected store coordinates for pickup confirmation map/directions.
      if (selectedPickupSite != null) {
        paymentLat = parseCoord(selectedPickupSite!['lat']) ??
            parseCoord(selectedPickupSite!['latitude']) ??
            parseCoord(selectedPickupSite!['store_lat']) ??
            parseCoord(selectedPickupSite!['store_latitude']) ??
            paymentLat;
        paymentLng = parseCoord(selectedPickupSite!['lng']) ??
            parseCoord(selectedPickupSite!['longitude']) ??
            parseCoord(selectedPickupSite!['store_lng']) ??
            parseCoord(selectedPickupSite!['store_longitude']) ??
            paymentLng;
      }
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
      print('   📍 Coordinates precision: '
          '${_latitude?.toStringAsFixed(8)}, ${_longitude?.toStringAsFixed(8)}');
      print('🚀 [DELIVERY] ======================================');
    } else {
      print('⚠️ [DELIVERY] No coordinates available to pass to PaymentPage');
    }

    _pushPageOnce(
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          deliveryAddress: deliveryAddress,
          contactNumber: _phoneController.text,
          deliveryOption: deliveryOption,
          guestEmail: _emailController.text.trim(),
          lat: paymentLat,
          lng: paymentLng,
          estimatedDeliveryTime: _apiDeliveryTime,
          distanceKm: _distanceKm,
          deliveryFee:
              deliveryOption == 'delivery' ? deliveryFee : 0.0,
          isOrderUrgent: _isOrderUrgent,
          emergencyOrderFee: _emergencyOrderFee,
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

    _pushPageOnce(
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          onLocationSelected: (double lat, double lng, String? address) {
            setState(() {
              _latitude = lat;
              _longitude = lng;
              if (deliveryOption == 'delivery') {
                if (!_tryApplyInstantDeliveryFee(lat, lng) && deliveryFee <= 0) {
                  _isUpdatingDeliveryFee = true;
                }
              }
            });

            if (deliveryOption == 'delivery') {
              unawaited(_refreshDeliveryFeeForCoordinates(lat, lng));
            }

            print(
                '🗺️ [MAP PICKER] ===== EXACT LOCATION SELECTED FROM MAP =====');
            print('🗺️ [MAP PICKER] 🎯 PRECISE COORDINATES SELECTED:');
            print('   📍 Latitude: $lat');
            print('   📍 Longitude: $lng');
            print('   📍 Full coordinates: ($lat, $lng)');
            print('   📍 Address from map picker: $address');
            print(
                '   📍 Coordinates type: ${lat.runtimeType}, ${lng.runtimeType}');
            print('   📍 Coordinates precision: '
                '${lat.toStringAsFixed(8)}, ${lng.toStringAsFixed(8)}');
            print('🗺️ [MAP PICKER] 📍 STORED IN STATE:');
            print('   📍 Stored Latitude: $_latitude');
            print('   📍 Stored Longitude: $_longitude');
            print('   📍 Stored coordinates: ($_latitude, $_longitude)');
            print('🗺️ [MAP PICKER] ======================================');

            // Always run reverse geocoding to populate region and city (required for validation).
            // If Places API gave us an address, pass it so we use it for the address field.
            final preferredAddress = (address != null &&
                    address.isNotEmpty &&
                    address != 'Unknown location' &&
                    address != 'Address not found')
                ? address
                : null;

            // Fire the async geocoding in the background (don't await, callback is void)
            try {
              _getAddressFromCoordinates(lat, lng,
                  preferredAddress: preferredAddress);
            } catch (e) {
              print('❌ [MAP PICKER] Error in location selected callback: $e');
            }
          },
        ),
      ),
    );
  }

  /// Get address from coordinates using reverse geocoding.
  /// [preferredAddress] if provided, is used for the address field instead of the placemark-built address.
  Future<void> _getAddressFromCoordinates(double lat, double lng,
      {String? preferredAddress}) async {
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
          _invalidateBillingLocationCache();
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

            // Update address field: use preferred (e.g. from Places) or placemark-built
            _addressController.text = (preferredAddress ?? address).trim();
            print(
                '🗺️ [REVERSE GEOCODING] Updated address: ${preferredAddress ?? address}');

            // Clear validation highlights since user picked a valid location
            _highlightRegionField = false;
            _highlightCityField = false;
            _highlightAddressField = false;
          });

          // Fee already refreshed from map tap; server save runs in that flow.
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

            // Validate pre-filled region value - use flexible matching
            if (_regionController.text.isNotEmpty) {
              final regionVal = _regionController.text.trim().toLowerCase();
              final regionExists = regions.any((r) {
                final desc = (r['description'] ?? '').toString().toLowerCase();
                return desc == regionVal ||
                    desc.contains(regionVal) ||
                    regionVal.contains(desc);
              });
              if (!regionExists) {
                _regionController.clear();
                print(
                    '⚠️ [REGIONS] Pre-filled region not in allowed list, cleared');
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

            // Validate pre-filled city value - use flexible matching
            if (_cityController.text.isNotEmpty) {
              final cityVal = _cityController.text.trim().toLowerCase();
              final cityExists = cities.any((c) {
                final desc = (c['description'] ?? '').toString().toLowerCase();
                return desc == cityVal ||
                    desc.contains(cityVal) ||
                    cityVal.contains(desc);
              });
              if (!cityExists) {
                _cityController.clear();
                print(
                    '⚠️ [CITIES] Pre-filled city not in cities list, cleared');
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
                final normalized = DeliveryService.normalizeStoreMap(store);
                final description = normalized['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueStores.containsKey(description)) {
                  uniqueStores[description] = normalized;
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
