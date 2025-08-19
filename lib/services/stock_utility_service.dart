// services/stock_utility_service.dart
import 'dart:developer';
import 'package:flutter/foundation.dart';

class StockUtilityService {
  static bool isProductInStock(String? quantity) {
    final stockLevel = getStockLevel(quantity);
    final result = stockLevel > 0;

    // Debug logging
    if (kDebugMode) {}

    return result;
  }

  static int getStockLevel(String? quantity) {
    if (quantity == null || quantity.isEmpty) return 0;

    try {
      return int.tryParse(quantity) ?? 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error parsing stock level: $e');
      return 0;
    }
  }

  static bool isLowStock(String? quantity) {
    final stockLevel = getStockLevel(quantity);
    final result = stockLevel > 0 && stockLevel <= 5;

    return result;
  }

  static String getStockStatus(String? quantity) {
    if (!isProductInStock(quantity)) {
      return 'Out of Stock';
    } else if (isLowStock(quantity)) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  static int getStockStatusColor(String? quantity) {
    if (!isProductInStock(quantity)) {
      return 0xFFFF6B35;
    } else if (isLowStock(quantity)) {
      return 0xFFFFA726;
    } else {
      return 0xFF4CAF50;
    }
  }

  static bool isProductInStockFromApi(Map<String, dynamic> productData) {
    try {
      final qtyInStock = productData['qty_in_stock'] ?? 0;
      return qtyInStock > 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error checking stock from API: $e');
      return false;
    }
  }

  static int getStockLevelFromApi(Map<String, dynamic> productData) {
    try {
      return productData['qty_in_stock'] ?? 0;
    } catch (e) {
      debugPrint('StockUtilityService: Error getting stock level from API: $e');
      return 0;
    }
  }

  static bool isLowStockFromApi(Map<String, dynamic> productData) {
    final stockLevel = getStockLevelFromApi(productData);
    return stockLevel > 0 && stockLevel <= 5;
  }

  static String getStockStatusFromApi(Map<String, dynamic> productData) {
    if (!isProductInStockFromApi(productData)) {
      return 'Out of Stock';
    } else if (isLowStockFromApi(productData)) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  static int getStockStatusColorFromApi(Map<String, dynamic> productData) {
    if (!isProductInStockFromApi(productData)) {
      return 0xFFFF6B35;
    } else if (isLowStockFromApi(productData)) {
      return 0xFFFFA726;
    } else {
      return 0xFF4CAF50;
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
