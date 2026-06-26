import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/category_fetch_result.dart';
import '../models/delivery_geofence.dart';
import '../models/store_location_model.dart';
import '../repositories/delivery_repository.dart';
import '../utils/delivery_api_parser.dart';
import '../utils/delivery_geofence_parser.dart';
import 'package:eclapp/services/auth_service.dart';
import '../utils/checkout_log.dart';
import '../utils/app_error_utils.dart';

class DeliveryService {
  static const String baseUrl = ApiConfig.baseUrl;

  static final DeliveryRepository _repository = DeliveryRepositoryImpl();

  /// Timeout for delivery API calls. Shorter = fail fast and use local fallback.
  static const Duration _apiTimeout = Duration(seconds: 5);

  static final Map<String, Map<String, dynamic>> _deliveryFeeApiCache = {};

  static List<Map<String, dynamic>>? _storesForFeeEstimateCache;
  static DateTime? _storesForFeeEstimateCachedAt;
  static Future<List<Map<String, dynamic>>>? _storesForFeeEstimateLoadFuture;
  static const Duration _storesCacheTtl = Duration(hours: 6);

  static final Map<int, List<Map<String, dynamic>>> _citiesByRegionCache = {};
  static final Map<int, DateTime> _citiesByRegionCachedAt = {};
  static final Map<int, Future<List<Map<String, dynamic>>>>
      _citiesByRegionInFlight = {};
  static const Duration _citiesCacheTtl = Duration(hours: 6);

  // Delivery pricing constants
  // Base fee = 20
  // Base distance = 3 km
  // Extra distance rate (X) per km
  static const double baseDeliveryFee = 20.0;
  static const double baseDeliveryDistanceKm = 3.0;
  static const double defaultRatePerKm = 3.0; // X: change this if needed

