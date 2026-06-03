// pages/delivery_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/models/guest_checkout_draft.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/services/delivery_service.dart';
import 'package:eclapp/services/guest_checkout_draft_service.dart';
import 'package:flutter/material.dart';
import 'bottomnav.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:eclapp/pages/map_picker_page.dart';
import '../utils/app_error_utils.dart';
import '../widgets/checkout_progress_stepper.dart';
import '../config/app_colors.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  DeliveryPageState createState() => DeliveryPageState();
}

class DeliveryPageState extends State<DeliveryPage> {
  bool _isNavigatingToNextPage = false;
  Future<void>? _initialDeliveryDataLoad;
  bool _isInitialDeliveryDataLoading = true;

  Future<T?> _pushPageOnce<T>(Route<T> route) async {
    if (!mounted || _isNavigatingToNextPage) return null;
    _isNavigatingToNextPage = true;
    try {
      return await Navigator.push<T>(context, route);
    } finally {
      if (mounted) {
        _isNavigatingToNextPage = false;
      }
    }
  }

  void _onAddressFieldsChanged() {
    if (_suppressAddressDrivenFeeRefresh > 0) return;
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
  int _suppressAddressDrivenFeeRefresh = 0;
  int _feeUpdateGeneration = 0;
  Future<void>? _activeDeliveryFeeRefresh;
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

  /// True when [deliveryFee] came from save-billing or calculate-delivery-fee API.
  bool _deliveryFeeFromApi = false;
  /// Order summary amounts — populated only from save-billing-add responses.
  bool _apiOrderSummaryReady = false;
  double? _apiSubtotal;
  double _apiDiscount = 0;
  double? _apiRunningSubtotal;
  bool _apiShippingFree = false;
  double _apiDeliveryFeeAmount = 0;

  String? _lastDeliveryErrorMessage;

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

  static const Color _pageBg = Color(0xFFF2F3F5);
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;
  bool _scrollCanScroll = false;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void dispose() {
    _feeUpdateGeneration++;
    unawaited(_persistGuestCheckoutDraft());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    _scrollController.addListener(_onScroll);
    _initialDeliveryDataLoad = _loadUserData().whenComplete(() {
      if (!mounted) return;
      setState(() => _isInitialDeliveryDataLoading = false);
    });
    _loadRegions(); // load regions when the page starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });
  }

  Future<void> _ensureInitialDeliveryDataLoaded() async {
    final pending = _initialDeliveryDataLoad;
    if (pending == null) {
      if (mounted && _isInitialDeliveryDataLoading) {
        setState(() => _isInitialDeliveryDataLoading = false);
      }
      return;
    }
    await pending;
    _initialDeliveryDataLoad = null;
    if (mounted && _isInitialDeliveryDataLoading) {
      setState(() => _isInitialDeliveryDataLoading = false);
    }
  }

  void _runWithSuppressedAddressFeeRefresh(void Function() action) {
    _suppressAddressDrivenFeeRefresh++;
    try {
      action();
    } finally {
      _suppressAddressDrivenFeeRefresh--;
    }
  }

  void _showDeliverySnack(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() => _lastDeliveryErrorMessage = isError ? message : null);
    if (!mounted) return;
    AppErrorUtils.showSnack(
      context,
      message,
      isError: isError,
      duration: Duration(seconds: isError ? 4 : 2),
    );
  }

  void _onScroll() => _updateScrollHint();

  void _updateScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final hasScrollableContent = position.maxScrollExtent > 1.0;
    final nearTop = position.pixels <= 8;
    final showHint = hasScrollableContent && nearTop;

