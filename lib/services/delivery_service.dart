// services/delivery_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  static const String baseUrl = ApiConfig.baseUrl;

  /// Save delivery information to the server
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
  }) async {
    try {
      // Determine if user is logged in or guest
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

      // Use the existing save-order API endpoint with correct field mappings
      final requestBody = {
        'fname': name, // Full name
        'email': email, // User email
        'phone': phone, // Phone number
        'shipping_type': deliveryOption, // Delivery method (delivery or pickup)
      };

      // Add delivery option and notes if available
      if (deliveryOption.isNotEmpty) {
        requestBody['delivery_option'] = deliveryOption;
      }
      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      // Handle delivery-specific fields
      if (deliveryOption == 'delivery') {
        // For delivery orders, include address fields
        requestBody['addr_1'] = address ?? 'Not specified';
        requestBody['region'] = region ?? 'Not specified';
        requestBody['city'] = city ?? 'Not specified';
      } else if (deliveryOption == 'pickup') {
        // For pickup orders, include pickup fields and minimal address info
        requestBody['addr_1'] = 'Pickup order';
        requestBody['region'] = pickupRegion ?? 'Not specified';
        requestBody['city'] = pickupCity ?? 'Not specified';
        // Add pickup_location field with the selected pickup site
        requestBody['pickup_location'] = pickupSite ?? '';
      }

      debugPrint('Saving delivery info to API...');
      debugPrint('Request body: ${json.encode(requestBody)}');
      debugPrint('Delivery option: $deliveryOption');
      debugPrint('Is delivery: ${deliveryOption == 'delivery'}');
      debugPrint('Is pickup: ${deliveryOption == 'pickup'}');

      // Set headers based on user type
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (isLoggedIn) 'Authorization': 'Bearer $token',
        if (!isLoggedIn && guestId != null) 'Authorization': 'Guest $guestId',
      };

      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/save-billing-add'),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Save delivery info response status: ${response.statusCode}');
      debugPrint('Save delivery info response headers: ${response.headers}');
      debugPrint('Save delivery info response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('=== API SAVE SUCCESS ===');
        debugPrint('Parsed response data: ${json.encode(data)}');
        debugPrint('Response message: ${data['message']}');
        debugPrint('Response data: ${data['data']}');
        debugPrint('========================');
        return {
          'success': true,
          'message':
              data['message'] ?? 'Delivery information saved successfully',
          'data': data['data'],
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

  /// Retrieve the last saved delivery information from the server
  static Future<Map<String, dynamic>> getLastDeliveryInfo() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
        };
      }

      debugPrint('Fetching last delivery info from API...');
      debugPrint(
          'API URL: https://eclcommerce.ernestchemists.com.gh/api/get-billing-add');

      // Use the correct endpoint for getting billing/delivery data
      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/get-billing-add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

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
          final billingAddr = data['data']['billingAddr'];
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

  /// Fetch all regions from API
  static Future<Map<String, dynamic>> getRegions() async {
    try {
      final response = await http.get(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/regions'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return {
          'success': true,
          'data': data['data'],
          'message': 'Regions fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);

        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch regions',
        };
      }
    } catch (e) {
      debugPrint('Error getting regions: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch cities for a specific region from API
  static Future<Map<String, dynamic>> getCitiesByRegion(int regionId) async {
    try {
      debugPrint('Fetching cities for region $regionId from API...');
      debugPrint(
          'API URL: https://eclcommerce.ernestchemists.com.gh/api/regions/$regionId/cities');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/regions/$regionId/cities'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      debugPrint('Get cities response status: ${response.statusCode}');
      debugPrint('Get cities response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('=== API GET CITIES SUCCESS ===');
        debugPrint('Cities data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': data['data'],
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
      debugPrint(
          'API URL: https://eclcommerce.ernestchemists.com.gh/api/cities/$cityId/stores');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/cities/$cityId/stores'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      debugPrint('Get stores response status: ${response.statusCode}');
      debugPrint('Get stores response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('=== API GET STORES SUCCESS ===');
        debugPrint('Stores data: ${json.encode(data)}');
        debugPrint('==============================');

        return {
          'success': true,
          'data': data['data'],
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
            // Find the corresponding city info
            final cityId = store['city_id'];
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
