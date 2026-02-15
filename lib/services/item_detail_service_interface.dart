// services/item_detail_service_interface.dart
// Abstract interface for product detail fetching. Allows swapping implementations
// (e.g. for testing or different caching strategies) without changing callers.

import '../models/product_model.dart';

abstract class ItemDetailServiceInterface {
  Future<void> initialize();

  Future<Product> getProductDetails(String urlName, {bool forceRefresh = false});

  Future<List<Product>> getRelatedProducts(String urlName,
      {bool forceRefresh = false});

  Future<List<String>> getProductImages(String urlName,
      {bool forceRefresh = false});
}