    if (hasScrollableContent != _scrollCanScroll ||
        showHint != _showScrollHint) {
      setState(() {
        _scrollCanScroll = hasScrollableContent;
        _showScrollHint = showHint;
      });
    }
  }

  bool _isFeeGenerationCurrent(int generation) =>
      mounted && generation == _feeUpdateGeneration;

  /// Fetches delivery fee from save-billing + calculate-delivery-fee APIs only.
  Future<void> _refreshDeliveryFeeForCoordinates(
    double lat,
    double lng, {
    bool fullLocationLookup = false,
  }) async {
    if (deliveryOption == 'pickup' || !mounted) return;

    final generation = ++_feeUpdateGeneration;

    setState(() {
      _isUpdatingDeliveryFee = true;
      _deliveryFeeFromApi = false;
      _lastFeeDistanceText = null;
      deliveryFee = 0;
    });

    final refresh = _runDeliveryFeeRefresh(
      generation,
      fullLocationLookup: fullLocationLookup,
    );
    _activeDeliveryFeeRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (_activeDeliveryFeeRefresh == refresh) {
        _activeDeliveryFeeRefresh = null;
      }
    }
  }

  /// Fee refresh after region/city/address are known (resolves billing location ids).
  Future<void> _refreshDeliveryFeeAfterCoordinatesResolved(
    double lat,
    double lng,
  ) =>
      _refreshDeliveryFeeForCoordinates(
        lat,
        lng,
        fullLocationLookup: true,
      );

  /// Whether save-billing-add has enough data to succeed (avoids 422 on map pick).
  bool _canSyncBillingForFeeRefresh() {
    if (deliveryOption != 'delivery') return false;
    if (_latitude == null || _longitude == null) return false;
    if (_regionController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      return false;
    }
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || email.isEmpty || phone.isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  Future<void> _runDeliveryFeeRefresh(
    int generation, {
    bool fullLocationLookup = false,
  }) async {
    try {
      if (!_canSyncBillingForFeeRefresh()) {
        debugPrint(
          '📦 [DELIVERY] Skipping save-billing until name, contact, and address are complete',
        );
        return;
      }

      final ok = await _syncDeliveryAddressToServer(
        generation,
        fullLocationLookup: fullLocationLookup,
      );
      if (!ok &&
          mounted &&
          generation == _feeUpdateGeneration &&
          deliveryOption == 'delivery') {
        _showDeliverySnack(
          _lastDeliveryErrorMessage ??
              'Could not update delivery fee. Reselect your location or try again.',
        );
      }
    } catch (e, st) {
      debugPrint('❌ [DELIVERY] Fee refresh error: $e\n$st');
      if (mounted && generation == _feeUpdateGeneration) {
        _showDeliverySnack(
          'Could not update delivery fee. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted && generation == _feeUpdateGeneration) {
        setState(() => _isUpdatingDeliveryFee = false);
      }
    }
  }

  Future<bool> _syncDeliveryAddressToServer(
    int generation, {
    bool fullLocationLookup = false,
  }) async {
    return _safelyCallDeliveryAPI(
      generation: generation,
      skipFeeWhenAlreadySet: false,
      skipLocationIdLookup: !fullLocationLookup,
    );
  }

  /// Map pick / coords update: reverse-geocode first, then sync billing when ready.
  void _onDeliveryLocationSelected(
    double lat,
    double lng, {
    String? address,
  }) {
    if (!mounted) return;
    if (!mounted) return;
    final preferredAddress = (address != null &&
            address.isNotEmpty &&
            address != 'Unknown location' &&
            address != 'Address not found')
        ? address.trim()
        : null;

    _runWithSuppressedAddressFeeRefresh(() {
      setState(() {
        _latitude = lat;
        _longitude = lng;
        if (deliveryOption == 'delivery') {
          _isUpdatingDeliveryFee = true;
          _deliveryFeeFromApi = false;
          _lastFeeDistanceText = null;
          deliveryFee = 0;
          if (preferredAddress != null) {
            _addressController.text = preferredAddress;
            _highlightAddressField = false;
          }
        }
      });
    });

    unawaited(_completeMapLocationSelection(lat, lng, preferredAddress));
  }

  Future<void> _completeMapLocationSelection(
    double lat,
    double lng,
    String? preferredAddress,
  ) async {
    await _getAddressFromCoordinates(
      lat,
      lng,
      preferredAddress: preferredAddress,
    );
    if (!mounted || deliveryOption != 'delivery') return;
    await _refreshDeliveryFeeForCoordinates(
      lat,
      lng,
      fullLocationLookup: true,
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

  double? _deliveryFeeFromSaveResult(Map<String, dynamic> result) {
    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    final raw = closestStore?['delivery_fee'] ??
        closestStore?['deliveryFee'] ??
        result['delivery_fee'] ??
        result['deliveryFee'] ??
        result['data']?['delivery_fee'] ??
        result['data']?['deliveryFee'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic>? _promoDetailsFromSaveResult(Map<String, dynamic> result) {
    final direct = result['promo_details'];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final root = result['data'] is Map ? result['data'] as Map : result;
    final promo = root['promo_details'];
    if (promo is Map<String, dynamic>) return promo;
    if (promo is Map) return Map<String, dynamic>.from(promo);
    return null;
  }

  void _applyOrderSummaryFromSaveResult(Map<String, dynamic> result) {
    if (!mounted) return;
    final promo = _promoDetailsFromSaveResult(result);
    if (promo == null) return;

    final shippingFree = promo['shipping_free'] == true;
    final subtotal = _toDouble(promo['subtotal']) ??
        _toDouble(promo['running_subtotal']);
    final discount = _toDouble(promo['discount_amount']) ??
        _toDouble(promo['coupon_discount']) ??
        0.0;
    final runningSubtotal = _toDouble(promo['running_subtotal']);

    _setStateIfMounted(() {
      _apiOrderSummaryReady = subtotal != null;
      _apiSubtotal = subtotal;
      _apiDiscount = discount;
      _apiRunningSubtotal = runningSubtotal;
      _apiShippingFree = shippingFree;
      if (shippingFree && deliveryOption == 'delivery') {
        _apiDeliveryFeeAmount = 0;
        deliveryFee = 0;
        _deliveryFeeFromApi = true;
      } else if (deliveryOption == 'delivery') {
        _deliveryFeeFromApi = false;
      }
    });

    debugPrint(
      '📊 [DELIVERY] Order summary from save-billing — subtotal=$_apiSubtotal, '
      'discount=$_apiDiscount, shippingFree=$_apiShippingFree, '
      'running=$_apiRunningSubtotal',
    );
  }

  /// Delivery fee from `/calculate-delivery-fee` (preferred) or save-billing fallback.
  Future<void> _resolveDeliveryFeeFromApis(
    Map<String, dynamic> result, {
    required int generation,
  }) async {
    if (!_isFeeGenerationCurrent(generation)) return;
    if (deliveryOption != 'delivery' || _apiShippingFree) return;

    final distanceText = _distanceTextFromSaveResult(result);
    final feeFromSave = _deliveryFeeFromSaveResult(result);

    double? resolvedFee;
    String? source;

    if (distanceText != null && distanceText.trim().isNotEmpty) {
      final calcResult = await DeliveryService.fetchDeliveryFeeFromApi(
        distanceText: distanceText.trim(),
        fallbackToLocalEstimate: false,
      );
      if (!_isFeeGenerationCurrent(generation)) return;
      if (calcResult != null) {
        resolvedFee = _toDouble(calcResult['delivery_fee']);
        source = 'calculate-delivery-fee';
        _lastFeeDistanceText = distanceText.trim();
      }
    }

    if (resolvedFee == null && feeFromSave != null) {
      resolvedFee = feeFromSave;
      source = 'save-billing-add';
    }

    if (resolvedFee == null || !_isFeeGenerationCurrent(generation)) return;

    _setStateIfMounted(() {
      _apiDeliveryFeeAmount = resolvedFee!;
      deliveryFee = resolvedFee;
      _deliveryFeeFromApi = true;
    });

    debugPrint(
      '📊 [DELIVERY] Delivery fee from $source: $_apiDeliveryFeeAmount '
      '(save-billing had ${feeFromSave ?? 'n/a'})',
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  /// Applies ETA and delivery fee from a save-billing-add response.
  Future<void> _applySaveBillingSideEffects(
    Map<String, dynamic> result, {
    required int generation,
  }) async {
    if (result['success'] != true || !mounted) return;

    // Order summary always follows the latest successful save-billing response.
    _applyOrderSummaryFromSaveResult(result);

    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    if (closestStore != null && closestStore['duration_text'] != null) {
      _setStateIfMounted(() {
        _apiDeliveryTime = closestStore['duration_text']?.toString();
      });
    }

    if (deliveryOption != 'delivery') return;
    if (!_isFeeGenerationCurrent(generation)) return;

    await _resolveDeliveryFeeFromApis(result, generation: generation);
  }

  void _applyDeliveryFeeResult(
    Map<String, dynamic> feeResult,
    String distanceText, {
    required bool fromApi,
    required int generation,
  }) {
    if (!_isFeeGenerationCurrent(generation)) return;
    final rawFee = feeResult['delivery_fee'];
    final parsedFee =
        rawFee is num ? rawFee.toDouble() : double.tryParse('$rawFee');
    if (parsedFee == null) return;
    final rawDist = feeResult['distance'];
    _setStateIfMounted(() {
      deliveryFee = parsedFee;
      if (fromApi) {
        _apiDeliveryFeeAmount = parsedFee;
      }
      if (distanceText.trim().isNotEmpty) {
        _lastFeeDistanceText = distanceText.trim();
      }
      _deliveryFeeFromApi = fromApi;
      if (rawDist is num) {
        _distanceKm = rawDist.toDouble();
      }
    });
  }

  /// Fetches the real fee from /calculate-delivery-fee (source of truth).
  Future<double?> _applyDeliveryFeeFromDistanceText(
    String distanceText, {
    required int generation,
  }) async {
    if (!_isFeeGenerationCurrent(generation)) return null;

    final trimmed = distanceText.trim();
    if (trimmed.isEmpty) return null;

    try {
      final feeResult = await DeliveryService.fetchDeliveryFeeFromApi(
        distanceText: trimmed,
        fallbackToLocalEstimate: true,
      );
      if (!_isFeeGenerationCurrent(generation)) return null;

      if (feeResult == null) {
        debugPrint(
            '❌ [DELIVERY] calculate-delivery-fee failed for "$trimmed"; fee not set');
        _lastDeliveryErrorMessage =
            'Could not calculate delivery fee for your address.';
        return null;
      }

      final fromApi = feeResult['from_api'] == true;
      _applyDeliveryFeeResult(
        feeResult,
        trimmed,
        fromApi: fromApi,
        generation: generation,
      );
      if (!_isFeeGenerationCurrent(generation)) return null;

      if (!fromApi) {
        debugPrint(
            '⚠️ [DELIVERY] Using local estimate for "$trimmed" — API unavailable');
        _lastDeliveryErrorMessage =
            'Showing estimated delivery fee — exact amount will be confirmed at checkout.';
      } else {
        _lastDeliveryErrorMessage = null;
      }
      return deliveryFee;
    } catch (e, st) {
      debugPrint('❌ [DELIVERY] Fee from distance_text failed: $e\n$st');
      if (_isFeeGenerationCurrent(generation)) {
        _lastDeliveryErrorMessage =
            'Could not calculate delivery fee. Please try again.';
      }
      return null;
    }
  }

  /// Ensures [deliveryFee] is set before payment without extra save/refresh cycles.
  Future<double> _ensureDeliveryFeeForPayment({
    Map<String, dynamic>? saveResult,
  }) async {
    if (deliveryOption == 'pickup') return 0;

    try {
      final pendingRefresh = _activeDeliveryFeeRefresh;
      if (pendingRefresh != null) {
        await pendingRefresh;
      }

      if (saveResult != null && saveResult['success'] == true) {
        await _applySaveBillingSideEffects(
          saveResult,
          generation: _feeUpdateGeneration,
        );
      }
      if (_deliveryFeeFromApi) return deliveryFee;

      final distanceText = saveResult != null
          ? _distanceTextFromSaveResult(saveResult)
          : _lastFeeDistanceText;
      if (distanceText != null && distanceText.isNotEmpty) {
        await _applyDeliveryFeeFromDistanceText(
          distanceText,
          generation: _feeUpdateGeneration,
        );
      }
      if (_deliveryFeeFromApi) return deliveryFee;

      if (_latitude != null && _longitude != null) {
        await _safelyCallDeliveryAPI(skipFeeWhenAlreadySet: false);
      }
    } catch (e, st) {
      debugPrint('❌ [DELIVERY] ensureDeliveryFeeForPayment: $e\n$st');
      _lastDeliveryErrorMessage =
          'Could not confirm delivery fee. Please try again.';
    }

    return deliveryFee;
  }

  // turn an address into map coordinates
  Future<void> _getCoordinatesFromAddress(String address) async {
    if (address.trim().isEmpty || !mounted) return;

    _setStateIfMounted(() {
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

        if (!mounted) return;
        _setStateIfMounted(() {
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

        await _getAddressFromCoordinates(_latitude!, _longitude!);
        if (!mounted) return;
        await _refreshDeliveryFeeAfterCoordinatesResolved(
          _latitude!,
          _longitude!,
        );

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
            if (!mounted) return;
            _setStateIfMounted(() {
              _latitude = location.latitude;
              _longitude = location.longitude;
            });
            print(
                '✅ [GEOCODING] Fallback SUCCESS! Using city center coordinates: (${_latitude}, ${_longitude})');

            await _getAddressFromCoordinates(_latitude!, _longitude!);
            if (!mounted) return;
            await _refreshDeliveryFeeAfterCoordinatesResolved(
              _latitude!,
              _longitude!,
            );
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
          if (!mounted) return;
          _setStateIfMounted(() {
            _latitude = location.latitude;
            _longitude = location.longitude;
          });
          print(
              '✅ [GEOCODING] Fallback SUCCESS after error! Using city center: (${_latitude}, ${_longitude})');

          await _getAddressFromCoordinates(_latitude!, _longitude!);
          if (!mounted) return;
          await _refreshDeliveryFeeAfterCoordinatesResolved(
            _latitude!,
            _longitude!,
          );
        }
      } catch (fallbackError) {
        print('❌ [GEOCODING] Fallback also failed: $fallbackError');
      }

      debugPrint('❌ Geocoding error: $e');
    } finally {
      _setStateIfMounted(() {
        _isGeocoding = false;
      });
      print('🔄 [GEOCODING] Geocoding process completed');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      GuestCheckoutDraft? localDraft;

      if (!isLoggedIn) {
        localDraft = await GuestCheckoutDraftService.load();
        if (localDraft != null && mounted) {
          await _applyGuestCheckoutDraft(localDraft);
        }
      } else {
        await _loadBasicUserData();
      }

      // API billing address (guest + logged-in). For guests, only overwrite when
      // the server returns usable fields so a failed payment does not wipe draft.
      try {
        final deliveryResult = await DeliveryService.getLastDeliveryInfo()
            .timeout(const Duration(seconds: 8));

        if (deliveryResult['success'] &&
            deliveryResult['data'] != null &&
            mounted) {
          _applyDeliveryApiData(
            Map<String, dynamic>.from(deliveryResult['data'] as Map),
            mergeOnly: !isLoggedIn && localDraft != null,
          );
        }
      } catch (apiError) {
        // Local guest draft (if any) remains on screen.
      }
    } catch (e) {
      // if loading failed, just start with empty fields
    }
  }

  void _applyDeliveryApiData(
    Map<String, dynamic> deliveryData, {
    bool mergeOnly = false,
  }) {
    if (!mounted) return;
    void applyText(
      TextEditingController controller,
      dynamic value,
    ) {
      final text = value?.toString().trim() ?? '';
      if (mergeOnly && text.isEmpty) return;
      if (text.isNotEmpty || !mergeOnly) {
        controller.text = text;
      }
    }

    double? loadedLat;
    double? loadedLng;
    var loadedAddress = '';

    setState(() {
      applyText(_nameController, deliveryData['name']);
      applyText(_emailController, deliveryData['email']);
      applyText(_phoneController, deliveryData['phone']);

      final option = (deliveryData['delivery_option'] ??
              deliveryData['shipping_type'] ??
              deliveryOption)
          .toString()
          .toLowerCase();
      if (!mergeOnly || option.isNotEmpty) {
        deliveryOption = option;
      }

      if (deliveryOption == 'delivery') {
        applyText(_regionController, deliveryData['region']);
        applyText(_cityController, deliveryData['city']);
        applyText(_addressController, deliveryData['address']);

        loadedLat = _toDouble(deliveryData['lat']);
        loadedLng = _toDouble(deliveryData['lng']);
        loadedAddress = deliveryData['address']?.toString().trim() ?? '';

        _runWithSuppressedAddressFeeRefresh(() {
          if (loadedLat != null && loadedLng != null) {
            _latitude = loadedLat;
            _longitude = loadedLng;
          }
        });
      } else if (deliveryOption == 'pickup') {
        final regionLabel =
            deliveryData['pickup_region']?.toString().trim() ?? '';
        final cityLabel = deliveryData['pickup_city']?.toString().trim() ?? '';
        final siteLabel = (deliveryData['pickup_site'] ??
                deliveryData['pickup_location'])
            ?.toString()
            .trim() ??
            '';
        if (!mergeOnly ||
            regionLabel.isNotEmpty ||
            cityLabel.isNotEmpty ||
            siteLabel.isNotEmpty) {
          unawaited(_restorePickupSelection(
            regionLabel: regionLabel,
            cityLabel: cityLabel,
            siteLabel: siteLabel,
          ));
        }
      }

      applyText(_notesController, deliveryData['notes']);
    });

    if (deliveryOption == 'delivery') {
      if (loadedLat != null &&
          loadedLng != null &&
          _canSyncBillingForFeeRefresh()) {
        unawaited(
          _refreshDeliveryFeeAfterCoordinatesResolved(loadedLat!, loadedLng!),
        );
      } else if (loadedAddress.isNotEmpty) {
        unawaited(_getCoordinatesFromAddress(loadedAddress));
      }
    }
  }

  Future<void> _applyGuestCheckoutDraft(GuestCheckoutDraft draft) async {
    if (!mounted) return;

    _runWithSuppressedAddressFeeRefresh(() {
      setState(() {
        _nameController.text = draft.name;
        _emailController.text = draft.email;
        _phoneController.text = draft.phone;
        deliveryOption = draft.deliveryOption;
        _regionController.text = draft.region;
        _cityController.text = draft.city;
        _addressController.text = draft.address;
        _notesController.text = draft.notes;
        _latitude = draft.lat;
        _longitude = draft.lng;
        deliveryFee = draft.deliveryFee;
        _deliveryFeeFromApi = draft.deliveryFee > 0;
        _isOrderUrgent = draft.isOrderUrgent;
        _emergencyOrderFee = draft.emergencyOrderFee;
        _apiDeliveryTime = draft.estimatedDeliveryTime;
        _distanceKm = draft.distanceKm;
        if (draft.apiSubtotal != null) {
          _apiOrderSummaryReady = true;
          _apiSubtotal = draft.apiSubtotal;
          _apiDiscount = draft.apiDiscountAmount ?? draft.discountAmount;
          _apiShippingFree = draft.apiShippingFree ?? false;
          _apiDeliveryFeeAmount = draft.deliveryFee;
          _deliveryFeeFromApi = draft.deliveryFee > 0 ||
              (draft.apiShippingFree ?? false);
        }
      });
    });

    if (draft.deliveryOption == 'pickup') {
      await _restorePickupSelection(
        regionLabel: draft.pickupRegionLabel,
        cityLabel: draft.pickupCityLabel,
        siteLabel: draft.pickupSiteLabel,
      );
    } else if (draft.address.trim().isNotEmpty &&
        draft.lat == null &&
        draft.lng == null) {
      await _getCoordinatesFromAddress(draft.address);
    }
  }

  Future<void> _restorePickupSelection({
    required String regionLabel,
    required String cityLabel,
    required String siteLabel,
  }) async {
    if (!mounted) return;
    if (regionLabel.isEmpty && cityLabel.isEmpty && siteLabel.isEmpty) return;

    if (regions.isEmpty) {
      await _loadRegions();
    }
    if (!mounted) return;

    final region = DeliveryService.findRegionInList(regions, regionLabel);
    if (region == null) return;

    final regionId = region['id'];
    if (regionId == null) return;

    await _loadCities(regionId);
    if (!mounted) return;

    Map<String, dynamic>? city;
    for (final c in cities) {
      final name = (c['description'] ?? c['name'] ?? '').toString();
      if (name.toLowerCase() == cityLabel.toLowerCase()) {
        city = c;
        break;
      }
    }
    if (city == null) return;

    final cityId = city['id'];
    if (cityId == null) return;

    await _loadStores(cityId);
    if (!mounted) return;

    Map<String, dynamic>? store;
    for (final s in stores) {
      final name = (s['description'] ?? s['name'] ?? '').toString();
      if (name.toLowerCase() == siteLabel.toLowerCase()) {
        store = s;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      selectedRegion = region;
      selectedCity = city;
      selectedPickupSite = store;
    });
  }

  Future<GuestCheckoutDraft?> _buildGuestCheckoutDraft() async {
    if (await AuthService.isLoggedIn()) return null;
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_id');
    if (guestId == null || guestId.isEmpty) return null;

    return GuestCheckoutDraft(
      guestId: guestId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      deliveryOption: deliveryOption,
      region: _regionController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
      pickupRegionLabel: selectedRegion?['description']?.toString() ?? '',
      pickupCityLabel: selectedCity?['description']?.toString() ?? '',
      pickupSiteLabel: selectedPickupSite?['description']?.toString() ?? '',
      lat: _latitude,
      lng: _longitude,
      deliveryFee: deliveryFee,
      isOrderUrgent: _isOrderUrgent,
      emergencyOrderFee: _emergencyOrderFee,
      estimatedDeliveryTime: _apiDeliveryTime,
      distanceKm: _distanceKm,
      apiSubtotal: _apiSubtotal,
      apiDiscountAmount: _apiDiscount > 0 ? _apiDiscount : null,
      apiShippingFree: _apiShippingFree,
    );
  }

  Future<void> _persistGuestCheckoutDraft() async {
    if (!mounted) return;
    if (await AuthService.isLoggedIn()) return;
    final draft = await _buildGuestCheckoutDraft();
    if (draft != null) {
      await GuestCheckoutDraftService.save(draft);
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

  Future<({int? regionId, int? cityId, int? storeId})>
      _resolveBillingLocationIdsSafe({required bool skipLookup}) async {
    if (skipLookup) {
      return (regionId: null, cityId: null, storeId: null);
    }
    try {
      return await _resolveBillingLocationIds();
    } catch (e) {
      debugPrint('❌ [DELIVERY] resolveBillingLocationIds: $e');
      return (regionId: null, cityId: null, storeId: null);
    }
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
      backgroundColor: _pageBg,
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
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                          child: const CheckoutProgressStepper(
                            compact: true,
                            steps: [
                              'Cart',
                              'Delivery',
                              'Payment',
                              'Confirmation'
                            ],
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
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0) {
                          _updateScrollHint();
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                          const SizedBox(height: 8),
                          if (deliveryOption == 'delivery') ...[
                            _buildUrgentOption(),
                            const SizedBox(height: 8),
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
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          Animate(
                            effects: [
                              FadeEffect(duration: 400.ms),
                              SlideEffect(
                                  duration: 400.ms,
                                  begin: Offset(0, 0.1),
                                  end: Offset(0, 0))
                            ],
                            child: _buildOrderSummary(),
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    ),
                    if (_showScrollHint)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _pageBg.withValues(alpha: 0),
                                      _pageBg,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                color: _pageBg,
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Scroll for more',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  static const double _fieldRadius = 12;
  static const double _sectionRadius = 14;
  static const EdgeInsets _sectionMargin = EdgeInsets.symmetric(horizontal: 14);
  static const EdgeInsets _sectionPadding = EdgeInsets.all(12);
  static const Color _cardShadow = Color(0x0A000000);
  static const Color _accent = Color(0xFF2E7D32);

  BoxDecoration _sectionCardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      );

  Widget _buildDeliveryOptions() {
    return Container(
      margin: _sectionMargin,
      padding: _sectionPadding,
      decoration: _sectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            'How do you want to receive your order?',
            compact: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
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
                size: 13,
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
                    fontSize: 11,
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
      margin: _sectionMargin,
      padding: _sectionPadding,
      decoration: _sectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Pickup location', compact: true),
          const SizedBox(height: 8),
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
                  style: const TextStyle(fontSize: 13),
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
            compact: true,
          ),
          if (selectedRegion != null) ...[
            const SizedBox(height: 10),
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
                    style: const TextStyle(fontSize: 13),
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
              compact: true,
            ),
          ],
          if (selectedCity != null) ...[
            const SizedBox(height: 10),
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
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedPickupSite = value;
                });
              },
              isLoading: isLoadingStores,
              compact: true,
            ),
          ],
          const SizedBox(height: 10),
          if (_highlightPickupField) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select region, city and pickup site',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pickup stations are open till 7pm, Monday to Saturday. Closed on Sundays.',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11,
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
    bool compact = false,
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
                fontSize: compact ? 11 : 14,
                color:
                    _highlightPickupField ? Colors.red : Colors.grey.shade700,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 11 : 14,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: _highlightPickupField ? Colors.red : Colors.grey.shade300,
              width: _highlightPickupField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
            color: _highlightPickupField
                ? Colors.red.shade50
                : Colors.grey.shade50,
          ),
          child: DropdownButtonFormField<Map<String, dynamic>>(
            value: value,
            isDense: compact,
            decoration: InputDecoration(
              prefixIcon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 6 : 8),
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
                      size: compact ? 18 : 22,
                    ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 14,
              ),
            ),
            hint: Text(
              isLoading
                  ? 'Loading...'
                  : (items.isEmpty ? 'No options available' : label),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: compact ? 13 : 14,
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
      margin: _sectionMargin,
      padding: _sectionPadding,
      decoration: _sectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionLabel('Contact & address', compact: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
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
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                _buildFormField(
                  key: nameSectionKey,
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  isRequired: true,
                  isHighlighted: _highlightNameField,
                  compact: true,
                  onChanged: (value) {
                    setState(() {
                      _highlightNameField = false;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildFormField(
                  key: emailSectionKey,
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  isRequired: true,
                  isHighlighted: _highlightEmailField,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  compact: true,
                  onChanged: (value) {
                    setState(() {
                      _highlightEmailField = false;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildPhoneField(isPhoneValid, compact: true),
              ],
            ),
          ),
          if (deliveryOption == 'delivery') ...[
            const SizedBox(height: 10),
            Text(
              'Delivery location',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: addressSectionKey,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_highlightRegionField ||
                        _highlightCityField ||
                        _highlightAddressField)
                    ? Colors.red.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.22),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pick location on map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_addressController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Location confirmed',
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _addressController.text,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 12,
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
    bool compact = false,
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
                fontSize: compact ? 11 : 13,
                color: isHighlighted ? Colors.red : Colors.grey.shade700,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 14,
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        TextField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          style: TextStyle(fontSize: compact ? 13 : 14),
          decoration: InputDecoration(
            isDense: compact,
            prefixIcon: Icon(
              icon,
              color: isHighlighted ? Colors.red : Colors.grey.shade600,
              size: compact ? 18 : 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey.shade300,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : Colors.grey.shade300,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: isHighlighted ? Colors.red : _accent,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isHighlighted ? Colors.red.shade50 : Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 10 : 14,
            ),
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
    await _refreshDeliveryFeeAfterCoordinatesResolved(_latitude!, _longitude!);
  }

  Future<bool> _safelyCallDeliveryAPI({
    int? generation,
    bool skipFeeWhenAlreadySet = false,
    bool skipLocationIdLookup = false,
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

      debugPrint('📤 Calling DeliveryService.saveDeliveryInfo...');

      final locationIds = await _resolveBillingLocationIdsSafe(
        skipLookup: skipLocationIdLookup,
      );

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
        final errorMessage =
            (result['message'] ?? 'Failed to save delivery information')
                .toString();
        debugPrint('❌ [DELIVERY] Save failed: $errorMessage');
        _lastDeliveryErrorMessage = errorMessage;
        return false;
      }
      _lastDeliveryErrorMessage = null;

      if (!skipFeeWhenAlreadySet &&
          mounted &&
          (generation == null || generation == _feeUpdateGeneration)) {
        await _applySaveBillingSideEffects(
          Map<String, dynamic>.from(result),
          generation: generation ?? _feeUpdateGeneration,
        );
      } else if (mounted &&
          (generation == null || generation == _feeUpdateGeneration)) {
        final closestStore =
            result['closest_store'] ?? result['data']?['closest_store'];
        if (closestStore != null && closestStore['duration_text'] != null) {
          _setStateIfMounted(() {
            _apiDeliveryTime = closestStore['duration_text']?.toString();
          });
        }
      }

      return true;
    } on TimeoutException catch (e) {
      debugPrint('❌ [DELIVERY] save billing timeout: $e');
      _lastDeliveryErrorMessage =
          'Request timed out. Please check your connection and try again.';
      return false;
    } catch (e, st) {
      debugPrint('❌ Error in API call: $e\n$st');
      _lastDeliveryErrorMessage =
          'Network error. Please check your connection and try again.';
      return false;
    }
  }

  Widget _buildPhoneField(bool isPhoneValid, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phone number',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: compact ? 11 : 13,
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade700,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 11 : 14,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          style: TextStyle(fontSize: compact ? 13 : 14),
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
                fontSize: compact ? 10 : 12,
              ),
            );
          },
          onChanged: (value) {
            setState(() {
              _highlightPhoneField = false;
            });
          },
          decoration: InputDecoration(
            isDense: compact,
            prefixIcon: Padding(
              padding: EdgeInsets.all(compact ? 6 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇬🇭', style: TextStyle(fontSize: compact ? 18 : 22)),
                  SizedBox(width: compact ? 3 : 4),
                  Text('+233', style: TextStyle(fontSize: compact ? 13 : 15)),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade300,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : Colors.grey.shade300,
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _highlightPhoneField ? Colors.red : _accent,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                _highlightPhoneField ? Colors.red.shade50 : Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 10 : 14,
            ),
            errorText: isPhoneValid ? null : 'Phone number must be 10 digits',
            errorStyle: TextStyle(fontSize: compact ? 10 : 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryNotes() {
    return Container(
      margin: _sectionMargin,
      padding: _sectionPadding,
      decoration: _sectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSectionLabel('Delivery notes', compact: true),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. gate code, landmarks, or special instructions',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _accent, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Future<void> _onUrgentToggleChanged(bool enabled) async {
    if (enabled == _isOrderUrgent || !mounted) return;

    if (!enabled) {
      _setStateIfMounted(() {
        _isOrderUrgent = false;
        _emergencyOrderFee = null;
      });
      return;
    }

    _setStateIfMounted(() => _isOrderUrgent = true);

    final result = await DeliveryService.addXpressFee();
    if (!mounted) return;

    if (result != null && result['xpress_fee'] != null) {
      _setStateIfMounted(() {
        _emergencyOrderFee = (result['xpress_fee'] is num)
            ? (result['xpress_fee'] as num).toDouble()
            : double.tryParse(result['xpress_fee'].toString());
      });
      return;
    }

    _setStateIfMounted(() {
      _isOrderUrgent = false;
      _emergencyOrderFee = null;
    });
    if (!mounted) return;
    AppErrorUtils.showSnack(
      context,
      'Urgent delivery is unavailable right now. Please try again.',
      isError: true,
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildUrgentOption() {
    final isOn = _isOrderUrgent;
    const urgentRed = Color(0xFFD32F2F);
    const urgentOrange = Color(0xFFEA580C);

    return Padding(
      padding: _sectionMargin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOn
                ? [
                    Colors.red.shade50,
                    const Color(0xFFFFF5F5),
                    Colors.white,
                  ]
                : [
                    const Color(0xFFFFF7ED),
                    const Color(0xFFFFFBEB),
                    Colors.white,
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOn
                ? urgentRed.withValues(alpha: 0.45)
                : urgentOrange.withValues(alpha: 0.55),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOn ? urgentRed : urgentOrange).withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isOn
                    ? urgentRed.withValues(alpha: 0.12)
                    : urgentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOn
                      ? urgentRed.withValues(alpha: 0.2)
                      : urgentOrange.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                isOn ? Icons.flash_on_rounded : Icons.flash_on_outlined,
                size: 17,
                color: isOn ? urgentRed : urgentOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isOn ? 'Urgent order' : 'xPress delivery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.2,
                            color: isOn ? urgentRed : const Color(0xFF9A3412),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isOn
                              ? urgentRed.withValues(alpha: 0.12)
                              : urgentOrange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOn ? 'ON' : 'FAST',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isOn ? urgentRed : urgentOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isOn
                        ? 'Prioritized for faster delivery.'
                        : 'Delivered sooner — extra fee applies.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: isOn
                          ? Colors.red.shade800.withValues(alpha: 0.75)
                          : Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Explicit thumb/track colors so the switch stays visible on Android
            // (M3 + ColorScheme.fromSwatch can render a near-white inactive switch).
            Switch.adaptive(
              value: isOn,
              onChanged: (value) => unawaited(_onUrgentToggleChanged(value)),
              activeThumbColor: Colors.white,
              activeTrackColor: urgentRed,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade600,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final emergencyOrderFee = _emergencyOrderFee ?? 0.0;
    final isDelivery = deliveryOption == 'delivery';
    final promoReady = _apiOrderSummaryReady && _apiSubtotal != null;
    final deliveryFeeReady =
        !isDelivery || _apiShippingFree || _deliveryFeeFromApi;
    final summaryLoading = !promoReady || (isDelivery && !deliveryFeeReady);

    if (summaryLoading) {
      return Container(
        margin: _sectionMargin,
        padding: _sectionPadding,
        decoration: _sectionCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Order summary', compact: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Subtotal',
                    0,
                    icon: Icons.shopping_cart_rounded,
                    isLoading: true,
                  ),
                  if (isDelivery) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Delivery fee',
                      0,
                      icon: Icons.local_shipping_rounded,
                      isLoading: true,
                    ),
                  ],
                  Divider(height: 20, thickness: 1, color: Colors.grey.shade300),
                  _buildSummaryRow(
                    'Total',
                    0,
                    isHighlighted: true,
                    icon: Icons.payment_rounded,
                    isLoading: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final subtotal = _apiSubtotal!;
    final discountAmount = _apiDiscount;
    final deliveryCharge = isDelivery
        ? (_apiShippingFree ? 0.0 : _apiDeliveryFeeAmount)
        : 0.0;
    final merchandiseTotal =
        _apiRunningSubtotal ?? (subtotal - discountAmount);
    final total = merchandiseTotal + deliveryCharge + emergencyOrderFee;

    return Container(
      margin: _sectionMargin,
      padding: _sectionPadding,
      decoration: _sectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Order summary', compact: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', subtotal,
                    icon: Icons.shopping_cart_rounded),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Discount',
                    -discountAmount,
                    icon: Icons.local_offer_rounded,
                  ),
                ],
                if (isDelivery) ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Delivery fee',
                    deliveryCharge,
                    icon: Icons.local_shipping_rounded,
                    isFree: _apiShippingFree,
                  ),
                ],
                if (emergencyOrderFee > 0) ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow('Urgent order fee', emergencyOrderFee,
                      icon: Icons.flash_on),
                ],
                Divider(height: 20, thickness: 1, color: Colors.grey.shade300),
                _buildSummaryRow('Total', total,
                    isHighlighted: true,
                    icon: Icons.payment_rounded),
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
    bool isFree = false,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: isHighlighted ? _accent : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              fontSize: isHighlighted ? 13 : 12,
              color:
                  isHighlighted ? Colors.grey.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
        _buildSummaryValue(value,
            isHighlighted: isHighlighted, isLoading: isLoading, isFree: isFree),
      ],
    );
  }

  Widget _buildSummaryValue(
    double value, {
    required bool isHighlighted,
    required bool isLoading,
    required bool isFree,
  }) {
    if (isLoading) {
      return Text(
        'Calculating…',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade500,
        ),
      );
    }

    if (isFree) {
      return Text(
        'Free',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.green.shade700,
        ),
      );
    }

    return Text(
      'GHS ${value.toStringAsFixed(2)}',
      style: TextStyle(
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
        fontSize: isHighlighted ? 15 : 12,
        color: isHighlighted ? _accent : Colors.grey.shade800,
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      margin: _sectionMargin,
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (_isProceedingToPayment || _isInitialDeliveryDataLoading)
              ? null
              : () async {
            await _ensureInitialDeliveryDataLoaded();
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

              AppErrorUtils.showSnack(context, message, isError: true);
              return;
            }

            try {
              setState(() => _isProceedingToPayment = true);

              // Always save delivery information to API, even for guests
              final locationIds = await _resolveBillingLocationIdsSafe(
                skipLookup: false,
              );
              Map<String, dynamic> saveResult;
              try {
                saveResult = await DeliveryService.saveDeliveryInfo(
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
                  pickupCity:
                      (deliveryOption == 'pickup' && selectedCity != null)
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
              } catch (e, st) {
                debugPrint('❌ [DELIVERY] saveDeliveryInfo threw: $e\n$st');
                if (!mounted) return;
                _showDeliverySnack(
                  'Could not save delivery details. Please try again.',
                );
                return;
              }

              if (saveResult['success'] != true) {
                if (!mounted) return;
                _showDeliverySnack(
                  saveResult['message']?.toString() ??
                      'Could not save delivery details. Please try again.',
                );
                return;
              }

              await _persistGuestCheckoutDraft();
              if (!mounted) return;

              await _ensureDeliveryFeeForPayment(
                saveResult: Map<String, dynamic>.from(saveResult),
              );
              if (!mounted) return;

              if (deliveryOption == 'delivery' &&
                  !_deliveryFeeFromApi) {
                _showDeliverySnack(
                  _lastDeliveryErrorMessage ??
                      'Could not calculate delivery fee. Reselect your location on the map and try again.',
                );
                return;
              }

              debugPrint('🚀 [DELIVERY] Fee passed to payment: $deliveryFee');

              if (!mounted) return;
              _proceedToPayment();
            } catch (e, st) {
              debugPrint('❌ [DELIVERY] Continue to payment failed: $e\n$st');
              if (mounted) {
                _showDeliverySnack(
                  'Something went wrong. Please try again.',
                );
              }
            } finally {
              if (mounted) setState(() => _isProceedingToPayment = false);
            }
                },
          child: Center(
            child: (_isProceedingToPayment || _isInitialDeliveryDataLoading)
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
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue to payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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

    unawaited(_persistGuestCheckoutDraft());

    final cartSubtotal = _apiSubtotal;

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
          deliveryFee: deliveryOption == 'delivery' ? _apiDeliveryFeeAmount : 0.0,
          isOrderUrgent: _isOrderUrgent,
          emergencyOrderFee: _emergencyOrderFee,
          apiSubtotal: cartSubtotal,
          apiDiscountAmount: _apiDiscount > 0 ? _apiDiscount : null,
          apiShippingFree: _apiShippingFree,
        ),
      ),
    );
  }

  /// Show map picker to select exact location
  void _showMapPicker() async {
    if (!mounted) return;
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
        _setStateIfMounted(() {
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
        if (!mounted) return;

        if (locations.isNotEmpty) {
          final location = locations.first;
          initialLat = location.latitude;
          initialLng = location.longitude;

          print(
              '🗺️ [MAP PICKER] ✅ SUCCESS! Fresh coordinates obtained: ($initialLat, $initialLng)');

          // Update the state for future use
          _setStateIfMounted(() {
            _latitude = initialLat;
            _longitude = initialLng;
          });

          print(
              '🗺️ [MAP PICKER] State updated with new coordinates: ($_latitude, $_longitude)');

          // Fetch delivery time from API with new coordinates
          _fetchDeliveryTimeFromAPI();

          // Force a small delay to ensure iOS processes the coordinate update
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;

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

    if (!mounted) return;
    _pushPageOnce(
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          onLocationSelected: (double lat, double lng, String? address) {
            _onDeliveryLocationSelected(lat, lng, address: address);

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
          _runWithSuppressedAddressFeeRefresh(() {
            setState(() {
              // Update region with administrative area
              if (placemark.administrativeArea != null &&
                  placemark.administrativeArea!.isNotEmpty) {
                _regionController.text = placemark.administrativeArea!;
                print(
                    '🗺️ [REVERSE GEOCODING] Updated region: ${placemark.administrativeArea}');
              }

              // Update city with locality
              if (placemark.locality != null &&
                  placemark.locality!.isNotEmpty) {
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
