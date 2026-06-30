// pages/delivery_page.dart
import 'dart:async';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/models/guest_checkout_draft.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/services/delivery_service.dart';
import 'package:eclapp/services/guest_checkout_draft_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/checkout_log.dart';
import 'bottomnav.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:eclapp/pages/map_picker_page.dart';
import '../utils/app_error_utils.dart';
import '../utils/checkout_order_totals.dart';
import '../providers/cart_provider.dart';
import '../widgets/order_threshold_promo_banner.dart';
import '../widgets/checkout_flow_header.dart';
import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';

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
        _isNavigatingToNextPage = false;
      }
    }
  }

  void _onAddressFieldsChanged() {
    if (_suppressAddressDrivenFeeRefresh > 0) return;
    if (_regionController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      return;
    }
    _addressFeeDebounceTimer?.cancel();
    _addressFeeDebounceTimer = Timer(_addressFeeDebounce, () {
      if (!mounted) return;
      _updateDeliveryFee();
    });
  }

  String deliveryOption = 'delivery';
  double deliveryFee = 0.00;
  double? _distanceKm; // actual distance in km from closest store
  bool _isProceedingToPayment = false;
  int _suppressAddressDrivenFeeRefresh = 0;
  int _feeUpdateGeneration = 0;
  Timer? _addressFeeDebounceTimer;
  static const Duration _addressFeeDebounce = Duration(milliseconds: 650);
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

  // how long delivery will take (from the api)
  String? _apiDeliveryTime;

  /// Last server [distance_text] we priced — skips duplicate calculate-delivery-fee calls.
  String? _lastFeeDistanceText;

  /// True when [deliveryFee] came from `/calculate-delivery-fee` (or its local formula fallback).
  bool _deliveryFeeFromApi = false;

  /// True while `/calculate-delivery-fee` is in flight after a map pick / geocode.
  bool _isFetchingDeliveryFee = false;

  /// Order summary amounts — from get-billing-add or save-billing-add.
  double? _apiSubtotal;
  double _apiDiscount = 0;
  double? _apiRunningSubtotal;
  bool _apiShippingFree = false;
  double _apiDeliveryFeeAmount = 0;

  /// Cart subtotal until billing [promo_details] arrives.
  double _cartMerchandiseSubtotal = 0;

  double get _merchandiseSubtotalForSummary =>
      (_apiSubtotal != null && _apiSubtotal! > 0)
          ? _apiSubtotal!
          : _cartMerchandiseSubtotal;

  bool get _hasMerchandiseSubtotalForSummary =>
      _merchandiseSubtotalForSummary > 0;

  bool get _effectiveShippingFree =>
      OrderThresholdPromoBanner.effectiveShippingFree(
        apiShippingFree: _apiShippingFree,
        merchandiseSubtotal: _merchandiseSubtotalForSummary,
        isDelivery: deliveryOption == 'delivery',
      );

  CheckoutOrderTotals get _checkoutTotals => CheckoutOrderTotals(
        merchandiseSubtotal: _merchandiseSubtotalForSummary,
        discount: _apiDiscount,
        deliveryFee: deliveryOption == 'delivery' ? deliveryFee : 0,
        emergencyOrderFee: _emergencyOrderFee ?? 0,
        runningSubtotal: _apiRunningSubtotal,
        shippingFree: _effectiveShippingFree,
        isDelivery: deliveryOption == 'delivery',
      );

  String? _lastDeliveryErrorMessage;

  String? _cachedBillingRegionLabel;
  String? _cachedBillingCityLabel;
  int? _cachedBillingRegionId;
  int? _cachedBillingCityId;
  Future<void>? _regionsLoadFuture;

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
    _addressFeeDebounceTimer?.cancel();
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
    _regionController.addListener(_onAddressFieldsChanged);
    _cityController.addListener(_onAddressFieldsChanged);
    _addressController.addListener(_onAddressFieldsChanged);
    unawaited(_loadUserData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCartMerchandiseSubtotal();
      if (mounted) _updateScrollHint();
    });
  }

  void _refreshCartMerchandiseSubtotal() {
    if (!mounted) return;
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final fromCart = cart.calculateSubtotal();
      if (fromCart <= 0) return;
      setState(() {
        _cartMerchandiseSubtotal = fromCart;
      });
    } catch (e) {
      debugPrint('[DELIVERY] Cart subtotal unavailable: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      GuestCheckoutDraft? localDraft;

      if (!isLoggedIn) {
        localDraft = await GuestCheckoutDraftService.load();
        if (localDraft != null && mounted) {
          unawaited(_applyGuestCheckoutDraft(localDraft));
        }
      } else {
        unawaited(_loadBasicUserData());
      }

      final mergeOnly = !isLoggedIn && localDraft != null;
      unawaited(_fetchGetBillingAndApply(mergeOnly: mergeOnly));
    } catch (e) {
      debugPrint('[DELIVERY] _loadUserData error: $e');
    }
  }

  void _ensurePickupRegionsLoaded() {
    if (regions.isNotEmpty || isLoadingRegions) return;
    _regionsLoadFuture ??= _loadRegions();
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

  /// Nearest-store distance label used to call `/calculate-delivery-fee`.
  Future<String?> _resolveDistanceTextForCoordinates(
    double lat,
    double lng,
    int generation,
  ) async {
    if (!_isFeeGenerationCurrent(generation) || _effectiveShippingFree) {
      return null;
    }

    var stores = DeliveryService.cachedStoresForFeeEstimate;
    if (stores == null || stores.isEmpty) {
      stores = await DeliveryService.getStoresForFeeEstimate();
    }
    if (!_isFeeGenerationCurrent(generation) || stores.isEmpty) {
      return null;
    }

    final estimate = DeliveryService.estimateFeeFromCoordinates(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    if (estimate == null) return null;

    final distanceKm = _toDouble(estimate['distance_km']);
    final distanceText = estimate['distance_text']?.toString().trim();
    if (distanceText == null || distanceText.isEmpty) return null;

    _setStateIfMounted(() {
      if (distanceKm != null) _distanceKm = distanceKm;
      _lastFeeDistanceText = distanceText;
    });
    return distanceText;
  }

  void _applyLocalFeeFallbackFromStores(
    double lat,
    double lng,
    int generation,
    List<Map<String, dynamic>> stores,
  ) {
    if (!_isFeeGenerationCurrent(generation) || _effectiveShippingFree) return;

    final estimate = DeliveryService.estimateFeeFromCoordinates(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    if (estimate == null) return;

    final parsedFee = _toDouble(estimate['delivery_fee']);
    if (parsedFee == null) return;

    _applyInstantDeliveryFee(
      fee: parsedFee,
      distanceText: estimate['distance_text']?.toString(),
      distanceKm: _toDouble(estimate['distance_km']),
      fromApi: false,
    );
  }

  void _applyInstantDeliveryFee({
    required double fee,
    String? distanceText,
    double? distanceKm,
    bool fromApi = true,
  }) {
    if (_effectiveShippingFree) return;
    _setStateIfMounted(() {
      deliveryFee = fee;
      _apiDeliveryFeeAmount = fee;
      _deliveryFeeFromApi = fromApi;
      if (distanceKm != null) {
        _distanceKm = distanceKm;
      }
      final trimmed = distanceText?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        _lastFeeDistanceText = trimmed;
      }
    });
  }

  /// Applies delivery fee from get-billing fields without network calls.
  void _applyDeliveryFeeFromBillingFields({
    double? fee,
    String? distanceText,
  }) {
    if (!mounted ||
        deliveryOption != 'delivery' ||
        _effectiveShippingFree) {
      return;
    }

    final trimmedDistance = distanceText?.trim() ?? '';
    if (trimmedDistance.isNotEmpty) {
      _lastFeeDistanceText = trimmedDistance;
    }

    var resolvedFee = fee;
    if ((resolvedFee == null || resolvedFee <= 0) && trimmedDistance.isNotEmpty) {
      final local = DeliveryService.localDeliveryFeeResult(trimmedDistance);
      resolvedFee = _toDouble(local?['delivery_fee']);
      final km = local?['distance'];
      if (km is num) {
        _distanceKm = km.toDouble();
      }
    }

    if (resolvedFee != null && resolvedFee >= 0) {
      _applyInstantDeliveryFee(
        fee: resolvedFee,
        distanceText: trimmedDistance.isNotEmpty ? trimmedDistance : null,
        distanceKm: _distanceKm,
        fromApi: false,
      );
    }
  }

  bool _distanceTextsMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final left = DeliveryService.normalizeDistanceTextForFeeApi(a.trim());
    final right = DeliveryService.normalizeDistanceTextForFeeApi(b.trim());
    return left.isNotEmpty && left == right;
  }

  /// Prices delivery via `/calculate-delivery-fee` as soon as coordinates are known.
  Future<void> _refreshDeliveryFeeForCoordinates(
    double lat,
    double lng,
  ) async {
    if (deliveryOption == 'pickup' || !mounted || _effectiveShippingFree) {
      return;
    }

    final generation = ++_feeUpdateGeneration;

    _setStateIfMounted(() {
      _isFetchingDeliveryFee = true;
      _deliveryFeeFromApi = false;
      _lastDeliveryErrorMessage = null;
    });

    try {
      final distanceText =
          await _resolveDistanceTextForCoordinates(lat, lng, generation);
      if (!_isFeeGenerationCurrent(generation) ||
          distanceText == null ||
          distanceText.isEmpty) {
        return;
      }

      final apiFee = await _applyDeliveryFeeFromDistanceText(
        distanceText,
        generation: generation,
        forceRefresh: false,
      );

      if (!_isFeeGenerationCurrent(generation)) return;

      if (apiFee == null) {
        final stores = DeliveryService.cachedStoresForFeeEstimate ??
            await DeliveryService.getStoresForFeeEstimate();
        if (stores.isNotEmpty) {
          _applyLocalFeeFallbackFromStores(lat, lng, generation, stores);
        }
      }
    } catch (e, st) {
      debugPrint('❌ [DELIVERY] refreshDeliveryFeeForCoordinates: $e\n$st');
      if (_isFeeGenerationCurrent(generation)) {
        _lastDeliveryErrorMessage =
            'Could not calculate delivery fee. Please try again.';
      }
    } finally {
      if (_isFeeGenerationCurrent(generation)) {
        _setStateIfMounted(() => _isFetchingDeliveryFee = false);
      }
    }
  }

  /// Map pick / coords update: reverse-geocode first (no save-billing until Continue).
  void _onDeliveryLocationSelected(
    double lat,
    double lng, {
    String? address,
  }) {
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
          _deliveryFeeFromApi = false;
          _isFetchingDeliveryFee = true;
          deliveryFee = 0;
          _apiDeliveryFeeAmount = 0;
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
    await _refreshDeliveryFeeForCoordinates(lat, lng);
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

  Map<String, dynamic>? _promoDetailsFromSaveResult(
      Map<String, dynamic> result) {
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

    final shippingFree = OrderThresholdPromoBanner.shippingFreeFromPromo(
      promo,
      fallbackSubtotal: _cartMerchandiseSubtotal,
    );
    final subtotal =
        _toDouble(promo['subtotal']) ?? _toDouble(promo['running_subtotal']);
    final discount = _toDouble(promo['discount_amount']) ??
        _toDouble(promo['coupon_discount']) ??
        0.0;
    final runningSubtotal = _toDouble(promo['running_subtotal']);

    _setStateIfMounted(() {
      _apiSubtotal = subtotal;
      _apiDiscount = discount;
      _apiRunningSubtotal = runningSubtotal;
      _apiShippingFree = shippingFree;
      if (shippingFree && deliveryOption == 'delivery') {
        _apiDeliveryFeeAmount = 0;
        deliveryFee = 0;
        _deliveryFeeFromApi = true;
      }
      // Keep calculated fee visible until calculate-delivery-fee returns an update.
    });

    checkoutLog(
      '📊 [DELIVERY] Order summary from save-billing — subtotal=$_apiSubtotal, '
      'discount=$_apiDiscount, shippingFree=$_apiShippingFree, '
      'running=$_apiRunningSubtotal',
    );
  }

  /// Delivery fee always from `/calculate-delivery-fee` (never save-billing `delivery_fee`).
  Future<void> _resolveDeliveryFeeFromApis(
    Map<String, dynamic> result, {
    required int generation,
    Map<String, dynamic>? prefetchedFeeResult,
    String? prefetchedDistanceText,
  }) async {
    if (!_isFeeGenerationCurrent(generation)) return;
    if (deliveryOption != 'delivery' || _effectiveShippingFree) return;

    final distanceText = _distanceTextFromSaveResult(result);
    final feeFromSave = _deliveryFeeFromSaveResult(result);

    if (distanceText == null || distanceText.trim().isEmpty) {
      debugPrint(
        '❌ [DELIVERY] No distance_text for calculate-delivery-fee '
        '(save-billing had ${feeFromSave ?? 'n/a'})',
      );
      return;
    }

    final trimmedDistance = distanceText.trim();

    if (prefetchedFeeResult != null &&
        prefetchedDistanceText != null &&
        _distanceTextsMatch(prefetchedDistanceText, trimmedDistance)) {
      final resolvedFee = _toDouble(prefetchedFeeResult['delivery_fee']);
      if (resolvedFee != null) {
        final fromApi = prefetchedFeeResult['from_api'] == true;
        _applyDeliveryFeeResult(
          prefetchedFeeResult,
          trimmedDistance,
          fromApi: fromApi,
          generation: generation,
        );
        checkoutLog(
          '📊 [DELIVERY] Reused parallel calculate-delivery-fee for '
          '"$trimmedDistance"',
        );
        return;
      }
    }

    if (_distanceTextsMatch(_lastFeeDistanceText, trimmedDistance) &&
        _deliveryFeeFromApi) {
      checkoutLog(
        '📊 [DELIVERY] Skipping duplicate calculate-delivery-fee for '
        '"$trimmedDistance"',
      );
      return;
    }

    final calcResult = await DeliveryService.fetchDeliveryFeeFromApi(
      distanceText: trimmedDistance,
      fallbackToLocalEstimate: false,
    );
    if (!_isFeeGenerationCurrent(generation)) return;

    final resolvedFee =
        calcResult != null ? _toDouble(calcResult['delivery_fee']) : null;
    if (resolvedFee == null) {
      debugPrint(
        '❌ [DELIVERY] calculate-delivery-fee returned no fee for '
        '"$trimmedDistance" (save-billing had ${feeFromSave ?? 'n/a'})',
      );
      return;
    }

    final source = calcResult!['from_api'] == true
        ? 'calculate-delivery-fee'
        : 'calculate-delivery-fee (local estimate)';

    _setStateIfMounted(() {
      _apiDeliveryFeeAmount = resolvedFee;
      deliveryFee = resolvedFee;
      _deliveryFeeFromApi = true;
      _lastFeeDistanceText = trimmedDistance;
    });

    checkoutLog(
      '📊 [DELIVERY] Delivery fee from $source: $_apiDeliveryFeeAmount '
      '(save-billing had ${feeFromSave ?? 'n/a'})',
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  /// Coordinates sent to save-billing-add (delivery address or pickup store).
  ({double? lat, double? lng}) _billingCoordinates() {
    if (deliveryOption == 'delivery') {
      return (lat: _latitude, lng: _longitude);
    }
    if (selectedPickupSite != null) {
      final site = selectedPickupSite!;
      return (
        lat: _toDouble(site['lat']) ??
            _toDouble(site['latitude']) ??
            _toDouble(site['store_lat']) ??
            _toDouble(site['store_latitude']),
        lng: _toDouble(site['lng']) ??
            _toDouble(site['longitude']) ??
            _toDouble(site['store_lng']) ??
            _toDouble(site['store_longitude']),
      );
    }
    return (lat: _latitude, lng: _longitude);
  }

  /// Applies ETA and delivery fee from a save-billing-add response.
  Future<void> _applySaveBillingSideEffects(
    Map<String, dynamic> result, {
    required int generation,
    Map<String, dynamic>? prefetchedFeeResult,
    String? prefetchedDistanceText,
  }) async {
    if (result['success'] != true || !mounted) return;

    // Order summary always follows the latest successful save-billing response.
    _applyOrderSummaryFromSaveResult(result);

    final serverDistance = _distanceTextFromSaveResult(result);
    if (serverDistance != null && serverDistance.isNotEmpty) {
      _lastFeeDistanceText = serverDistance;
    }

    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    if (closestStore != null && closestStore['duration_text'] != null) {
      _setStateIfMounted(() {
        _apiDeliveryTime = closestStore['duration_text']?.toString();
      });
    }

    if (deliveryOption != 'delivery') return;
    if (!_isFeeGenerationCurrent(generation)) return;
    if (_effectiveShippingFree) return;

    await _resolveDeliveryFeeFromApis(
      result,
      generation: generation,
      prefetchedFeeResult: prefetchedFeeResult,
      prefetchedDistanceText: prefetchedDistanceText,
    );
  }

  void _applyDeliveryFeeResult(
    Map<String, dynamic> feeResult,
    String distanceText, {
    required bool fromApi,
    required int generation,
  }) {
    if (!_isFeeGenerationCurrent(generation) || _effectiveShippingFree) return;
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

  /// Fetches delivery fee from `/calculate-delivery-fee` (always preferred).
  Future<double?> _applyDeliveryFeeFromDistanceText(
    String distanceText, {
    required int generation,
    bool forceRefresh = false,
  }) async {
    if (!_isFeeGenerationCurrent(generation)) return null;
    if (_effectiveShippingFree) return 0;

    final trimmed = distanceText.trim();
    if (trimmed.isEmpty) return null;

    try {
      final feeResult = await DeliveryService.fetchDeliveryFeeFromApi(
        distanceText: trimmed,
        fallbackToLocalEstimate: false,
        forceRefresh: forceRefresh,
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

  /// Ensures [deliveryFee] is set via calculate-delivery-fee before payment.
  Future<double> _ensureDeliveryFeeForPayment({
    Map<String, dynamic>? saveResult,
    bool forceRefreshBeforePayment = false,
  }) async {
    if (deliveryOption == 'pickup') return 0;
    if (_effectiveShippingFree) return 0;

    try {
      if (saveResult != null && saveResult['success'] == true) {
        await _applySaveBillingSideEffects(
          saveResult,
          generation: _feeUpdateGeneration,
        );
      }

      final distanceText = saveResult != null
          ? _distanceTextFromSaveResult(saveResult)
          : _lastFeeDistanceText;

      // save-billing side effects already priced closest_store distance.
      if (_deliveryFeeFromApi &&
          deliveryFee > 0 &&
          distanceText != null &&
          _distanceTextsMatch(_lastFeeDistanceText, distanceText)) {
        return deliveryFee;
      }

      if (_deliveryFeeFromApi && !forceRefreshBeforePayment) {
        return deliveryFee;
      }

      if (distanceText != null && distanceText.isNotEmpty) {
        await _applyDeliveryFeeFromDistanceText(
          distanceText,
          generation: _feeUpdateGeneration,
          forceRefresh: forceRefreshBeforePayment,
        );
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
          '$cleanAddress, ${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';

      final locations = await locationFromAddress(fullAddress);

      if (locations.isNotEmpty) {
        final location = locations.first;

        if (!mounted) return;
        _setStateIfMounted(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });

        await _getAddressFromCoordinates(_latitude!, _longitude!);
        if (!mounted) return;
        if (!_isProceedingToPayment) {
          await _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!);
        }
      } else {
        // if the full address didnt work, try just city and region
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

            await _getAddressFromCoordinates(_latitude!, _longitude!);
            if (!mounted) return;
            if (!_isProceedingToPayment) {
              await _refreshDeliveryFeeForCoordinates(
                _latitude!,
                _longitude!,
              );
            }
          }
        } catch (_) {}

        checkoutLog('⚠️ No coordinates found for address: $fullAddress');
      }
    } catch (e) {
      // try again with just city and region
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
          await _getAddressFromCoordinates(_latitude!, _longitude!);
          if (!mounted) return;
          if (!_isProceedingToPayment) {
            await _refreshDeliveryFeeForCoordinates(
              _latitude!,
              _longitude!,
            );
          }
        }
      } catch (_) {}

      checkoutLog('❌ Geocoding error: $e');
    } finally {
      _setStateIfMounted(() {
      });
    }
  }

  Future<void> _fetchGetBillingAndApply({required bool mergeOnly}) async {
    try {
      final deliveryResult = await DeliveryService.getLastDeliveryInfo()
          .timeout(const Duration(seconds: 8));

      if (deliveryResult['success'] == true && mounted) {
        _applyGetBillingResponse(
          Map<String, dynamic>.from(deliveryResult),
          mergeOnly: mergeOnly,
        );
      }
    } catch (apiError) {
      // Local guest draft (if any) remains on screen.
    }
  }

  void _applyGetBillingResponse(
    Map<String, dynamic> result, {
    bool mergeOnly = false,
  }) {
    final data = result['data'];
    final checkout = result['checkout'];

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      _applyDeliveryApiData(map, mergeOnly: mergeOnly);
    }

    if (checkout is Map) {
      _applyBillingCheckoutFromServer(
        Map<String, dynamic>.from(checkout),
      );
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (!_deliveryFeeFromApi || deliveryFee <= 0) {
        _applyDeliveryFeeFromBillingFields(
          fee: _toDouble(map['delivery_fee']),
          distanceText: map['distance_text']?.toString(),
        );
      }
    }

    if (deliveryOption == 'delivery' &&
        !_effectiveShippingFree &&
        !_deliveryFeeFromApi &&
        deliveryFee <= 0 &&
        _latitude != null &&
        _longitude != null) {
      unawaited(
        _refreshDeliveryFeeForCoordinates(_latitude!, _longitude!),
      );
    }
  }

  /// Applies order summary, delivery fee, and ETA from get-billing-add checkout payload.
  void _applyBillingCheckoutFromServer(Map<String, dynamic> checkout) {
    if (!mounted) return;

    final normalized = Map<String, dynamic>.from(checkout);
    _applyOrderSummaryFromSaveResult(normalized);

    final distanceText = DeliveryService.distanceTextFromSaveResult(normalized) ??
        checkout['distance_text']?.toString();
    if (distanceText != null && distanceText.trim().isNotEmpty) {
      _lastFeeDistanceText = distanceText.trim();
    }

    final closestStore = normalized['closest_store'];
    if (closestStore is Map && closestStore['duration_text'] != null) {
      _setStateIfMounted(() {
        _apiDeliveryTime = closestStore['duration_text']?.toString();
      });
    }

    final urgent = checkout['order_urgent'] == true ||
        checkout['is_urgent'] == true;
    final xpressFee = _toDouble(checkout['xpress_fee']) ??
        _toDouble(checkout['emergency_order_fee']);

    // Never overwrite a calculate-delivery-fee quote with save-billing store fee.
    if (!_deliveryFeeFromApi || deliveryFee <= 0) {
      _applyDeliveryFeeFromBillingFields(
        fee: DeliveryService.deliveryFeeFromSaveResult(normalized),
        distanceText: distanceText,
      );
    }

    if (urgent || (xpressFee != null && xpressFee > 0)) {
      _setStateIfMounted(() {
        _isOrderUrgent = urgent || (xpressFee ?? 0) > 0;
        if (xpressFee != null && xpressFee > 0) {
          _emergencyOrderFee = xpressFee;
        }
      });
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

    _runWithSuppressedAddressFeeRefresh(() {
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

          if (loadedLat != null && loadedLng != null) {
            _latitude = loadedLat;
            _longitude = loadedLng;
          }
        } else if (deliveryOption == 'pickup') {
          _ensurePickupRegionsLoaded();
          final regionLabel =
              deliveryData['pickup_region']?.toString().trim() ?? '';
          final cityLabel = deliveryData['pickup_city']?.toString().trim() ?? '';
          final siteLabel =
              (deliveryData['pickup_site'] ?? deliveryData['pickup_location'])
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
        _applyBillingLocationIdsFromData(deliveryData);
      });
    });
  }

  void _applyBillingLocationIdsFromData(Map<String, dynamic> deliveryData) {
    final regionId = deliveryData['region_id'];
    final cityId = deliveryData['city_id'];
    if (regionId is int && regionId > 0) {
      _cachedBillingRegionId = regionId;
      _cachedBillingRegionLabel = _regionController.text.trim();
    }
    if (cityId is int && cityId > 0) {
      _cachedBillingCityId = cityId;
      _cachedBillingCityLabel = _cityController.text.trim();
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
        deliveryFee = 0;
        _deliveryFeeFromApi = false;
        _apiDeliveryFeeAmount = 0;
        _isOrderUrgent = draft.isOrderUrgent;
        _emergencyOrderFee = draft.emergencyOrderFee;
        _apiDeliveryTime = draft.estimatedDeliveryTime;
        _distanceKm = draft.distanceKm;
        if (draft.apiSubtotal != null) {
          _apiSubtotal = draft.apiSubtotal;
          _apiDiscount = draft.apiDiscountAmount ?? draft.discountAmount;
          _apiShippingFree = draft.apiShippingFree ?? false;
        }
      });
    });

    if (draft.deliveryOption == 'pickup') {
      unawaited(_restorePickupSelection(
        regionLabel: draft.pickupRegionLabel,
        cityLabel: draft.pickupCityLabel,
        siteLabel: draft.pickupSiteLabel,
      ));
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

    final billingCoords = _billingCoordinates();
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
      lat: billingCoords.lat,
      lng: billingCoords.lng,
      deliveryFee: deliveryFee,
      isOrderUrgent: _isOrderUrgent,
      emergencyOrderFee: _emergencyOrderFee,
      estimatedDeliveryTime: _apiDeliveryTime,
      distanceKm: _distanceKm,
      feeDistanceText: _lastFeeDistanceText,
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
    // Geocode for lat/lng only — save-billing runs on Continue.
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

  Future<void> _ensureRegionsLoaded() async {
    if (regions.isNotEmpty) return;

    for (var attempt = 0; attempt < 3 && regions.isEmpty; attempt++) {
      if (attempt > 0) {
        _regionsLoadFuture = null;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        debugPrint('[REGIONS] Retrying region load (attempt ${attempt + 1}/3)');
      }
      _regionsLoadFuture ??= _loadRegions();
      await _regionsLoadFuture;
    }
  }

  Future<int?> _nearestDeliveryStoreId({
    required double lat,
    required double lng,
  }) async {
    final stores = DeliveryService.cachedStoresForFeeEstimate ??
        await DeliveryService.getStoresForFeeEstimate();
    if (stores.isEmpty) return null;
    final nearest = DeliveryService.nearestStoreToCoordinates(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    if (nearest == null) return null;
    return _idFromLocationMap(nearest.store);
  }

  /// Ensures the server checkout session has cart lines and delivery fee before
  /// save-billing-add (avoids backend null cart / delivery_fee assignment).
  Future<void> _prepareServerCartForSaveBilling() async {
    if (!mounted) return;

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      await cart.ensureReadyForCheckoutPayment();
      await cart.reaffirmSelectedItemsOnServer();
    } catch (e, st) {
      debugPrint('❌ [DELIVERY] reaffirm cart before save-billing: $e\n$st');
    }

    if (deliveryOption != 'delivery' || _effectiveShippingFree) return;

    final distance = _lastFeeDistanceText?.trim() ?? '';
    if (distance.isEmpty) return;

    try {
      await DeliveryService.applyDeliveryFeeToCart(
        distanceText: distance,
        fallbackToLocalEstimate: false,
        forceRefresh: true,
      );
    } catch (e, st) {
      debugPrint(
        '❌ [DELIVERY] apply delivery fee before save-billing: $e\n$st',
      );
    }
  }

  void _recordBillingSync(Map<String, dynamic> result) {
    if (result['success'] != true) return;
    final serverDistance = DeliveryService.distanceTextFromSaveResult(result);
    if (serverDistance != null && serverDistance.isNotEmpty) {
      _lastFeeDistanceText = serverDistance;
    }
    _applyOrderSummaryFromSaveResult(result);
  }

  /// Resolve backend region/city/store ids (save-billing-add expects numeric ids).
  Future<({int? regionId, int? cityId, int? storeId})>
      _resolveBillingLocationIds() async {
    await _ensureRegionsLoaded();
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
      cityId = await DeliveryService.resolveBillingCityId(
        regionId: regionId,
        cityLabel: cityLabel,
      );
      final cachedRows =
          await DeliveryService.getCitiesForRegionCached(regionId);
      _citiesCache[regionId] = cachedRows;
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
    final theme = context.appColors;
    return Scaffold(
      backgroundColor: theme.pageBg,
      body: Stack(
        children: [
          Column(
            children: [
              const CheckoutFlowHeader(
                title: 'Delivery Information',
                activeStep: 2,
                completedSteps: {1},
                confirmOnBack: true,
                leaveTitle: 'Leave Delivery',
                leaveMessage:
                    'Are you sure you want to leave the delivery page? Your information will be saved.',
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
                                      theme.pageBg.withValues(alpha: 0),
                                      theme.pageBg,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                color: theme.pageBg,
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Scroll for more',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.isDark
                                            ? Colors.white70
                                            : AppColors.primaryDark,
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
  static const Color _accent = AppColors.primaryDark;

  AppThemeColors get _theme => context.appColors;

  BoxDecoration _sectionCardDecoration() {
    final t = _theme;
    return BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(_sectionRadius),
      border: Border.all(color: t.border),
      boxShadow: t.isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : const [
              BoxShadow(
                color: _cardShadow,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
    );
  }

  BoxDecoration _innerPanelDecoration({Color? fill, Color? borderColor}) {
    final t = _theme;
    return BoxDecoration(
      color: fill ?? t.fieldBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor ?? t.border),
    );
  }

  Color _fieldFill({bool highlighted = false}) {
    if (!highlighted) return _theme.fieldBg;
    return _theme.isDark
        ? Colors.red.withValues(alpha: 0.14)
        : Colors.red.shade50;
  }

  Color _fieldBorder({bool highlighted = false}) {
    if (highlighted) return Colors.red;
    return _theme.searchBorder;
  }

  TextStyle _fieldTextStyle({double? fontSize}) => TextStyle(
        fontSize: fontSize ?? 14,
        color: _theme.inputText,
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
              color: _theme.fieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _theme.border),
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
              color: _theme.ink,
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
                color: isSelected ? Colors.white : _theme.muted,
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
                    color: isSelected ? Colors.white : _theme.ink,
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
                  style: _fieldTextStyle(fontSize: 13),
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
                    style: _fieldTextStyle(fontSize: 13),
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
                    style: _fieldTextStyle(fontSize: 13),
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
                color: _fieldFill(highlighted: true),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade400,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select region, city and pickup site',
                      style: TextStyle(
                        color: _theme.isDark
                            ? Colors.red.shade300
                            : Colors.red.shade700,
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
              color: _theme.isDark
                  ? Colors.blue.withValues(alpha: 0.12)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _theme.isDark
                    ? Colors.blue.withValues(alpha: 0.35)
                    : Colors.blue.shade100,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _theme.isDark
                      ? Colors.blue.shade300
                      : Colors.blue.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pickup stations are open till 7pm, Monday to Saturday. Closed on Sundays.',
                    style: TextStyle(
                      color: _theme.isDark
                          ? Colors.blue.shade200
                          : Colors.blue.shade800,
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
                color: _highlightPickupField ? Colors.red : _theme.ink,
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
              color: _fieldBorder(highlighted: _highlightPickupField),
              width: _highlightPickupField ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
            color: _fieldFill(highlighted: _highlightPickupField),
          ),
          child: DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: value,
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
                            _highlightPickupField ? Colors.red : _theme.muted,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.location_on_rounded,
                      color: _highlightPickupField ? Colors.red : _theme.muted,
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
                color: _theme.inputHint,
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
            dropdownColor: _theme.surface,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _highlightPickupField ? Colors.red : _theme.muted,
            ),
            style: _fieldTextStyle(fontSize: 14),
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
            decoration: _innerPanelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Personal details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: _theme.muted,
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
                color: _theme.muted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: addressSectionKey,
              padding: const EdgeInsets.all(10),
              decoration: _innerPanelDecoration(
                fill: (_highlightRegionField ||
                        _highlightCityField ||
                        _highlightAddressField)
                    ? _fieldFill(highlighted: true)
                    : null,
                borderColor: (_highlightRegionField ||
                        _highlightCityField ||
                        _highlightAddressField)
                    ? Colors.red
                    : null,
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
                        color: _theme.surface,
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
                            color: _theme.isDark
                                ? AppColors.primaryLight
                                : _accent,
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
                                    color: _theme.isDark
                                        ? AppColors.primaryLight
                                        : _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _addressController.text,
                                  style: TextStyle(
                                    color: _theme.ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                                if (_cityController.text.trim().isNotEmpty ||
                                    _regionController.text
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      _cityController.text.trim(),
                                      _regionController.text.trim(),
                                    ].where((s) => s.isNotEmpty).join(', '),
                                    style: TextStyle(
                                      color: _theme.muted,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
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
                color: isHighlighted ? Colors.red : _theme.ink,
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
          style: _fieldTextStyle(fontSize: compact ? 13 : 14),
          cursorColor: _theme.inputText,
          decoration: InputDecoration(
            isDense: compact,
            prefixIcon: Icon(
              icon,
              color: isHighlighted ? Colors.red : _theme.muted,
              size: compact ? 18 : 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _fieldBorder(highlighted: isHighlighted),
                width: isHighlighted ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _fieldBorder(highlighted: isHighlighted),
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
            fillColor: _fieldFill(highlighted: isHighlighted),
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
                color: _highlightPhoneField ? Colors.red : _theme.ink,
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
          style: _fieldTextStyle(fontSize: compact ? 13 : 14),
          cursorColor: _theme.inputText,
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
                color: currentLength == maxLength ? _accent : _theme.inputHint,
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
                  Text('+233',
                      style: _fieldTextStyle(fontSize: compact ? 13 : 15)),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _fieldBorder(highlighted: _highlightPhoneField),
                width: _highlightPhoneField ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : _fieldRadius),
              borderSide: BorderSide(
                color: _fieldBorder(highlighted: _highlightPhoneField),
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
            fillColor: _fieldFill(highlighted: _highlightPhoneField),
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
                  color: _theme.fieldBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _theme.border),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _theme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            style: _fieldTextStyle(fontSize: 13),
            cursorColor: _theme.inputText,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. gate code, landmarks, or special instructions',
              hintStyle: TextStyle(
                color: _theme.inputHint,
                fontSize: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _fieldBorder()),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _fieldBorder()),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _accent, width: 2),
              ),
              filled: true,
              fillColor: _fieldFill(),
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
      unawaited(_clearStaleUrgentFeeIfNeeded());
      return;
    }

    // Defer add-xpress-fee API until continue (after calculate-delivery-fee).
    // Calling it here leaves the server cart at merchandise + xpress only.
    _setStateIfMounted(() {
      _isOrderUrgent = true;
      _emergencyOrderFee ??= DeliveryService.defaultXpressFee;
    });
  }

  Future<bool> _applyUrgentFeeToServerCart() async {
    if (!_isOrderUrgent) return true;

    final result = await DeliveryService.addXpressFee();
    if (!mounted) return false;

    if (result != null && result['xpress_fee'] != null) {
      _setStateIfMounted(() {
        _emergencyOrderFee = (result['xpress_fee'] is num)
            ? (result['xpress_fee'] as num).toDouble()
            : double.tryParse(result['xpress_fee'].toString());
      });
      return true;
    }

    _setStateIfMounted(() {
      _isOrderUrgent = false;
      _emergencyOrderFee = null;
    });
    if (!mounted) return false;
    AppErrorUtils.showSnack(
      context,
      'Urgent delivery is unavailable right now. Please try again.',
      isError: true,
      duration: const Duration(seconds: 2),
    );
    return false;
  }

  Future<void> _clearStaleUrgentFeeIfNeeded() async {
    if (!mounted) return;
    final locationIds = await _resolveBillingLocationIdsSafe(skipLookup: true);
    final billingCoords = _billingCoordinates();
    await DeliveryService.clearStaleUrgentFeeOnServer(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text,
      deliveryOption: deliveryOption,
      region: deliveryOption == 'delivery'
          ? _regionController.text.trim()
          : null,
      city:
          deliveryOption == 'delivery' ? _cityController.text.trim() : null,
      address: deliveryOption == 'delivery'
          ? _addressController.text.trim()
          : null,
      regionId: locationIds.regionId,
      cityId: locationIds.cityId,
      lat: billingCoords.lat,
      lng: billingCoords.lng,
      distanceText: _lastFeeDistanceText,
    );
  }

  Widget _buildUrgentOption() {
    final isOn = _isOrderUrgent;
    const urgentRed = Color(0xFFD32F2F);
    const urgentOrange = Color(0xFFEA580C);
    final isDark = _theme.isDark;

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
                ? (isDark
                    ? [
                        urgentRed.withValues(alpha: 0.18),
                        _theme.surface,
                        _theme.surface,
                      ]
                    : [
                        Colors.red.shade50,
                        const Color(0xFFFFF5F5),
                        Colors.white,
                      ])
                : (isDark
                    ? [
                        urgentOrange.withValues(alpha: 0.14),
                        _theme.surface,
                      ]
                    : [
                        const Color(0xFFFFF7ED),
                        const Color(0xFFFFFBEB),
                        Colors.white,
                      ]),
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOn
                ? urgentRed.withValues(alpha: isDark ? 0.55 : 0.45)
                : urgentOrange.withValues(alpha: isDark ? 0.5 : 0.55),
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
                            color: isOn
                                ? urgentRed
                                : (isDark
                                    ? urgentOrange.withValues(alpha: 0.95)
                                    : const Color(0xFF9A3412)),
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
                          ? (isDark
                              ? Colors.red.shade300
                              : Colors.red.shade800.withValues(alpha: 0.75))
                          : _theme.muted,
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
              inactiveTrackColor: isDark ? _theme.border : Colors.grey.shade600,
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
    final subtotalLoading = !_hasMerchandiseSubtotalForSummary;
    final deliveryFeeLoading = isDelivery &&
        !_effectiveShippingFree &&
        (_isFetchingDeliveryFee ||
            (!_deliveryFeeFromApi && deliveryFee <= 0));

    if (subtotalLoading && deliveryFeeLoading) {
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
              decoration: _innerPanelDecoration(),
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
                  Divider(height: 20, thickness: 1, color: _theme.border),
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

    final totals = _checkoutTotals;
    final subtotal = totals.merchandiseSubtotal;
    final discountAmount = totals.discount;
    final deliveryCharge = totals.chargedDeliveryFee;
    final total = totals.total;

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
            decoration: _innerPanelDecoration(),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Subtotal',
                  subtotal,
                  icon: Icons.shopping_cart_rounded,
                  isLoading: subtotalLoading,
                ),
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
                    isFree: _effectiveShippingFree,
                    isLoading: deliveryFeeLoading,
                  ),
                ],
                if (emergencyOrderFee > 0) ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow('Xpress order fee', emergencyOrderFee,
                      icon: Icons.flash_on),
                ],
                Divider(height: 20, thickness: 1, color: _theme.border),
                _buildSummaryRow(
                  'Total',
                  total,
                  isHighlighted: true,
                  icon: Icons.payment_rounded,
                  isLoading: subtotalLoading ||
                      (isDelivery &&
                          deliveryFeeLoading &&
                          !_effectiveShippingFree),
                ),
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
            color: isHighlighted ? _accent : _theme.muted,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              fontSize: isHighlighted ? 13 : 12,
              color: isHighlighted ? _theme.ink : _theme.muted,
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
          color: _theme.inputHint,
        ),
      );
    }

    if (isFree) {
      return Text(
        'Free',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: _theme.isDark ? Colors.green.shade400 : Colors.green.shade700,
        ),
      );
    }

    return Text(
      'GHS ${value.toStringAsFixed(2)}',
      style: TextStyle(
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
        fontSize: isHighlighted ? 15 : 12,
        color: isHighlighted ? _accent : _theme.ink,
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
          onTap: _isProceedingToPayment
              ? null
              : () async {
                  if (!mounted) return;
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

                  // Validate delivery location (map pick → region, city, address, coordinates)
                  if (deliveryOption == 'delivery' &&
                      (_regionController.text.trim().isEmpty ||
                          _cityController.text.trim().isEmpty ||
                          _addressController.text.trim().isEmpty ||
                          !_deliveryCoordinatesValid())) {
                    setState(() {
                      _highlightRegionField = true;
                      _highlightCityField = true;
                      _highlightAddressField = true;
                      isValid = false;
                    });
                    _scrollToError(addressSectionKey,
                        errorType: 'delivery location');
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
                    if (_nameController.text.trim().isEmpty) {
                      missing.add('name');
                    }
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
                          _cityController.text.trim().isEmpty ||
                          !_deliveryCoordinatesValid()) {
                        missing.add(
                            'delivery address (tap "Pick location on map")');
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
                    _feeUpdateGeneration++;
                    setState(() => _isProceedingToPayment = true);

                    // Always save billing on Continue so delivery fee is on the server cart.
                    await _prepareServerCartForSaveBilling();
                    if (!mounted) return;

                    final locationIds = await _resolveBillingLocationIdsSafe(
                      skipLookup: false,
                    );
                    final billingCoords = _billingCoordinates();
                    int? nearestStoreId;
                    if (deliveryOption == 'delivery' &&
                        billingCoords.lat != null &&
                        billingCoords.lng != null) {
                      nearestStoreId = await _nearestDeliveryStoreId(
                        lat: billingCoords.lat!,
                        lng: billingCoords.lng!,
                      );
                    }
                    Map<String, dynamic> saveResult;
                    if (kDebugMode) {
                      debugPrint(
                        '[DELIVERY] Continue → calling /save-billing-add '
                        '(distance=$_lastFeeDistanceText)',
                      );
                    }
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
                        pickupRegion: (deliveryOption == 'pickup' &&
                                selectedRegion != null)
                            ? selectedRegion!['description']?.toString()
                            : null,
                        pickupCity: (deliveryOption == 'pickup' &&
                                selectedCity != null)
                            ? selectedCity!['description']?.toString()
                            : null,
                        pickupSite: (deliveryOption == 'pickup' &&
                                selectedPickupSite != null)
                            ? selectedPickupSite!['description']?.toString()
                            : null,
                        regionId: locationIds.regionId,
                        cityId: locationIds.cityId,
                        storeId: locationIds.storeId ?? nearestStoreId,
                        lat: billingCoords.lat,
                        lng: billingCoords.lng,
                        distanceText: _lastFeeDistanceText,
                        orderUrgent: _isOrderUrgent,
                        clearStaleUrgentFee: false,
                      );
                    } catch (e, st) {
                      debugPrint(
                          '❌ [DELIVERY] saveDeliveryInfo threw: $e\n$st');
                      if (!mounted) return;
                      _showDeliverySnack(
                        'Could not save delivery details. Please try again.',
                      );
                      return;
                    }

                    if (saveResult['success'] == true) {
                      _recordBillingSync(saveResult);
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
                      forceRefreshBeforePayment: true,
                    );
                    if (!mounted) return;

                    if (!await _applyUrgentFeeToServerCart()) return;

                    if (!mounted) return;

                    if (deliveryOption == 'delivery' && !_deliveryFeeFromApi) {
                      _showDeliverySnack(
                        _lastDeliveryErrorMessage ??
                            'Could not calculate delivery fee. Reselect your location on the map and try again.',
                      );
                      return;
                    }

                    checkoutLog(
                        '🚀 [DELIVERY] Fee passed to payment: $deliveryFee');

                    if (!mounted) return;
                    _proceedToPayment();
                  } catch (e, st) {
                    debugPrint(
                        '❌ [DELIVERY] Continue to payment failed: $e\n$st');
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
        _ensurePickupRegionsLoaded();
      }
    });
  }

  void _proceedToPayment() {
    // Create delivery address based on option
    String deliveryAddress;
    final billingCoords = _billingCoordinates();
    final paymentLat = billingCoords.lat;
    final paymentLng = billingCoords.lng;
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
    unawaited(_persistGuestCheckoutDraft());

    final totals = _checkoutTotals;
    final confirmedDeliveryFee =
        deliveryOption == 'delivery' ? totals.deliveryFee : 0.0;
    checkoutLog(
      '[DELIVERY] → PaymentPage totals: merchandise=${totals.merchandiseSubtotal}, '
      'delivery(raw)=${totals.deliveryFee}, delivery(charged)=${totals.chargedDeliveryFee}, '
      'xpress=${totals.emergencyOrderFee}, total=${totals.payableAmount}, '
      'confirmedDeliveryFee=$confirmedDeliveryFee',
    );

    _pushPageOnce(
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          orderTotals: totals,
          lockedDeliveryFee:
              confirmedDeliveryFee > 0 ? confirmedDeliveryFee : null,
          lockedXpressFee: totals.emergencyOrderFee,
          deliveryAddress: deliveryAddress,
          contactNumber: _phoneController.text,
          deliveryOption: deliveryOption,
          guestEmail: _emailController.text.trim(),
          lat: paymentLat,
          lng: paymentLng,
          estimatedDeliveryTime: _apiDeliveryTime,
          distanceKm: _distanceKm,
          feeDistanceText: _lastFeeDistanceText,
          isOrderUrgent: _isOrderUrgent,
          billingCartSynced: true,
          streetAddress: _addressController.text.trim(),
          deliveryCity: _cityController.text.trim(),
          deliveryRegion: _regionController.text.trim(),
          billingRegionId: _cachedBillingRegionId,
          billingCityId: _cachedBillingCityId,
        ),
      ),
    );
  }

  void _switchToPickupFromOutsideGeofence() {
    _handleDeliveryOptionChange('pickup');
    _scrollToError(pickupSectionKey);
  }

  bool _deliveryCoordinatesValid() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  /// Show map picker to select exact delivery location.
  void _showMapPicker() async {
    if (!mounted) return;

    const defaultLat = 5.6037;
    const defaultLng = -0.1870;
    var initialLat = defaultLat;
    var initialLng = defaultLng;

    if (_deliveryCoordinatesValid()) {
      initialLat = _latitude!;
      initialLng = _longitude!;
    } else if (_addressController.text.trim().isNotEmpty) {
      try {
        var cleanAddress = _addressController.text.trim();
        cleanAddress =
            cleanAddress.replaceAll(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{3}'), '');
        cleanAddress = cleanAddress.replaceAll(RegExp(r',+'), ',');
        cleanAddress =
            cleanAddress.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');

        final fullAddress =
            '$cleanAddress, ${_cityController.text.trim()}, ${_regionController.text.trim()}, Ghana';

        final locations = await locationFromAddress(fullAddress);
        if (!mounted) return;

        if (locations.isNotEmpty) {
          final location = locations.first;
          initialLat = location.latitude;
          initialLng = location.longitude;
        }
      } catch (e) {
        checkoutLog('🗺️ [MAP PICKER] Geocode error: $e');
      }
    }

    if (!mounted) return;
    _pushPageOnce(
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          onOfferPickup: _switchToPickupFromOutsideGeofence,
          onLocationSelected: (double lat, double lng, String? address) {
            _onDeliveryLocationSelected(lat, lng, address: address);
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
      final placemarks = await placemarkFromCoordinates(lat, lng);

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

        final address = _buildReadableAddressFromPlacemark(placemark);

        if (mounted) {
          _invalidateBillingLocationCache();
          _runWithSuppressedAddressFeeRefresh(() {
            setState(() {
              // Update region with administrative area
              if (placemark.administrativeArea != null &&
                  placemark.administrativeArea!.isNotEmpty) {
                _regionController.text = placemark.administrativeArea!;
              }

              if (placemark.locality != null &&
                  placemark.locality!.isNotEmpty) {
                _cityController.text = placemark.locality!;
              }

              _addressController.text = (preferredAddress ?? address).trim();

              // Clear validation highlights since user picked a valid location
              _highlightRegionField = false;
              _highlightCityField = false;
              _highlightAddressField = false;
            });
          });
        }
      }
    } catch (e) {
      checkoutLog('❌ Reverse geocoding error: $e');
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

            for (final region in rawRegions) {
              try {
                final description = region['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueRegions.containsKey(description)) {
                  uniqueRegions[description] = region;
                }
              } catch (_) {
                continue;
              }
            }

            final allRegions = uniqueRegions.values.toList();

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
              }
            }
          });
        } catch (e) {
          checkoutLog('❌ [REGIONS] Error setting regions state: $e');
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
        _regionsLoadFuture = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingRegions = false;
      });
      debugPrint('Error loading regions: $e');
    } finally {
      if (regions.isEmpty) {
        _regionsLoadFuture = null;
      }
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
      final citiesData =
          await DeliveryService.getCitiesForRegionCached(regionId);
      if (!mounted) return;
      setState(() {
        cities = List<Map<String, dynamic>>.from(citiesData);
        _citiesCache[regionId] = cities;
        isLoadingCities = false;

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
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cities = [];
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

            for (final store in storesData) {
              try {
                final normalized = DeliveryService.normalizeStoreMap(store);
                final description = normalized['description']?.toString() ?? '';
                if (description.isNotEmpty &&
                    !uniqueStores.containsKey(description)) {
                  uniqueStores[description] = normalized;
                }
              } catch (_) {
                continue;
              }
            }

            stores = uniqueStores.values.toList();
            _storesCache[cityId] = uniqueStores.values.toList();
            isLoadingStores = false;

            if (selectedPickupSite != null) {
              final storeExists =
                  stores.any((s) => s['id'] == selectedPickupSite!['id']);
              if (!storeExists) {
                selectedPickupSite = null;
              }
            }
          });
        } catch (e) {
          checkoutLog('❌ [STORES] Error setting stores state: $e');
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
