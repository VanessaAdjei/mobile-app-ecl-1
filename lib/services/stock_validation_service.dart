// services/stock_validation_service.dart
// services/stock_validation_service.dart
// services/stock_validation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StockValidationService {
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const Duration _cacheExpiration = Duration(minutes: 5);

  // Cache for stock data to avoid repeated API calls
  static final Map<String, dynamic> _stockCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Validates if a product has sufficient stock for the requested quantity
  static Future<Map<String, dynamic>> validateStockForOrder({
    required String productId,
    required int requestedQuantity,
    String? productName,
  }) async {
    try {
      // Get current stock level
      final stockInfo = await getProductStockInfo(productId);

      if (stockInfo == null) {
        return {
          'isValid': false,
          'message': 'Unable to verify stock availability. Please try again.',
          'availableStock': 0,
          'requestedQuantity': requestedQuantity,
        };
      }

      final availableStock = stockInfo['qty_in_stock'] ?? 0;
      final stockProductName = stockInfo['product_name'] ?? 'Unknown Product';

      debugPrint('Available Stock: $availableStock');
      debugPrint('Requested Quantity: $requestedQuantity');

      if (availableStock < requestedQuantity) {
        final message = availableStock == 0
            ? '$stockProductName is currently unavailable.'
            : '$stockProductName only has $availableStock units available. You requested $requestedQuantity.';

        return {
          'isValid': false,
          'message': message,
          'availableStock': availableStock,
          'requestedQuantity': requestedQuantity,
          'productName': productName,
        };
      }

      return {
        'isValid': true,
        'message': 'Stock validation passed',
        'availableStock': availableStock,
        'requestedQuantity': requestedQuantity,
        'productName': productName,
      };
    } catch (e) {
      debugPrint('❌ Stock validation error: $e');
      return {
        'isValid': false,
        'message': 'Error checking stock availability. Please try again.',
        'availableStock': 0,
        'requestedQuantity': requestedQuantity,
      };
    }
  }

  /// Validates stock for all items in cart
  static Future<Map<String, dynamic>> validateCartStock(
      List<dynamic> cartItems) async {
    try {
      debugPrint('🔍 CART STOCK VALIDATION ===');
      debugPrint('Cart Items Count: ${cartItems.length}');

      final List<Map<String, dynamic>> stockErrors = [];
      final List<Map<String, dynamic>> stockWarnings = [];

      for (final item in cartItems) {
        final productId = item['productId'] ?? item['id']?.toString();
        final requestedQuantity = item['quantity'] ?? 1;
        final productName = item['name'] ?? 'Unknown Product';

        if (productId == null) {
          debugPrint('⚠️ Skipping item with no product ID: $productName');
          continue;
        }

        final stockValidation = await validateStockForOrder(
          productId: productId,
          requestedQuantity: requestedQuantity,
          productName: productName,
        );

        if (!stockValidation['isValid']) {
          stockErrors.add({
            'productName': productName,
            'requestedQuantity': requestedQuantity,
            'availableStock': stockValidation['availableStock'],
            'message': stockValidation['message'],
          });
        } else if (stockValidation['availableStock'] <= 5) {
          // Add warning for low stock items
          stockWarnings.add({
            'productName': productName,
            'requestedQuantity': requestedQuantity,
            'availableStock': stockValidation['availableStock'],
            'message':
                '$productName has limited stock (${stockValidation['availableStock']} left)',
          });
        }
      }

      final hasErrors = stockErrors.isNotEmpty;
      final hasWarnings = stockWarnings.isNotEmpty;

      debugPrint('Stock Errors: ${stockErrors.length}');
      debugPrint('Stock Warnings: ${stockWarnings.length}');
      debugPrint('========================');

      return {
        'isValid': !hasErrors,
        'errors': stockErrors,
        'warnings': stockWarnings,
        'hasErrors': hasErrors,
        'hasWarnings': hasWarnings,
        'totalItems': cartItems.length,
        'errorCount': stockErrors.length,
        'warningCount': stockWarnings.length,
      };
    } catch (e) {
      debugPrint('❌ Cart stock validation error: $e');
      return {
        'isValid': false,
        'errors': [
          {
            'productName': 'Unknown',
            'message': 'Error checking stock availability. Please try again.',
          }
        ],
        'warnings': [],
        'hasErrors': true,
        'hasWarnings': false,
        'totalItems': cartItems.length,
        'errorCount': 1,
        'warningCount': 0,
      };
    }
  }

  /// Gets current stock information for a product
  static Future<Map<String, dynamic>?> getProductStockInfo(
      String productId) async {
    try {
      // Check cache first
      final cacheKey = 'stock_$productId';
      final cachedData = _stockCache[cacheKey];
      final cacheTime = _cacheTimestamps[cacheKey];

      if (cachedData != null && cacheTime != null) {
        final timeSinceCache = DateTime.now().difference(cacheTime);
        if (timeSinceCache < _cacheExpiration) {
          debugPrint('📦 Using cached stock data for product $productId');
          return cachedData;
        }
      }

      // Try to get the URL name for this product ID first
      // We need to use the product-details endpoint which requires urlName, not productId
      // For now, let's try a different approach - use the inventory endpoint
      final url = '$_baseUrl/inventory/$productId';
      debugPrint('🔍 Fetching stock data from: $url');

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      debugPrint('📡 API Response Status: ${response.statusCode}');
      debugPrint('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('data') && data['data'] != null) {
          final inventoryData = data['data'];
          final stockInfo = {
            'qty_stocked': inventoryData['qty_stocked'] ?? 0,
            'qty_sold': inventoryData['qty_sold'] ?? 0,
            'qty_in_stock':
                inventoryData['qty_in_stock'] ?? inventoryData['quantity'] ?? 0,
            'product_name': inventoryData['product_name'] ?? 'Unknown Product',
            'batch_no': inventoryData['batch_no'] ?? '',
          };

          // Cache the result
          _stockCache[cacheKey] = stockInfo;
          _cacheTimestamps[cacheKey] = DateTime.now();

          debugPrint('📦 Fresh stock data fetched for product $productId');
          return stockInfo;
        } else {
          debugPrint(
              '❌ API response missing data field for product $productId');
        }
      } else {
        debugPrint(
            '❌ API request failed with status ${response.statusCode} for product $productId');
      }

      debugPrint('❌ Failed to get stock info for product $productId');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting stock info for product $productId: $e');
      return null;
    }
  }

  /// Clears the stock cache
  static void clearCache() {
    _stockCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Stock cache cleared');
  }

  /// Gets cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedItems': _stockCache.length,
      'cacheSize': _cacheTimestamps.length,
    };
  }
}