  static dynamic _decodedPayload(CategoryFetchResult result) {
    if (result.body != null) return result.body;
    final raw = result.rawBody;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return json.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Single store map with parsed coords, address, and formatted hours.
  static Map<String, dynamic> normalizeStoreMap(Map<String, dynamic> raw) {
    return normalizeDeliveryStoreMap(raw);
  }

  /// Call /add-xpress-fee API to add express/urgent delivery fee
  static const Duration _feeApiRetryDelay = Duration(milliseconds: 400);

  /// Default xpress surcharge for UI until continue confirms via API.
  static const double defaultXpressFee = 15.0;

  static Future<Map<String, dynamic>?> addXpressFee({
    int maxAttempts = 2,
  }) async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      String? token;
      String? guestId;
      if (isLoggedIn) {
        token = await AuthService.getToken();
      } else {
        final prefs = await SharedPreferences.getInstance();
        guestId = prefs.getString('guest_id');
      }
      if (!isLoggedIn && (guestId == null || guestId.isEmpty)) {
        debugPrint('add-xpress-fee: Guest auth required');
        return null;
      }
      if (isLoggedIn && (token == null || token.isEmpty)) {
        debugPrint('add-xpress-fee: Auth required');
        return null;
      }
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) ...{
          'Authorization': 'Guest $guestId',
          'X-Guest-ID': guestId,
        },
      };

      CategoryFetchResult? result;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        result = await _repository.addXpressFee(headers: headers);
        debugPrint(
          '[add-xpress-fee] attempt $attempt/$maxAttempts '
          'status=${result.statusCode}',
        );
        debugPrint('[add-xpress-fee] Response body: ${result.rawBody}');
        if (result.statusCode == 200 || result.statusCode == 201) {
          break;
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(_feeApiRetryDelay);
        }
      }

      final last = result;
      if (last == null) return null;
      if (last.statusCode == 200 || last.statusCode == 201) {
        final data = _decodedPayload(last);
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('add-xpress-fee error: $e');
      return null;
    }
  }

  static String _normalizeLocationLabel(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static bool _locationLabelsMatch(String a, String b) {
    final left = _normalizeLocationLabel(a);
    final right = _normalizeLocationLabel(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    return left.contains(right) || right.contains(left);
  }

  /// Match a geocoded or user-entered label to a region row from [/regions].
  static Map<String, dynamic>? findRegionInList(
    List<Map<String, dynamic>> regions,
    String label,
  ) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    for (final region in regions) {
      final name =
          (region['description'] ?? region['name'] ?? region['title'] ?? '')
              .toString();
      if (_locationLabelsMatch(name, trimmed)) {
        return region;
      }
    }
    return null;
  }

  /// Match a city label within a region via cached [/regions/{id}/cities].
  static Future<Map<String, dynamic>?> findCityInRegion(
    int regionId,
    String label,
  ) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || regionId <= 0) return null;

    final cities = await getCitiesForRegionCached(regionId);
    for (final raw in cities) {
      final city = Map<String, dynamic>.from(raw);
      final name = (city['description'] ?? city['name'] ?? city['title'] ?? '')
          .toString();
      if (_locationLabelsMatch(name, trimmed)) {
        return city;
      }
    }
    return null;
  }

  /// Cached city rows for a region (shared by billing lookup and pickup UI).
  static Future<List<Map<String, dynamic>>> getCitiesForRegionCached(
    int regionId,
  ) async {
    if (regionId <= 0) return const [];

    final cachedAt = _citiesByRegionCachedAt[regionId];
    final cachedRows = _citiesByRegionCache[regionId];
    if (cachedRows != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _citiesCacheTtl) {
      return cachedRows;
    }

    final inFlight = _citiesByRegionInFlight[regionId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchAndCacheCitiesForRegion(regionId);
    _citiesByRegionInFlight[regionId] = future;
    try {
      return await future;
    } finally {
      _citiesByRegionInFlight.remove(regionId);
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAndCacheCitiesForRegion(
    int regionId,
  ) async {
    final result = await getCitiesByRegion(regionId);
    if (result['success'] != true || result['data'] is! List) {
      return _citiesByRegionCache[regionId] ?? const [];
    }

    final uniqueCities = <String, Map<String, dynamic>>{};
    for (final raw in result['data'] as List) {
      if (raw is! Map) continue;
      final city = Map<String, dynamic>.from(raw);
      final description = city['description']?.toString() ?? '';
      if (description.isNotEmpty && !uniqueCities.containsKey(description)) {
        uniqueCities[description] = city;
      }
    }

    final rows = uniqueCities.values.toList();
    _citiesByRegionCache[regionId] = rows;
    _citiesByRegionCachedAt[regionId] = DateTime.now();
    return rows;
  }

  /// Provisional distance label from coordinates + cached stores (for parallel fee API).
  static Future<String?> provisionalDistanceTextForCoordinates({
    required double lat,
    required double lng,
  }) async {
    final stores = await getStoresForFeeEstimate();
    final estimate = estimateFeeFromCoordinates(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    return estimate?['distance_text']?.toString();
  }

  /// Runs save-billing and calculate-delivery-fee concurrently when distance is known.
  static Future<
      ({
        Map<String, dynamic> saveResult,
        Map<String, dynamic>? feeResult,
      })> saveBillingAndCalculateFeeParallel({
    required Future<Map<String, dynamic>> saveFuture,
    String? provisionalDistanceText,
    bool fallbackToLocalEstimate = true,
  }) async {
    final trimmedDistance = provisionalDistanceText?.trim() ?? '';
    final feeFuture = trimmedDistance.isNotEmpty
        ? fetchDeliveryFeeFromApi(
            distanceText: trimmedDistance,
            fallbackToLocalEstimate: fallbackToLocalEstimate,
          )
        : Future<Map<String, dynamic>?>.value(null);

    final results = await Future.wait<dynamic>([
      saveFuture,
      feeFuture,
    ]);

    return (
      saveResult: Map<String, dynamic>.from(results[0] as Map),
      feeResult: results[1] as Map<String, dynamic>?,
    );
  }

  /// Adds lat/lng (and aliases) to save-billing-add when coordinates are known.
  @visibleForTesting
  static void attachBillingCoordinates(
    Map<String, dynamic> body, {
    double? lat,
    double? lng,
  }) {
    if (lat == null || lng == null) return;
    body['lat'] = lat;
    body['lng'] = lng;
    body['latitude'] = lat;
    body['longitude'] = lng;
    body['coordinates'] = [lat, lng];
  }

  static void _logSaveBillingExchange({
    required Map<String, dynamic> requestBody,
    required int statusCode,
    String? responseBody,
  }) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');
    final url = ApiConfig.getEndpointUrl(ApiConfig.saveBillingAddress);

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('[SAVE-BILLING-ADD] POST $url');
    debugPrint('── Request body ──');
    debugPrint(encoder.convert(requestBody));
    debugPrint('── Response HTTP $statusCode ──');
    if (responseBody != null && responseBody.trim().isNotEmpty) {
      try {
        final decoded = json.decode(responseBody);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(responseBody);
      }
    } else {
      debugPrint('(empty body)');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  static void _logGetBillingResponse({
    required int statusCode,
    String? responseBody,
  }) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');
    final url = ApiConfig.getEndpointUrl(ApiConfig.getBillingAddress);

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('[GET-BILLING-ADD] GET $url');
    debugPrint('── Response HTTP $statusCode ──');
    if (responseBody != null && responseBody.trim().isNotEmpty) {
      try {
        final decoded = json.decode(responseBody);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(responseBody);
      }
    } else {
      debugPrint('(empty body)');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// Order summary / fee fields from get-billing-add or save-billing-add JSON.
  @visibleForTesting
  static Map<String, dynamic>? billingCheckoutPayloadFromResponse(
    Map<String, dynamic> responseMap,
  ) {
    final data = responseMap['data'];
    final root = data is Map
        ? Map<String, dynamic>.from(data)
        : responseMap;

    final billingAddr = root['billingAddr'];
    final addr = billingAddr is Map
        ? Map<String, dynamic>.from(billingAddr)
        : null;

    final closestRaw = root['closest_store'];
    final closestStore = closestRaw is Map
        ? Map<String, dynamic>.from(closestRaw)
        : null;

    final promoRaw = root['promo_details'];
    final promo =
        promoRaw is Map ? Map<String, dynamic>.from(promoRaw) : null;

    final deliveryFee =
        root['delivery_fee'] ?? addr?['delivery_fee'] ?? closestStore?['delivery_fee'];

    final hasCheckout = promo != null ||
        closestStore != null ||
        deliveryFee != null ||
        root['selected_store_description'] != null;
    if (!hasCheckout) return null;

    return {
      'success': true,
      if (promo != null) 'promo_details': promo,
      if (closestStore != null) 'closest_store': closestStore,
      if (deliveryFee != null) 'delivery_fee': deliveryFee,
      if (root['selected_store_description'] != null)
        'selected_store_description': root['selected_store_description'],
      if (addr?['distance_text'] != null) 'distance_text': addr!['distance_text'],
      if (addr?['order_urgent'] == true || addr?['is_urgent'] == true)
        'order_urgent': true,
      if (addr?['xpress_fee'] != null) 'xpress_fee': addr!['xpress_fee'],
      if (addr?['emergency_order_fee'] != null)
        'emergency_order_fee': addr!['emergency_order_fee'],
    };
  }

  static int? _billingLocationId(dynamic raw) {
    if (raw is int) return raw > 0 ? raw : null;
    return int.tryParse('${raw ?? ''}');
  }

  // save where they want stuff delivered
  static Future<Map<String, dynamic>> saveDeliveryInfo({
    required String name,
    required String email,
    required String phone,
    required String deliveryOption,
    String? region,
    String? city,
    String? address,
    String? notes,
    String? pickupRegion,
    String? pickupCity,
    String? pickupSite,
    int? regionId,
    int? cityId,
    int? storeId,
    double? lat,
    double? lng,
    double? deliveryFee,
    String? distanceText,
    bool? orderUrgent,
    double? emergencyOrderFee,

    /// When true, tells the API to drop any leftover xpress/urgent fee from a
    /// prior checkout session (non-urgent orders only).
    bool clearStaleUrgentFee = false,
  }) async {
    try {
      // check if theyre logged in or just a guest
      final isLoggedIn = await AuthService.isLoggedIn();
      String? token;
      String? guestId;
      if (isLoggedIn) {
        token = await AuthService.getToken();
      } else {
        final prefs = await SharedPreferences.getInstance();
        guestId = prefs.getString('guest_id');
      }

      if (!isLoggedIn && (guestId == null || guestId.isEmpty)) {
        return {
          'success': false,
          'message': 'Guest authentication required. Please try again.',
        };
      }
      if (isLoggedIn && (token == null || token.isEmpty)) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
        };
      }

      // build the request body with all the info
      final Map<String, dynamic> requestBody = {
        'fname': name, // their name
        'email': email, // email address
        'phone': phone, // phone number
        'shipping_type': deliveryOption, // either delivery or pickup
      };

      // add extra stuff if we have it
      if (deliveryOption.isNotEmpty) {
        requestBody['delivery_option'] = deliveryOption;
      }
      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
        // Backend billing address schema expects this field for location hints.
        requestBody['landmark'] = notes;
      }

      final resolvedRegionId = regionId ?? 0;
      final resolvedCityId = cityId ?? 0;
      final resolvedStoreId = storeId ?? 0;
      if (resolvedRegionId > 0) {
        requestBody['region_id'] = resolvedRegionId;
      }
      if (resolvedCityId > 0) {
        requestBody['city_id'] = resolvedCityId;
      }
      if (resolvedStoreId > 0) {
        requestBody['store_id'] = resolvedStoreId;
        requestBody['pickup_site_id'] = resolvedStoreId;
      }

      // different fields depending on if its delivery or pickup
      if (deliveryOption == 'delivery') {
        // if they want it delivered, we need their address
        requestBody['addr_1'] = address ?? 'Not specified';
        requestBody['region'] = region ?? 'Not specified';
        requestBody['city'] = city ?? 'Not specified';
        if (deliveryFee != null && deliveryFee > 0) {
          requestBody['delivery_fee'] = deliveryFee;
        }
        final trimmedDistance = distanceText?.trim() ?? '';
        if (trimmedDistance.isNotEmpty) {
          requestBody['distance_text'] = trimmedDistance;
        }
      } else if (deliveryOption == 'pickup') {
        // if theyre picking it up, we need the store info
        requestBody['addr_1'] = 'Pickup order';
        final regionLabel = pickupRegion ?? 'Not specified';
        final cityLabel = pickupCity ?? 'Not specified';
        requestBody['region'] = regionLabel;
        requestBody['city'] = cityLabel;
        requestBody['pickup_region'] = regionLabel;
        requestBody['pickup_city'] = cityLabel;
        if (pickupSite != null && pickupSite.isNotEmpty) {
          requestBody['pickup_site'] = pickupSite;
        }
        // Backend expects store id for pickup_location (not display name only)
        if (resolvedStoreId > 0) {
          requestBody['pickup_location'] = resolvedStoreId.toString();
        } else if (pickupSite != null && pickupSite.isNotEmpty) {
          requestBody['pickup_location'] = pickupSite;
        } else {
          requestBody['pickup_location'] = '';
        }
      }

      attachBillingCoordinates(requestBody, lat: lat, lng: lng);

      if (emergencyOrderFee != null && emergencyOrderFee > 0) {
        requestBody['order_urgent'] = true;
        requestBody['is_urgent'] = true;
        requestBody['emergency_order_fee'] = emergencyOrderFee;
        requestBody['xpress_fee'] = emergencyOrderFee;
      } else if (orderUrgent == true) {
        requestBody['order_urgent'] = true;
        requestBody['is_urgent'] = true;
      } else if (clearStaleUrgentFee) {
        requestBody['order_urgent'] = false;
        requestBody['is_urgent'] = false;
        requestBody['xpress_fee'] = 0;
        requestBody['emergency_order_fee'] = 0;
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) ...{
          'Authorization': 'Guest $guestId',
          'X-Guest-ID': guestId,
        },
      };

      final result = await _repository.saveBillingAddress(
        headers: headers,
        body: json.encode(requestBody),
        timeout: _apiTimeout,
      );

      _logSaveBillingExchange(
        requestBody: requestBody,
        statusCode: result.statusCode,
        responseBody: result.rawBody,
      );

      if (result.statusCode == 200 || result.statusCode == 201) {
        final data = _decodedPayload(result);
        if (data is! Map) {
          return {
            'success': false,
            'message': 'Failed to save delivery information',
          };
        }
        final responseMap = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data);

        final closestStore = responseMap['closest_store'];
        final selectedStoreDescription =
            responseMap['selected_store_description'];

        final resolvedStore =
            closestStore ?? responseMap['data']?['closest_store'];

        return {
          'success': true,
          'message': responseMap['message'] ??
              'Delivery information saved successfully',
          'status': responseMap['status'] ?? 'success',
          'closest_store': resolvedStore,
          'selected_store_description': selectedStoreDescription,
          'delivery_fee': responseMap['delivery_fee'] ??
              responseMap['data']?['delivery_fee'],
          'promo_details': responseMap['promo_details'] ??
              responseMap['data']?['promo_details'],
          'data': responseMap,
        };
      } else {
        final errorData = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
        return {
          'success': false,
          'message': AppErrorUtils.messageFromMap(
            errorData,
            fallback: result.statusCode == 500
                ? 'Could not verify your delivery address. Please try again or pick a location on the map.'
                : 'Failed to save delivery information',
          ),
        };
      }
    } catch (e, st) {
      AppErrorUtils.log('DeliveryService.saveDeliveryInfo', e, st);
      return AppErrorUtils.failure(
        e,
        fallback: 'Failed to save delivery information',
      );
    }
  }

  // get the last address they saved
  static Future<Map<String, dynamic>> getLastDeliveryInfo() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (isLoggedIn) {
        // Use getAuthHeaders for consistent auth - prefers in-memory token (avoids keychain/SharedPreferences sync issues)
        final authHeaders = await AuthService.getAuthHeaders();
        final authHeader = authHeaders['Authorization'];
        if (authHeader == null || authHeader.isEmpty) {
          return {
            'success': false,
            'message': 'Authentication required. Please log in again.',
          };
        }
        headers['Authorization'] = authHeader;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final guestId = prefs.getString('guest_id');
        if (guestId == null || guestId.isEmpty) {
          return {
            'success': false,
            'message': 'Guest session required. Please try again.',
          };
        }
        headers['X-Guest-ID'] = guestId;
        headers['Authorization'] = 'Guest $guestId';
      }

      final result = await _repository.getBillingAddress(
        headers: headers,
        timeout: _apiTimeout,
      );

      _logGetBillingResponse(
        statusCode: result.statusCode,
        responseBody: result.rawBody,
      );

      if (result.statusCode == 200) {
        final data = _decodedPayload(result);
        if (data is! Map) {
          return {
            'success': false,
            'message': 'Failed to retrieve delivery information',
          };
        }
        final responseMap = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data);

        if (responseMap['data'] == null) {
          return {
            'success': true,
            'data': null,
            'message': 'No delivery data found in response',
          };
        }

        final billingAddr = responseMap['data']['billingAddr'];
        if (billingAddr == null) {
          debugPrint('\n❌ NO BILLING ADDR IN RESPONSE');
          return {
            'success': true,
            'data': null,
            'message': 'No billing address found in response',
          };
        }

        final dataRoot = responseMap['data'];
        final dataMap =
            dataRoot is Map ? Map<String, dynamic>.from(dataRoot) : null;
        final closestFromData = dataMap?['closest_store'];
        final closestDistance = closestFromData is Map
            ? closestFromData['distance_text']?.toString()
            : null;

        final deliveryData = {
          'name': billingAddr['fname'] ?? '',
          'email': billingAddr['email'] ?? '',
          'phone': billingAddr['phone'] ?? '',
          'delivery_option': (billingAddr['delivery_option'] ??
                  billingAddr['shipping_type'] ??
                  'delivery')
              .toLowerCase(),
          'region': billingAddr['region'] ?? '',
          'city': billingAddr['city'] ?? '',
          'address': billingAddr['addr_1'] ?? '',
          'notes': billingAddr['notes'] ?? billingAddr['landmark'] ?? '',
          'landmark': billingAddr['landmark'] ?? '',
          'pickup_region': billingAddr['pickup_region'] ?? '',
          'pickup_city': billingAddr['pickup_city'] ?? '',
          'pickup_site': billingAddr['pickup_site'] ??
              billingAddr['pickup_location'] ??
              '',
          'shipping_type': (billingAddr['shipping_type'] ??
                  billingAddr['delivery_option'] ??
                  'delivery')
              .toLowerCase(),
          'pickup_location': billingAddr['pickup_location'] ??
              billingAddr['pickup_site'] ??
              '',
          'lat': _parseBillingCoordinate(billingAddr['lat']),
          'lng': _parseBillingCoordinate(billingAddr['lng']),
          'region_id': _billingLocationId(billingAddr['region_id']),
          'city_id': _billingLocationId(billingAddr['city_id']),
          'store_id': _billingLocationId(
            billingAddr['store_id'] ?? billingAddr['pickup_site_id'],
          ),
          'distance_text':
              billingAddr['distance_text']?.toString() ?? closestDistance,
          'delivery_fee': billingAddr['delivery_fee'] ?? dataMap?['delivery_fee'],
        };

        final checkout =
            billingCheckoutPayloadFromResponse(responseMap);

        return {
          'success': true,
          'data': deliveryData,
          if (checkout != null) 'checkout': checkout,
          'message': responseMap['message'] ??
              'Delivery information retrieved successfully',
        };
      } else if (result.statusCode == 404) {
        debugPrint('=== API GET - NO DATA FOUND ===');
        debugPrint('Status: 404 - No previous delivery information found');
        debugPrint('================================');
        return {
          'success': true,
          'data': null,
          'message': 'No previous delivery information found',
        };
      } else if (result.statusCode == 401) {
        debugPrint(
            '=== API GET - UNAUTHORIZED (treating as no saved address) ===');
        return {
          'success': true,
          'data': null,
          'message': 'No previous delivery information found',
        };
      } else {
        final errorData = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
        debugPrint('=== API GET ERROR ===');
        debugPrint('Error status code: ${result.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('Error message: ${errorData?['message']}');
        debugPrint('====================');
        return {
          'success': false,
          'message': errorData?['message'] ??
              'Failed to retrieve delivery information',
        };
      }
    } catch (e) {
      debugPrint('Error getting delivery info: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  static double? _parseBillingCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  /// Google-style distance label for [calculate-delivery-fee].
  static String formatDistanceText(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Straight-line distance to the nearest store with valid coordinates (km).
  static double? nearestStoreDistanceKm({
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> stores,
  }) {
    double? bestKm;
    for (final raw in stores) {
      final store = StoreLocationModel.fromApiJson(
        Map<String, dynamic>.from(raw),
      );
      final storeLat = store.lat;
      final storeLng = store.lng;
      if (storeLat == null || storeLng == null) continue;
      final meters = Geolocator.distanceBetween(lat, lng, storeLat, storeLng);
      final km = meters / 1000.0;
      if (bestKm == null || km < bestKm) bestKm = km;
    }
    return bestKm;
  }

  /// Instant fee estimate from map coordinates (no save-billing-add round trip).
  static Map<String, dynamic>? estimateFeeFromCoordinates({
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> stores,
  }) {
    final distanceKm = nearestStoreDistanceKm(
      lat: lat,
      lng: lng,
      stores: stores,
    );
    if (distanceKm == null) return null;
    final fee = calculateDeliveryFeeByDistance(distanceKm);
    return {
      'distance_km': distanceKm,
      'distance_text': formatDistanceText(distanceKm),
      'delivery_fee': fee,
    };
  }

  /// Instant fee from distance_text using the same tiered formula as the server.
  static Map<String, dynamic>? localDeliveryFeeResult(String distanceText) {
    final parsed = calculateDeliveryFeeFromDistanceText(distanceText);
    if (parsed == null) return null;
    return {
      'distance': parsed['distanceKm'],
      'delivery_fee': parsed['fee'],
    };
  }

  /// Cached store list for map-based fee estimates (null until first load).
  static List<Map<String, dynamic>>? get cachedStoresForFeeEstimate =>
      _storesForFeeEstimateCache;

  /// Cached store list for map-based fee estimates (background preload).
  static Future<List<Map<String, dynamic>>> getStoresForFeeEstimate() async {
    if (_storesForFeeEstimateCache != null &&
        _storesForFeeEstimateCachedAt != null &&
        DateTime.now().difference(_storesForFeeEstimateCachedAt!) <
            _storesCacheTtl) {
      return _storesForFeeEstimateCache!;
    }

    _storesForFeeEstimateLoadFuture ??= _loadStoresForFeeEstimate();
    try {
      return await _storesForFeeEstimateLoadFuture!;
    } finally {
      _storesForFeeEstimateLoadFuture = null;
    }
  }

  static Future<List<Map<String, dynamic>>> _loadStoresForFeeEstimate() async {
    try {
      final result = await getAllStores();
      if (result['success'] == true && result['data'] is List) {
        final list = (result['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _storesForFeeEstimateCache = list;
        _storesForFeeEstimateCachedAt = DateTime.now();
        return list;
      }
    } catch (e) {
      debugPrint('getStoresForFeeEstimate error: $e');
    }
    return _storesForFeeEstimateCache ?? [];
  }

  /// Auth headers aligned with [saveDeliveryInfo] (Bearer vs Guest).
  static Future<Map<String, String>> deliveryAuthHeaders() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return {};
      return {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_id');
    if (guestId == null || guestId.isEmpty) return {};
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Guest $guestId',
      'X-Guest-ID': guestId,
    };
  }

  /// Loads the delivery zone boundary from `/delivery-geofence` for the map picker.
  static Future<DeliveryGeofence?> fetchDeliveryGeofence() async {
    try {
      final headers = await deliveryAuthHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        debugPrint('delivery-geofence: Auth required');
        return null;
      }

      final url = ApiConfig.getEndpointUrl(ApiConfig.deliveryGeofence);
      debugPrint('📤 [DELIVERY-GEOFENCE] GET $url');

      final result = await _repository.fetchDeliveryGeofence(
        headers: headers,
        timeout: _apiTimeout,
      );

      if (result.statusCode == 404 || result.statusCode == 405) {
        debugPrint(
          '📥 [DELIVERY-GEOFENCE] status=${result.statusCode} — '
          'route not registered on server yet (GET /delivery-geofence)',
        );
        return null;
      }

      debugPrint(
        '📥 [DELIVERY-GEOFENCE] status=${result.statusCode} body=${result.rawBody}',
      );

      if (result.statusCode != 200 && result.statusCode != 201) {
        return null;
      }

      final decoded = _decodedPayload(result);
      return DeliveryGeofenceParser.parseGeofenceResponse(decoded);
    } catch (e) {
      debugPrint('delivery-geofence error: $e');
      return null;
    }
  }

  /// Validates picked coordinates against `/validate-geofence`.
  static Future<GeofenceValidationResult> validateGeofence({
    required double lat,
    required double lng,
  }) async {
    try {
      final headers = await deliveryAuthHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        return const GeofenceValidationResult(
          isValid: false,
          message:
              'Please sign in or continue as guest to verify delivery area.',
        );
      }

      final url = ApiConfig.getEndpointUrl(ApiConfig.validateGeofence);
      final body = json.encode({
        'lat': lat,
        'lng': lng,
      });

      debugPrint('📤 [VALIDATE-GEOFENCE] POST $url');
      debugPrint('📤 [VALIDATE-GEOFENCE] body: $body');

      final result = await _repository.validateGeofence(
        headers: headers,
        body: body,
        timeout: _apiTimeout,
      );

      if (result.statusCode == 404 || result.statusCode == 405) {
        debugPrint(
          '📥 [VALIDATE-GEOFENCE] status=${result.statusCode} — '
          'route not registered on server yet (POST /validate-geofence)',
        );
        return const GeofenceValidationResult(
          isValid: false,
          checkedRemotely: false,
        );
      }

      debugPrint(
        '📥 [VALIDATE-GEOFENCE] status=${result.statusCode} body=${result.rawBody}',
      );

      if (result.statusCode == 0) {
        return const GeofenceValidationResult(
          isValid: false,
          message: 'Could not verify delivery area. Check your connection.',
        );
      }

      final decoded = _decodedPayload(result);
      final parsed = DeliveryGeofenceParser.parseValidationResponse(decoded);
      if (parsed != null) return parsed;

      if (result.statusCode == 200 || result.statusCode == 201) {
        return const GeofenceValidationResult(
          isValid: true,
          message: 'Location verified',
        );
      }

      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;

      return GeofenceValidationResult(
        isValid: false,
        message: message?.trim().isNotEmpty == true &&
                !AppErrorUtils.isTechnicalBackendMessage(message!.trim())
            ? message.trim()
            : DeliveryGeofenceCopy.outsideArea,
      );
    } catch (e) {
      debugPrint('validate-geofence error: $e');
      return const GeofenceValidationResult(
        isValid: false,
        message: 'Could not verify delivery area. Please try again.',
      );
    }
  }

  /// Parses calculate-delivery-fee JSON (supports nested `data` wrapper).
  static Map<String, dynamic>? parseCalculateDeliveryFeePayload(
    Map<String, dynamic> root,
  ) {
    final payloads = <Map<String, dynamic>>[root];
    final nested = root['data'];
    if (nested is Map) {
      payloads.add(Map<String, dynamic>.from(nested));
    }

    for (final map in payloads) {
      final deliveryFeeRaw =
          map['delivery_fee'] ?? map['deliveryFee'] ?? map['fee'];
      if (deliveryFeeRaw == null) continue;

      final feeValue = deliveryFeeRaw is num
          ? deliveryFeeRaw.toDouble()
          : (double.tryParse(deliveryFeeRaw.toString()) ?? 0.0);

      final distance = map['distance'] ?? map['distance_km'];
      double? distanceKm;
      if (distance is num) {
        distanceKm = distance.toDouble();
      } else if (distance != null) {
        distanceKm = double.tryParse(distance.toString()) ??
            parseDistanceTextToKm(distance.toString());
      }

      return {
        'distance': distanceKm,
        'delivery_fee': feeValue,
        'from_api': true,
      };
    }
    return null;
  }

  /// distance_text from a save-billing response (closest store).
  static String? distanceTextFromSaveResult(Map<String, dynamic> result) {
    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    final text = closestStore?['distance_text']?.toString() ??
        result['distance_text']?.toString() ??
        result['data']?['distance_text']?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text.trim();
  }

  static Map<String, dynamic>? promoDetailsFromSaveResult(
    Map<String, dynamic> result,
  ) {
    final promo = result['promo_details'];
    if (promo is Map) return Map<String, dynamic>.from(promo);
    final data = result['data'];
    if (data is Map) {
      final nested = data['promo_details'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return null;
  }

  static double? _readAmount(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('${raw ?? ''}'.replaceAll(',', '').trim());
  }

  /// Merchandise-only subtotal from save-billing [promo_details] (no delivery/xpress).
  static double? merchandiseSubtotalFromSaveResult(
    Map<String, dynamic>? result,
  ) {
    if (result == null || result['success'] != true) return null;
    final promo = promoDetailsFromSaveResult(result);
    if (promo == null) return null;
    return _readAmount(promo['running_subtotal']) ??
        _readAmount(promo['subtotal']);
  }

  /// Delivery fee quoted on a save-billing response (closest store / root).
  static double? deliveryFeeFromSaveResult(Map<String, dynamic>? result) {
    if (result == null || result['success'] != true) return null;
    final closestStore =
        result['closest_store'] ?? result['data']?['closest_store'];
    final raw = closestStore?['delivery_fee'] ??
        closestStore?['deliveryFee'] ??
        result['delivery_fee'] ??
        result['deliveryFee'] ??
        result['data']?['delivery_fee'] ??
        result['data']?['deliveryFee'];
    return _readAmount(raw);
  }

  static int? _locationIdFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final raw = map['id'] ?? map['region_id'] ?? map['city_id'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  /// Resolves backend region/city ids for save-billing-add.
  static Future<({int? regionId, int? cityId})> resolveBillingLocationIds({
    required String regionLabel,
    required String cityLabel,
  }) async {
    final trimmedRegion = regionLabel.trim();
    if (trimmedRegion.isEmpty) {
      return (regionId: null, cityId: null);
    }

    final regionsResult = await getRegions();
    if (regionsResult['success'] != true) {
      return (regionId: null, cityId: null);
    }

    final regionRows = (regionsResult['data'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final regionMatch = findRegionInList(regionRows, trimmedRegion);
    final regionId = _locationIdFromMap(
      regionMatch != null ? Map<String, dynamic>.from(regionMatch) : null,
    );
    if (regionId == null) {
      return (regionId: null, cityId: null);
    }

    int? cityId;
    final trimmedCity = cityLabel.trim();
    if (trimmedCity.isNotEmpty) {
      final cityMatch = await findCityInRegion(regionId, trimmedCity);
      cityId = _locationIdFromMap(
        cityMatch != null ? Map<String, dynamic>.from(cityMatch) : null,
      );
    }

    return (regionId: regionId, cityId: cityId);
  }

  /// Applies delivery fee via POST [/calculate-delivery-fee].
  /// Call after save-billing (and after add-xpress-fee when urgent).
  /// [forceRefresh] bypasses the fee cache so the server session is updated
  /// immediately before ExpressPay (cached quotes do not re-apply).
  static Future<Map<String, dynamic>?> applyDeliveryFeeToCart({
    required String distanceText,
    bool fallbackToLocalEstimate = true,
    bool forceRefresh = false,
    double? knownDeliveryFee,
  }) async {
    final trimmed = distanceText.trim();
    if (trimmed.isEmpty) return null;

    final result = await fetchDeliveryFeeFromApi(
      distanceText: trimmed,
      fallbackToLocalEstimate: fallbackToLocalEstimate,
      forceRefresh: forceRefresh,
      knownDeliveryFee: knownDeliveryFee,
    );
    debugPrint(
      '[DELIVERY] calculate-delivery-fee applied: fee=${result?['delivery_fee']}'
      '${forceRefresh ? ' (force refresh)' : ''}',
    );
    return result;
  }

  /// Resolves distance_text for [/calculate-delivery-fee].
  /// Prefers save-billing [feeDistanceText] (e.g. "0.4 km") over km-derived labels.
  static Future<String?> resolveDistanceTextForDeliveryFee({
    String? feeDistanceText,
    double? knownDistanceKm,
    double? lat,
    double? lng,
  }) async {
    final authoritative = feeDistanceText?.trim();
    if (authoritative != null && authoritative.isNotEmpty) {
      return authoritative;
    }
    if (knownDistanceKm != null && knownDistanceKm >= 1) {
      return formatDistanceText(knownDistanceKm);
    }
    if (lat != null && lng != null) {
      return provisionalDistanceTextForCoordinates(lat: lat, lng: lng);
    }
    if (knownDistanceKm != null && knownDistanceKm > 0) {
      return formatDistanceText(knownDistanceKm);
    }
    return null;
  }

  /// Drops leftover xpress/urgent fee from a prior checkout on the server cart.
  static Future<void> clearStaleUrgentFeeOnServer({
    required String name,
    required String email,
    required String phone,
    required String deliveryOption,
    String? region,
    String? city,
    String? address,
    int? regionId,
    int? cityId,
    double? lat,
    double? lng,
    double? deliveryFee,
    String? distanceText,
  }) async {
    debugPrint(
      '[DELIVERY] Clearing stale xpress/urgent fee from server cart '
      '(non-urgent checkout)',
    );
    await saveDeliveryInfo(
      name: name,
      email: email,
      phone: phone,
      deliveryOption: deliveryOption,
      region: region,
      city: city,
      address: address,
      regionId: regionId,
      cityId: cityId,
      lat: lat,
      lng: lng,
      deliveryFee: deliveryFee,
      distanceText: distanceText,
      orderUrgent: false,
      clearStaleUrgentFee: true,
    );
  }

  /// Call /calculate-delivery-fee API with distance_text (e.g. "1.9 km").
  /// Returns { distance, delivery_fee, from_api } or null. Caches API results only.
  static Future<Map<String, dynamic>?> fetchDeliveryFeeFromApi({
    required String distanceText,
    bool fallbackToLocalEstimate = false,
    bool forceRefresh = false,
    double? knownDeliveryFee,
  }) async {
    try {
      final key = distanceText.trim();
      if (key.isEmpty) {
        debugPrint('calculate-delivery-fee: distance_text is empty');
        return null;
      }

      final normalizedKey = normalizeDistanceTextForFeeApi(key);

      if (!forceRefresh) {
        final cached =
            _deliveryFeeApiCache[normalizedKey] ?? _deliveryFeeApiCache[key];
        if (cached != null && cached['from_api'] == true) {
          return Map<String, dynamic>.from(cached);
        }
      }

      final headers = await deliveryAuthHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        debugPrint('calculate-delivery-fee: Auth required');
        return fallbackToLocalEstimate ? _localEstimateResult(key) : null;
      }

      final payload = <String, dynamic>{'distance_text': normalizedKey};
      if (knownDeliveryFee != null && knownDeliveryFee > 0) {
        payload['delivery_fee'] = knownDeliveryFee;
      }
      final jsonBody = json.encode(payload);

      var result = await _repository.calculateDeliveryFee(
        headers: headers,
        body: jsonBody,
        formEncoded: false,
        timeout: _apiTimeout,
      );

      if (result.statusCode != 200 && result.statusCode != 201) {
        var formBody = 'distance_text=${Uri.encodeComponent(normalizedKey)}';
        if (knownDeliveryFee != null && knownDeliveryFee > 0) {
          formBody +=
              '&delivery_fee=${Uri.encodeComponent(knownDeliveryFee.toString())}';
        }
        result = await _repository.calculateDeliveryFee(
          headers: headers,
          body: formBody,
          formEncoded: true,
          timeout: _apiTimeout,
        );
      }

      if (result.statusCode != 200 && result.statusCode != 201) {
        checkoutLog('❌ [CALCULATE-DELIVERY-FEE] Non-success status');
        return fallbackToLocalEstimate ? _localEstimateResult(key) : null;
      }

      final decoded = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
      if (decoded == null) {
        debugPrint('❌ [CALCULATE-DELIVERY-FEE] Unexpected response shape');
        return fallbackToLocalEstimate ? _localEstimateResult(key) : null;
      }

      final parsed = parseCalculateDeliveryFeePayload(decoded);
      if (parsed == null) {
        debugPrint('❌ [CALCULATE-DELIVERY-FEE] No delivery_fee in response');
        return fallbackToLocalEstimate ? _localEstimateResult(key) : null;
      }

      _deliveryFeeApiCache[normalizedKey] = parsed;
      if (normalizedKey != key) {
        _deliveryFeeApiCache[key] = parsed;
      }
      return parsed;
    } on TimeoutException catch (e) {
      debugPrint('❌ [CALCULATE-DELIVERY-FEE] Timeout: $e');
      return fallbackToLocalEstimate
          ? _localEstimateResult(distanceText.trim())
          : null;
    } on SocketException catch (e) {
      debugPrint('❌ [CALCULATE-DELIVERY-FEE] Network: $e');
      return fallbackToLocalEstimate
          ? _localEstimateResult(distanceText.trim())
          : null;
    } catch (e) {
      debugPrint('❌ [CALCULATE-DELIVERY-FEE] Error: $e');
      return fallbackToLocalEstimate
          ? _localEstimateResult(distanceText.trim())
          : null;
    }
  }

  static Map<String, dynamic>? _localEstimateResult(String key) {
    final local = localDeliveryFeeResult(key);
    if (local == null) return null;
    return {...local, 'from_api': false};
  }

  /// Calculate delivery fee based on region and city
  static double calculateDeliveryFee(String region, String city) {
    if (region.toLowerCase().contains('accra') ||
        city.toLowerCase().contains('accra')) {
      return 00.00;
    } else if (region.toLowerCase().contains('kumasi') ||
        city.toLowerCase().contains('kumasi')) {
      return 00.00;
    } else {
      return 00.00;
    }
  }

  /// Parse Google-style distance_text (e.g. "4.2 km", "500 m") to distance in km.
  /// Returns null if parsing fails.
  static double? parseDistanceTextToKm(String? distanceText) {
    if (distanceText == null || distanceText.trim().isEmpty) return null;
    final trimmed = distanceText.trim().toLowerCase();
    // Match number: digits, optional decimal (. or ,), optional more digits
    final match = RegExp(r'([\d\s]+[.,]?\d*)').firstMatch(trimmed);
    if (match == null) return null;
    final numStr = match.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
    final value = double.tryParse(numStr);
    if (value == null) return null;
    if (trimmed.contains('km')) return value;
    if (trimmed.contains('m') && !trimmed.contains('km')) return value / 1000.0;
    return value;
  }

  /// Sends sub-km labels in km so the server does not treat "5 m" as 5 km.
  static String normalizeDistanceTextForFeeApi(String distanceText) {
    final trimmed = distanceText.trim();
    final km = parseDistanceTextToKm(trimmed);
    if (km == null) return trimmed;
    if (km < 1) {
      final decimals = km < 0.01 ? 3 : (km < 0.1 ? 2 : 1);
      return '${km.toStringAsFixed(decimals)} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Rejects calculate-delivery-fee payloads when distance drifts from the label.
  static bool isCalculateDeliveryFeeResponseTrusted({
    required String distanceText,
    required Map<String, dynamic> apiResult,
  }) {
    final expectedKm = parseDistanceTextToKm(distanceText.trim());
    final apiDistanceRaw = apiResult['distance'];
    if (expectedKm == null || apiDistanceRaw == null) return true;

    final apiKm = apiDistanceRaw is num
        ? apiDistanceRaw.toDouble()
        : double.tryParse(apiDistanceRaw.toString());
    if (apiKm == null) return true;

    final delta = (apiKm - expectedKm).abs();
    if (delta <= 0.2) return true;

    // Server mis-parsed meter labels as km (e.g. "5 m" → distance 5).
    if (expectedKm < 0.5 && apiKm >= 1.0 && apiKm / expectedKm > 20) {
      return false;
    }

    final maxKm = expectedKm > apiKm ? expectedKm : apiKm;
    return maxKm <= 0 || delta / maxKm < 0.35;
  }

  /// Calculate delivery fee from distance_text (e.g. "4.2 km", "500 m").
  /// Returns map with 'fee' and 'distanceKm', or null if parsing fails.
  static Map<String, double>? calculateDeliveryFeeFromDistanceText(
    String? distanceText, {
    double? ratePerKm,
  }) {
    final distanceKm = parseDistanceTextToKm(distanceText);
    if (distanceKm == null) return null;
    final fee =
        calculateDeliveryFeeByDistance(distanceKm, ratePerKm: ratePerKm);
    return {'fee': fee, 'distanceKm': distanceKm};
  }

  /// Calculate delivery fee based purely on distance in km.
  ///
  /// Formula:
  ///   Delivery Fee = 20 + max(0, Distance − 3) × X
  ///
  /// Where:
  ///   - 20 is [baseDeliveryFee]
  ///   - 3 is [baseDeliveryDistanceKm]
  ///   - X is [defaultRatePerKm] (or an override passed in)
  static double calculateDeliveryFeeByDistance(
    double distanceKm, {
    double? ratePerKm,
  }) {
    final double rate = ratePerKm ?? defaultRatePerKm;
    final double extraDistance =
        (distanceKm - baseDeliveryDistanceKm).clamp(0.0, double.infinity);
    final double fee = baseDeliveryFee + extraDistance * rate;

    checkoutLog(
      '📦 Delivery fee by distance → '
      'distance: ${distanceKm.toStringAsFixed(2)} km, fee: ${fee.toStringAsFixed(2)}',
    );

    return fee;
  }

  /// Fetch all regions from API
  static Future<Map<String, dynamic>> getRegions() async {
    try {
      final result = await _repository.fetchRegions();

      if (result.statusCode == 0) {
        final err = result.error;
        if (err is TimeoutException) {
          return {
            'success': false,
            'message': 'Request timed out. Please try again.',
          };
        }
        if (err is SocketException) {
          return {
            'success': false,
            'message':
                'Unable to connect. Please check your internet connection.',
          };
        }
        return {
          'success': false,
          'message':
              'Network error. Please check your connection and try again.',
        };
      }

      if (result.statusCode == 200) {
        final data = _decodedPayload(result);
        final normalized = normalizeDeliveryDescriptionField(
          extractDeliveryListPayload(data),
        );

        return {
          'success': true,
          'data': normalized,
          'message': 'Regions fetched successfully',
        };
      } else {
        final errorData = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');

        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to fetch regions',
        };
      }
    } catch (e) {
      debugPrint('🔍 DeliveryService: Error getting regions: $e');
      return {
        'success': false,
        'message': 'Unable to load regions. Please try again later.',
      };
    }
  }

  /// Fetch cities for a specific region from API
  static Future<Map<String, dynamic>> getCitiesByRegion(int regionId) async {
    try {
      debugPrint('Fetching cities for region $regionId from API...');
      debugPrint(
          'API URL: ${ApiConfig.getRegionCitiesUrl(regionId.toString())}');

      final result = await _repository.fetchCitiesByRegion(regionId);

      debugPrint('Get cities response status: ${result.statusCode}');
      debugPrint('Get cities response body: ${result.rawBody}');

      if (result.statusCode == 200) {
        final data = _decodedPayload(result);
        final normalized = normalizeDeliveryDescriptionField(
          extractDeliveryListPayload(data),
        );
        debugPrint('=== API GET CITIES SUCCESS ===');
        debugPrint('Cities data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': normalized,
          'message': 'Cities fetched successfully',
        };
      } else {
        final errorData = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
        debugPrint('=== API GET CITIES ERROR ===');
        debugPrint('Error status code: ${result.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('============================');
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to fetch cities',
        };
      }
    } catch (e) {
      debugPrint('Error getting cities: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch stores for a specific city from API
  static Future<Map<String, dynamic>> getStoresByCity(int cityId) async {
    try {
      debugPrint('Fetching stores for city $cityId from API...');
      debugPrint('API URL: ${ApiConfig.getCityStoresUrl(cityId.toString())}');

      final result = await _repository.fetchStoresByCity(cityId);

      debugPrint('Get stores response status: ${result.statusCode}');
      debugPrint('Get stores response body: ${result.rawBody}');

      if (result.statusCode == 200) {
        final data = _decodedPayload(result);
        final normalized = normalizeDeliveryStoreRecords(
          extractDeliveryListPayload(data),
        );
        debugPrint('=== API GET STORES SUCCESS ===');
        debugPrint('Stores data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': normalized,
          'message': 'Stores fetched successfully',
        };
      } else {
        final errorData = AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
        debugPrint('=== API GET STORES ERROR ===');
        debugPrint('Error status code: ${result.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('============================');
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to fetch stores',
        };
      }
    } catch (e) {
      debugPrint('Error getting stores: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch all stores from all cities in parallel for better performance
  static Future<Map<String, dynamic>> getAllStores() async {
    try {
      debugPrint('=== DELIVERY SERVICE: Fetching all stores in parallel ===');

      // First get all regions
      final regionsResult = await getRegions();
      if (!regionsResult['success']) {
        return regionsResult;
      }

      final regionsData = regionsResult['data'] ?? [];
      List<Future<Map<String, dynamic>>> cityFutures = [];
      Map<int, String> regionNames = {};

      // Create a map of region IDs to region names
      for (var region in regionsData) {
        final regionId = int.tryParse(region['id'].toString()) ?? 0;
        final regionName = region['description']?.toString() ?? '';
        regionNames[regionId] = regionName;
      }

      // Get all cities for all regions in parallel
      for (var region in regionsData) {
        final regionId = int.tryParse(region['id'].toString()) ?? 0;
        cityFutures.add(getCitiesByRegion(regionId));
      }

      // Wait for all city requests to complete
      final cityResults = await Future.wait(cityFutures);

      List<Future<Map<String, dynamic>>> storeFutures = [];
      Map<int, Map<String, String>> cityInfo = {};

      // Process city results and create store futures
      for (int i = 0; i < cityResults.length; i++) {
        if (cityResults[i]['success']) {
          final citiesData = cityResults[i]['data'] ?? [];
          final regionId = int.tryParse(regionsData[i]['id'].toString()) ?? 0;
          final regionName = regionNames[regionId] ?? '';

          for (var city in citiesData) {
            final cityId = int.tryParse(city['id'].toString()) ?? 0;
            cityInfo[cityId] = {
              'region_name': regionName,
              'city_name': city['description']?.toString() ?? '',
            };
            storeFutures.add(getStoresByCity(cityId));
          }
        }
      }

      // Wait for all store requests to complete
      final storeResults = await Future.wait(storeFutures);

      List<dynamic> allStores = [];
      // int storeIndex = 0;

      // Process store results and add region/city info
      for (var storeResult in storeResults) {
        if (storeResult['success']) {
          final storesData = storeResult['data'] ?? [];
          for (var store in storesData) {
            final cityId =
                int.tryParse(store['city_id']?.toString() ?? '') ?? 0;
            if (cityInfo.containsKey(cityId)) {
              store['region_name'] = cityInfo[cityId]!['region_name'];
              store['city_name'] = cityInfo[cityId]!['city_name'];
            }
            allStores.add(store);
          }
        }
        // storeIndex++;
      }

      return {
        'success': true,
        'data': allStores,
        'message': 'All stores fetched successfully',
      };
    } catch (e) {
      debugPrint('Error getting all stores: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }
}
