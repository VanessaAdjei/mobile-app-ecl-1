// services/refill_api_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/refill_medicine.dart';
import 'api_service.dart';
import 'auth_service.dart';

class RefillApiService {
  static const String baseUrl = 'https://eclcommerce.ernestchemists.com.gh/api';
  static const Duration requestTimeout = Duration(seconds: 30);

  // get medicines that can be refilled
  static Future<List<RefillMedicine>> getRefillableMedicines() async {
    try {
      debugPrint('[RefillAPI] Fetching refillable medicines...');

      // get the auth token
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Authentication Required',
            'Please log in to view refillable medicines.');
      }

      // Prepare headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'ECL-Pharmacy-App/1.0',
      };

      // call the api
      final response = await http
          .get(
            Uri.parse('$baseUrl/refill'),
            headers: headers,
          )
          .timeout(requestTimeout);

      debugPrint('[RefillAPI] Response status: ${response.statusCode}');
      debugPrint('[RefillAPI] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // the api might return data in different formats, handle all of them
        List<dynamic> medicinesData = [];

        if (data is List) {
          medicinesData = data;
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            medicinesData = data['data'];
          } else if (data.containsKey('medicines') &&
              data['medicines'] is List) {
            medicinesData = data['medicines'];
          } else if (data.containsKey('refillable_medicines') &&
              data['refillable_medicines'] is List) {
            medicinesData = data['refillable_medicines'];
          }
        }

        // turn the api data into RefillMedicine objects
        final medicines = medicinesData
            .map((medicineData) => RefillMedicine.fromJson(medicineData))
            .toList();

        debugPrint(
            '[RefillAPI] Successfully fetched ${medicines.length} refillable medicines');
        return medicines;
      } else {
        // _handleErrorResponse throws an exception, so this return never happens
        // but we keep it here anyway
        _handleErrorResponse(response);
        return []; // this line never runs
      }
    } on http.ClientException catch (e) {
      debugPrint('[RefillAPI] Client exception: $e');
      throw ApiException('Connection Error',
          'Unable to connect to server. Please check your internet connection.');
    } on TimeoutException catch (e) {
      debugPrint('[RefillAPI] Timeout exception: $e');
      throw ApiException('Request Timeout',
          'The request took too long to complete. Please try again.');
    } catch (e) {
      debugPrint('[RefillAPI] Unexpected error: $e');
      throw ApiException('Request Failed',
          'An unexpected error occurred while fetching refillable medicines.');
    }
  }

  // add a medicine to cart for refill (using the refill-cart endpoint)
  static Future<bool> addToCartForRefill(int productId) async {
    try {
      debugPrint('[RefillAPI] Adding product $productId to cart for refill...');

      // Get auth token
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        throw ApiException(
            'Authentication Required', 'Please log in to add items to cart.');
      }

      // Prepare headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'ECL-Pharmacy-App/1.0',
      };

      // Prepare request body with product_id
      final body = {
        'product_id': productId,
      };

      // Make API request to refill-cart endpoint
      final response = await http
          .post(
            Uri.parse('$baseUrl/refill-cart'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(requestTimeout);

      debugPrint(
          '[RefillAPI] Add to cart response status: ${response.statusCode}');
      debugPrint('[RefillAPI] Add to cart response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final success = data['success'] ?? data['status'] == 'success';

        if (success) {
          debugPrint(
              '[RefillAPI] Successfully added product to cart for refill');
          return true;
        } else {
          throw ApiException('Failed to Add to Cart',
              data['message'] ?? 'Failed to add product to cart.');
        }
      } else {
        // _handleErrorResponse throws an exception, so this return is unreachable
        // but we keep it for clarity
        _handleErrorResponse(response);
        return false; // This line will never execute
      }
    } on http.ClientException catch (e) {
      debugPrint('[RefillAPI] Client exception: $e');
      throw ApiException('Connection Error',
          'Unable to connect to server. Please check your internet connection.');
    } on TimeoutException catch (e) {
      debugPrint('[RefillAPI] Timeout exception: $e');
      throw ApiException('Request Timeout',
          'The request took too long to complete. Please try again.');
    } catch (e) {
      debugPrint('[RefillAPI] Unexpected error: $e');
      throw ApiException('Request Failed',
          'An unexpected error occurred while adding product to cart.');
    }
  }

  // Get auth token (reusing the pattern from ApiService)
  static Future<String?> _getAuthToken() async {
    try {
      // Use the same auth service as ApiService
      return await AuthService.getToken();
    } catch (e) {
      debugPrint('[RefillAPI] Error getting auth token: $e');
      return null;
    }
  }

  // handle errors from the api
  static void _handleErrorResponse(http.Response response) {
    String message = 'An error occurred';
    String details = 'Please try again later.';

    try {
      final errorData = json.decode(response.body);
      message = errorData['message'] ?? message;
      details = errorData['details'] ?? details;
    } catch (e) {
      // if we cant parse the json, just use a default message
    }

    switch (response.statusCode) {
      case 400:
        throw ApiException('Bad Request', message);
      case 401:
        throw ApiException('Unauthorized', 'Please log in again.');
      case 403:
        throw ApiException(
            'Forbidden', 'You don\'t have permission to access this resource.');
      case 404:
        throw ApiException(
            'Not Found', 'The requested resource was not found.');
      case 422:
        throw ApiException('Validation Error', message);
      case 429:
        throw ApiException(
            'Too Many Requests', 'Please wait a moment before trying again.');
      case 500:
        throw ApiException('Server Error',
            'Something went wrong on our end. Please try again later.');
      case 502:
        throw ApiException('Bad Gateway',
            'The server is temporarily unavailable. Please try again later.');
      case 503:
        throw ApiException('Service Unavailable',
            'The service is temporarily unavailable. Please try again later.');
      default:
        throw ApiException('Request Failed',
            'An unexpected error occurred. Please try again.');
    }
  }
}
