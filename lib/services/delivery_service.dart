// services/delivery_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      print('Saving delivery info to API...');
      print('Request body: ${json.encode(requestBody)}');
      print('Delivery option: $deliveryOption');
      print('Is delivery: ${deliveryOption == 'delivery'}');
      print('Is pickup: ${deliveryOption == 'pickup'}');

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

      print('Save delivery info response status: ${response.statusCode}');
      print('Save delivery info response headers: ${response.headers}');
      print('Save delivery info response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('=== API SAVE SUCCESS ===');
        print('Parsed response data: ${json.encode(data)}');
        print('Response message: ${data['message']}');
        print('Response data: ${data['data']}');
        print('========================');
        return {
          'success': true,
          'message':
              data['message'] ?? 'Delivery information saved successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        print('=== API SAVE ERROR ===');
        print('Error status code: ${response.statusCode}');
        print('Error response: ${json.encode(errorData)}');
        print('Error message: ${errorData['message']}');
        print('=====================');
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to save delivery information',
        };
      }
    } catch (e) {
      print('Error saving delivery info: $e');
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

      print('Fetching last delivery info from API...');
      print(
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

      print('\n' + '=' * 50);
      print('🔍 API RESPONSE DEBUG');
      print('=' * 50);
      print('Get delivery info response status: ${response.statusCode}');
      print('Get delivery info response headers: ${response.headers}');
      print('Get delivery info response body: ${response.body}');
      print('=' * 50);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('\n' + '=' * 50);
        print('✅ API GET SUCCESS');
        print('=' * 50);
        print('Raw response data: ${json.encode(data)}');
        print('Response message: ${data['message']}');
        print('Response data: ${data['data']}');
        print('=' * 50);

        // Pretty print the API response
        print('\n' + '=' * 50);
        print('📋 COMPLETE API RESPONSE STRUCTURE');
        print('=' * 50);
        print('Status: ${data['status']}');
        print('Data Structure:');
        if (data['data'] != null && data['data']['billingAddr'] != null) {
          final billingAddr = data['data']['billingAddr'];
          print('  └── billingAddr:');
          print('      ├── id: ${billingAddr['id']}');
          print('      ├── user_id: ${billingAddr['user_id']}');
          print('      ├── fname: "${billingAddr['fname']}"');
          print('      ├── lname: ${billingAddr['lname']}');
          print('      ├── email: "${billingAddr['email']}"');
          print('      ├── phone: "${billingAddr['phone']}"');
          print('      ├── addr_1: "${billingAddr['addr_1']}"');
          print('      ├── addr_2: ${billingAddr['addr_2']}');
          print('      ├── region: "${billingAddr['region']}"');
          print('      ├── city: ${billingAddr['city']}');
          print('      ├── shipping_type: "${billingAddr['shipping_type']}"');
          print(
              '      ├── pickup_location: "${billingAddr['pickup_location']}"');
          print(
              '      ├── delivery_option: "${billingAddr['delivery_option']}"');
          print('      ├── pickup_region: "${billingAddr['pickup_region']}"');
          print('      ├── pickup_city: "${billingAddr['pickup_city']}"');
          print('      ├── pickup_site: "${billingAddr['pickup_site']}"');
          print('      ├── notes: "${billingAddr['notes']}"');
          print('      ├── created_at: "${billingAddr['created_at']}"');
          print('      └── updated_at: "${billingAddr['updated_at']}"');
        } else {
          print('  └── billingAddr: null');
        }
        print('=' * 50);

        // Check if data exists and has content
        if (data['data'] == null) {
          print('\n❌ NO DATA IN RESPONSE');
          return {
            'success': true,
            'data': null,
            'message': 'No delivery data found in response',
          };
        }

        // Get the billingAddr object from the response
        final billingAddr = data['data']['billingAddr'];
        if (billingAddr == null) {
          print('\n❌ NO BILLING ADDR IN RESPONSE');
          return {
            'success': true,
            'data': null,
            'message': 'No billing address found in response',
          };
        }

        print('\n' + '=' * 50);
        print('🔄 FIELD MAPPING');
        print('=' * 50);
        print('Billing address data: ${json.encode(billingAddr)}');

        // Debug specific fields
        print('\n🔍 SPECIFIC FIELD DEBUG:');
        print('Raw billingAddr["region"]: ${billingAddr['region']}');
        print('Raw billingAddr["city"]: ${billingAddr['city']}');
        print('Raw billingAddr["addr_1"]: ${billingAddr['addr_1']}');
        print('Raw billingAddr["fname"]: ${billingAddr['fname']}');
        print('Raw billingAddr["email"]: ${billingAddr['email']}');
        print('Raw billingAddr["phone"]: ${billingAddr['phone']}');

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

        print('\n📝 MAPPED FIELD DEBUG:');
        print('deliveryData["region"]: "${deliveryData['region']}"');
        print('deliveryData["city"]: "${deliveryData['city']}"');
        print('deliveryData["address"]: "${deliveryData['address']}"');
        print('deliveryData["name"]: "${deliveryData['name']}"');
        print('deliveryData["email"]: "${deliveryData['email']}"');
        print('deliveryData["phone"]: "${deliveryData['phone']}"');
        print(
            'deliveryData["shipping_type"]: "${deliveryData['shipping_type']}"');
        print(
            'deliveryData["pickup_location"]: "${deliveryData['pickup_location']}"');
        print(
            'deliveryData["delivery_option"]: "${deliveryData['delivery_option']}"');

        print('Mapped delivery data: ${json.encode(deliveryData)}');
        print('Field values:');
        print('- name: "${deliveryData['name']}"');
        print('- email: "${deliveryData['email']}"');
        print('- phone: "${deliveryData['phone']}"');
        print('- region: "${deliveryData['region']}"');
        print('- city: "${deliveryData['city']}"');
        print('- address: "${deliveryData['address']}"');
        print('- shipping_type: "${deliveryData['shipping_type']}"');
        print('- pickup_location: "${deliveryData['pickup_location']}"');
        print('- delivery_option: "${deliveryData['delivery_option']}"');
        print('=' * 50);

        return {
          'success': true,
          'data': deliveryData,
          'message':
              data['message'] ?? 'Delivery information retrieved successfully',
        };
      } else if (response.statusCode == 404) {
        // No previous delivery info found
        print('=== API GET - NO DATA FOUND ===');
        print('Status: 404 - No previous delivery information found');
        print('================================');
        return {
          'success': true,
          'data': null,
          'message': 'No previous delivery information found',
        };
      } else {
        final errorData = json.decode(response.body);
        print('=== API GET ERROR ===');
        print('Error status code: ${response.statusCode}');
        print('Error response: ${json.encode(errorData)}');
        print('Error message: ${errorData['message']}');
        print('====================');
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to retrieve delivery information',
        };
      }
    } catch (e) {
      print('Error getting delivery info: $e');
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
      print('Error getting regions: $e');
      print('Error type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch cities for a specific region from API
  static Future<Map<String, dynamic>> getCitiesByRegion(int regionId) async {
    try {
      print('Fetching cities for region $regionId from API...');
      print(
          'API URL: https://eclcommerce.ernestchemists.com.gh/api/regions/$regionId/cities');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/regions/$regionId/cities'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      print('Get cities response status: ${response.statusCode}');
      print('Get cities response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('=== API GET CITIES SUCCESS ===');
        print('Cities data: ${json.encode(data)}');
        print('==============================');

        return {
          'success': true,
          'data': data['data'],
          'message': 'Cities fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        print('=== API GET CITIES ERROR ===');
        print('Error status code: ${response.statusCode}');
        print('Error response: ${json.encode(errorData)}');
        print('============================');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch cities',
        };
      }
    } catch (e) {
      print('Error getting cities: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch stores for a specific city from API
  static Future<Map<String, dynamic>> getStoresByCity(int cityId) async {
    try {
      print('Fetching stores for city $cityId from API...');
      print(
          'API URL: https://eclcommerce.ernestchemists.com.gh/api/cities/$cityId/stores');

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/cities/$cityId/stores'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      print('Get stores response status: ${response.statusCode}');
      print('Get stores response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('=== API GET STORES SUCCESS ===');
        print('Stores data: ${json.encode(data)}');
        print('==============================');

        return {
          'success': true,
          'data': data['data'],
          'message': 'Stores fetched successfully',
        };
      } else {
        final errorData = json.decode(response.body);
        print('=== API GET STORES ERROR ===');
        print('Error status code: ${response.statusCode}');
        print('Error response: ${json.encode(errorData)}');
        print('============================');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch stores',
        };
      }
    } catch (e) {
      print('Error getting stores: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }

  /// Fetch all stores from all cities in parallel for better performance
  static Future<Map<String, dynamic>> getAllStores() async {
    try {
      print('=== DELIVERY SERVICE: Fetching all stores in parallel ===');

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
      int storeIndex = 0;

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
        storeIndex++;
      }

      print('All stores loaded successfully: ${allStores.length} stores');
      return {
        'success': true,
        'data': allStores,
        'message': 'All stores fetched successfully',
      };
    } catch (e) {
      print('Error getting all stores: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }
}
