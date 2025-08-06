// services/stock_utility_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class StockUtilityService {
  // Check if a product is in stock based on qty_in_stock
  static bool isProductInStock(String? quantity) {
    if (quantity == null || quantity.isEmpty) return false;

    try {
      final qty = int.tryParse(quantity);
      return qty != null && qty > 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error parsing quantity: $e');
      return false;
    }
  }

  // Get stock level from quantity string
  static int getStockLevel(String? quantity) {
    if (quantity == null || quantity.isEmpty) return 0;

    try {
      return int.tryParse(quantity) ?? 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error parsing stock level: $e');
      return 0;
    }
  }

  // Check if stock is low (5 or fewer items)
  static bool isLowStock(String? quantity) {
    final stockLevel = getStockLevel(quantity);
    return stockLevel > 0 && stockLevel <= 5;
  }

  // Get stock status description
  static String getStockStatus(String? quantity) {
    if (!isProductInStock(quantity)) {
      return 'Out of Stock';
    } else if (isLowStock(quantity)) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  // Get stock status color
  static int getStockStatusColor(String? quantity) {
    if (!isProductInStock(quantity)) {
      return 0xFFFF6B35; // Orange for out of stock
    } else if (isLowStock(quantity)) {
      return 0xFFFFA726; // Light orange for low stock
    } else {
      return 0xFF4CAF50; // Green for in stock
    }
  }

  // Check stock from API response
  static bool isProductInStockFromApi(Map<String, dynamic> productData) {
    try {
      final qtyInStock = productData['qty_in_stock'] ?? 0;
      return qtyInStock > 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error checking stock from API: $e');
      return false;
    }
  }

  // Get stock level from API response
  static int getStockLevelFromApi(Map<String, dynamic> productData) {
    try {
      return productData['qty_in_stock'] ?? 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error getting stock level from API: $e');
      return 0;
    }
  }

  // Check if stock is low from API response
  static bool isLowStockFromApi(Map<String, dynamic> productData) {
    final stockLevel = getStockLevelFromApi(productData);
    return stockLevel > 0 && stockLevel <= 5;
  }

  // Get stock status from API response
  static String getStockStatusFromApi(Map<String, dynamic> productData) {
    if (!isProductInStockFromApi(productData)) {
      return 'Out of Stock';
    } else if (isLowStockFromApi(productData)) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  // Get stock status color from API response
  static int getStockStatusColorFromApi(Map<String, dynamic> productData) {
    if (!isProductInStockFromApi(productData)) {
      return 0xFFFF6B35; // Orange for out of stock
    } else if (isLowStockFromApi(productData)) {
      return 0xFFFFA726; // Light orange for low stock
    } else {
      return 0xFF4CAF50; // Green for in stock
    }
  }

  // Format stock level for display
  static String formatStockLevel(String? quantity) {
    final stockLevel = getStockLevel(quantity);
    if (stockLevel == 0) {
      return 'Out of Stock';
    } else if (stockLevel <= 5) {
      return 'Only ${stockLevel} left';
    } else {
      return '${stockLevel} in stock';
    }
  }

  // Format stock level from API response
  static String formatStockLevelFromApi(Map<String, dynamic> productData) {
    final stockLevel = getStockLevelFromApi(productData);
    if (stockLevel == 0) {
      return 'Out of Stock';
    } else if (stockLevel <= 5) {
      return 'Only ${stockLevel} left';
    } else {
      return '${stockLevel} in stock';
    }
  }
}
