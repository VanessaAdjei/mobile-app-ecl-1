// services/delivery_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../pages/auth_service.dart';

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
      final token = await AuthService.getToken();
      if (token == null) {
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
        'addr_1': address ?? '', // Address
        'region': region ?? '', // Region
        'city': city ?? '', // City
      };

      // Add delivery option and notes if available
      if (deliveryOption.isNotEmpty) {
        requestBody['delivery_option'] = deliveryOption;
      }
      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      // Add pickup information if it's a pickup order
      if (deliveryOption == 'Pickup') {
        requestBody['pickup_region'] = pickupRegion ?? '';
        requestBody['pickup_city'] = pickupCity ?? '';
        requestBody['pickup_site'] = pickupSite ?? '';
      }

      print('Saving delivery info to API...');
      print('Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/save-billing-add'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

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
      ).timeout(const Duration(seconds: 30));

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
          'delivery_option': billingAddr['delivery_option'] ?? 'Delivery',
          'region': billingAddr['region'] ?? '',
          'city': billingAddr['city'] ?? '',
          'address': billingAddr['addr_1'] ?? '',
          'notes': billingAddr['notes'] ?? '',
          'pickup_region': billingAddr['pickup_region'] ?? '',
          'pickup_city': billingAddr['pickup_city'] ?? '',
          'pickup_site': billingAddr['pickup_site'] ?? '',
        };

        print('\n📝 MAPPED FIELD DEBUG:');
        print('deliveryData["region"]: "${deliveryData['region']}"');
        print('deliveryData["city"]: "${deliveryData['city']}"');
        print('deliveryData["address"]: "${deliveryData['address']}"');
        print('deliveryData["name"]: "${deliveryData['name']}"');
        print('deliveryData["email"]: "${deliveryData['email']}"');
        print('deliveryData["phone"]: "${deliveryData['phone']}"');

        print('Mapped delivery data: ${json.encode(deliveryData)}');
        print('Field values:');
        print('- name: "${deliveryData['name']}"');
        print('- email: "${deliveryData['email']}"');
        print('- phone: "${deliveryData['phone']}"');
        print('- region: "${deliveryData['region']}"');
        print('- city: "${deliveryData['city']}"');
        print('- address: "${deliveryData['address']}"');
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
      return 10.00;
    } else if (region.toLowerCase().contains('kumasi') ||
        city.toLowerCase().contains('kumasi')) {
      return 15.00;
    } else {
      return 20.00;
    }
  }
}
