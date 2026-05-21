import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/store_location_model.dart';
import 'package:eclapp/services/auth_service.dart';

class DeliveryService {
  static const String baseUrl = ApiConfig.baseUrl;

  /// Timeout for delivery API calls. Shorter = fail fast and use local fallback.
  static const Duration _apiTimeout = Duration(seconds: 5);

  // Delivery pricing constants
  // Base fee = 20
  // Base distance = 3 km
  // Extra distance rate (X) per km
  static const double baseDeliveryFee = 20.0;
  static const double baseDeliveryDistanceKm = 3.0;
  static const double defaultRatePerKm = 3.0; // X: change this if needed

  /// Extract list payload from common API response shapes.
  static List<dynamic> _extractListPayload(dynamic decodedBody) {
    if (decodedBody is List) return decodedBody;
    if (decodedBody is! Map<String, dynamic>) return [];

    final data = decodedBody['data'];
    if (data is List) return data;

    // Handle nested wrappers: { data: { data: [...] } }
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is List) return nested;
    }

    // Fallback keys used by some backends.
    for (final key in const ['regions', 'cities', 'stores', 'results', 'items']) {
      final value = decodedBody[key];
      if (value is List) return value;
    }

    return [];
  }

  /// Normalizes store API rows (`id`, `city_id`, `description`, `lat`, `lng`, …).
  static List<Map<String, dynamic>> _normalizeStoreRecords(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((raw) => normalizeStoreMap(Map<String, dynamic>.from(raw)))
        .toList();
  }

  /// Single store map with parsed coords, address, and formatted hours.
  static Map<String, dynamic> normalizeStoreMap(Map<String, dynamic> raw) {
    return StoreLocationModel.fromApiJson(raw).toMap();
  }

  /// Ensure UI-facing records always have a `description` field.
  static List<Map<String, dynamic>> _normalizeDescriptionField(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map((item) {
          final label = (item['description'] ??
                  item['name'] ??
                  item['title'] ??
                  item['label'] ??
                  '')
              .toString();
          if (item['description'] == null && label.isNotEmpty) {
            item['description'] = label;
          }
          return item;
        })
        .toList();
  }

  /// Call /add-xpress-fee API to add express/urgent delivery fee
  static Future<Map<String, dynamic>?> addXpressFee() async {
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
      final url = ApiConfig.getEndpointUrl('/add-xpress-fee');
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) ...{
          'Authorization': 'Guest $guestId',
          'X-Guest-ID': guestId,
        },
      };
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 5));
      debugPrint('[add-xpress-fee] Response status: \\${response.statusCode}');
      debugPrint('[add-xpress-fee] Response body: \\${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('add-xpress-fee error: \\${e.toString()}');
      return null;
    }
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
    double? lat,
    double? lng,
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

      // different fields depending on if its delivery or pickup
      if (deliveryOption == 'delivery') {
        // if they want it delivered, we need their address
        requestBody['addr_1'] = address ?? 'Not specified';
        requestBody['region'] = region ?? 'Not specified';
        requestBody['city'] = city ?? 'Not specified';

        // add the map coordinates if we have them
        if (lat != null && lng != null) {
          requestBody['lat'] = lat;
          requestBody['lng'] = lng;
          // Backward-compatible aliases used by some backend handlers
          requestBody['latitude'] = lat;
          requestBody['longitude'] = lng;
        }
      } else if (deliveryOption == 'pickup') {
        // if theyre picking it up, we need the store info
        requestBody['addr_1'] = 'Pickup order';
        requestBody['region'] = pickupRegion ?? 'Not specified';
        requestBody['city'] = pickupCity ?? 'Not specified';
        // which store they want to pick up from
        requestBody['pickup_location'] = pickupSite ?? '';
      }

      debugPrint('Saving delivery info to API...');
      debugPrint('Request body: ${json.encode(requestBody)}');
      debugPrint('Delivery option: $deliveryOption');
      debugPrint('Is delivery: ${deliveryOption == 'delivery'}');
      debugPrint('Is pickup: ${deliveryOption == 'pickup'}');

      // set the headers depending on if theyre logged in or not
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) ...{
          'Authorization': 'Guest $guestId',
          'X-Guest-ID': guestId,
        },
      };

      final saveAddressUrl =
          ApiConfig.getEndpointUrl(ApiConfig.saveBillingAddress);
      final response = await http
          .post(
            Uri.parse(saveAddressUrl),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(_apiTimeout);

      debugPrint('===== SAVE ADDRESS API RESPONSE =====');
      debugPrint('URL: $saveAddressUrl');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('HEADERS: ${response.headers}');
      debugPrint('RAW BODY: ${response.body}');
      debugPrint('====================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('=== API SAVE SUCCESS ===');
        debugPrint('Parsed response data: ${json.encode(data)}');
        debugPrint('Response message: ${data['message']}');
        debugPrint('Response status: ${data['status']}');

        // get the store info from the response
        final closestStore = data['closest_store'];
        final selectedStoreDescription = data['selected_store_description'];

        // Also check nested data.data (some APIs wrap response)
        final resolvedStore = closestStore ?? data['data']?['closest_store'];
        if (resolvedStore != null) {
          debugPrint('Closest store found:');
          debugPrint('  - ID: ${resolvedStore['id']}');
          debugPrint('  - Lat: ${resolvedStore['lat']}');
          debugPrint('  - Lng: ${resolvedStore['lng']}');
          debugPrint('  - distance_text: ${resolvedStore['distance_text']}');
          debugPrint('  - Duration: ${resolvedStore['duration_text']}');
        }

        if (selectedStoreDescription != null) {
          debugPrint('Selected store: $selectedStoreDescription');
        }

        debugPrint('========================');

        return {
          'success': true,
          'message':
              data['message'] ?? 'Delivery information saved successfully',
          'status': data['status'] ?? 'success',
          'closest_store': resolvedStore,
          'selected_store_description': selectedStoreDescription,
          'data': data, // keep the original data just in case we need it later
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('=== API SAVE ERROR ===');
        debugPrint('Error status code: ${response.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('Error message: ${errorData['message']}');
        debugPrint('=====================');
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to save delivery information',
        };
      }
    } catch (e) {
      debugPrint('Error saving delivery info: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
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

      debugPrint('Fetching last delivery info from API...');
      debugPrint(
          'API URL: ${ApiConfig.getEndpointUrl(ApiConfig.getBillingAddress)}');

      // call the api to get their saved address
      final response = await http
          .get(
            Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getBillingAddress)),
            headers: headers,
          )
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('\n${'=' * 50}');
        debugPrint('✅ API GET SUCCESS');
        debugPrint('=' * 50);
        debugPrint('Raw response data: ${json.encode(data)}');
        debugPrint('Response message: ${data['message']}');
        debugPrint('Response data: ${data['data']}');
        debugPrint('=' * 50);

        // Pretty print the API response

        if (data['data'] != null && data['data']['billingAddr'] != null) {
          // keep for structured logging / future use
        } else {
          debugPrint('  └── billingAddr: null');
        }

        // Check if data exists and has content
        if (data['data'] == null) {
          debugPrint('\n❌ NO DATA IN RESPONSE');
          return {
            'success': true,
            'data': null,
            'message': 'No delivery data found in response',
          };
        }

        // Get the billingAddr object from the response
        final billingAddr = data['data']['billingAddr'];
        if (billingAddr == null) {
          debugPrint('\n❌ NO BILLING ADDR IN RESPONSE');
          return {
            'success': true,
            'data': null,
            'message': 'No billing address found in response',
          };
        }

        // Debug specific fields

        // Map the API response fields to our expected format
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
          'notes': billingAddr['notes'] ?? '',
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
        };

        return {
          'success': true,
          'data': deliveryData,
          'message':
              data['message'] ?? 'Delivery information retrieved successfully',
        };
      } else if (response.statusCode == 404) {
        // No previous delivery info found
        debugPrint('=== API GET - NO DATA FOUND ===');
        debugPrint('Status: 404 - No previous delivery information found');
        debugPrint('================================');
        return {
          'success': true,
          'data': null,
          'message': 'No previous delivery information found',
        };
      } else if (response.statusCode == 401) {
        // Unauthorized (expired token or invalid guest_id) - treat as no saved address
        debugPrint(
            '=== API GET - UNAUTHORIZED (treating as no saved address) ===');
        return {
          'success': true,
          'data': null,
          'message': 'No previous delivery information found',
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('=== API GET ERROR ===');
        debugPrint('Error status code: ${response.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('Error message: ${errorData['message']}');
        debugPrint('====================');
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to retrieve delivery information',
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

  /// Call /calculate-delivery-fee API with distance_text (e.g. "1.9 km").
  /// Returns { distance: num, delivery_fee: double } or null on failure.
  /// Results are cached by distance_text to avoid repeated slow API calls.
  static Future<Map<String, dynamic>?> fetchDeliveryFeeFromApi({
    required String distanceText,
  }) async {
    try {
      final key = distanceText.trim();
      if (key.isEmpty) {
        debugPrint('calculate-delivery-fee: distance_text is empty');
        return null;
      }
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
        debugPrint('calculate-delivery-fee: Guest auth required');
        return null;
      }
      if (isLoggedIn && (token == null || token.isEmpty)) {
        debugPrint('calculate-delivery-fee: Auth required');
        return null;
      }

      final url = ApiConfig.getEndpointUrl(ApiConfig.calculateDeliveryFee);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) ...{
          'Authorization': 'Guest $guestId',
          'X-Guest-ID': guestId,
        },
      };
      // API expects "distance_text" - try JSON body first
      final jsonBody = json.encode({'distance_text': distanceText.trim()});
      final formBody =
          'distance_text=${Uri.encodeComponent(distanceText.trim())}';

      print('📤 [CALCULATE-DELIVERY-FEE] Calling API: $url');
      print('📤 [CALCULATE-DELIVERY-FEE] distance_text: "$distanceText"');

      var response = await http
          .post(Uri.parse(url), headers: headers, body: jsonBody)
          .timeout(_apiTimeout);

      // If JSON fails (401, 422, etc), try form-urlencoded
      if (response.statusCode != 200 && response.statusCode != 201) {
        final formHeaders = <String, String>{
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        };
        response = await http
            .post(Uri.parse(url), headers: formHeaders, body: formBody)
            .timeout(_apiTimeout);
      }

      print(
          '📥 [CALCULATE-DELIVERY-FEE] Response status: ${response.statusCode}');
      print('📥 [CALCULATE-DELIVERY-FEE] Response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('❌ [CALCULATE-DELIVERY-FEE] Non-success status, using fallback');
        return null;
      }
      final data = json.decode(response.body) as Map<String, dynamic>?;
      if (data == null) {
        print(
            '❌ [CALCULATE-DELIVERY-FEE] Response body could not be parsed, using fallback');
        return null;
      }

      final distance = data['distance'];
      final deliveryFeeRaw =
          data['delivery_fee'] ?? data['deliveryFee'] ?? data['fee'];
      if (deliveryFeeRaw == null) {
        print(
            '❌ [CALCULATE-DELIVERY-FEE] No delivery_fee in response, using fallback');
        return null;
      }

      final feeValue = deliveryFeeRaw is num
          ? deliveryFeeRaw.toDouble()
          : (double.tryParse(deliveryFeeRaw.toString()) ?? 0.0);
      final distanceKm = distance is num
          ? distance.toDouble()
          : (distance != null ? double.tryParse(distance.toString()) : null);

      final result = <String, dynamic>{
        'distance': distanceKm,
        'delivery_fee': feeValue,
      };
      return result;
    } catch (e) {
      print('❌ [CALCULATE-DELIVERY-FEE] Error: $e');
      return null;
    }
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

    debugPrint(
      '📦 Delivery fee by distance → '
      'distance: ${distanceKm.toStringAsFixed(2)} km, '
      'extra: ${extraDistance.toStringAsFixed(2)} km, '
      'rate: $rate, '
      'fee: ${fee.toStringAsFixed(2)}',
    );

    return fee;
  }

  /// Fetch all regions from API
  static Future<Map<String, dynamic>> getRegions() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.regions)),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final normalized =
            _normalizeDescriptionField(_extractListPayload(data));

        return {
          'success': true,
          'data': normalized,
          'message': 'Regions fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);

        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch regions',
        };
      }
    } on TimeoutException catch (e) {
      // Timeout error - catch this first
      debugPrint('🔍 DeliveryService: Timeout getting regions: $e');
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    } on SocketException catch (e) {
      // DNS/Network error - handle gracefully
      debugPrint(
          '🔍 DeliveryService: Network error getting regions (DNS/hostname issue): ${e.message}');
      return {
        'success': false,
        'message': 'Unable to connect. Please check your internet connection.',
      };
    } on http.ClientException catch (e) {
      // Client/network error (this often wraps SocketException)
      debugPrint('🔍 DeliveryService: Client error getting regions: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    } catch (e) {
      // Other errors
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

      final response = await http.get(
        Uri.parse(ApiConfig.getRegionCitiesUrl(regionId.toString())),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      debugPrint('Get cities response status: ${response.statusCode}');
      debugPrint('Get cities response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final normalized =
            _normalizeDescriptionField(_extractListPayload(data));
        debugPrint('=== API GET CITIES SUCCESS ===');
        debugPrint('Cities data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': normalized,
          'message': 'Cities fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('=== API GET CITIES ERROR ===');
        debugPrint('Error status code: ${response.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('============================');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch cities',
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

      final response = await http.get(
        Uri.parse(ApiConfig.getCityStoresUrl(cityId.toString())),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      debugPrint('Get stores response status: ${response.statusCode}');
      debugPrint('Get stores response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final normalized = _normalizeStoreRecords(_extractListPayload(data));
        debugPrint('=== API GET STORES SUCCESS ===');
        debugPrint('Stores data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': normalized,
          'message': 'Stores fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('=== API GET STORES ERROR ===');
        debugPrint('Error status code: ${response.statusCode}');
        debugPrint('Error response: ${json.encode(errorData)}');
        debugPrint('============================');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch stores',
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
