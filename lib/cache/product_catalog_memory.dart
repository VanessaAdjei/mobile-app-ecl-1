import '../models/product_model.dart';

/// In-memory catalog snapshot for fast lookups (e.g. product detail otcpom).
/// Updated by [ProductCache] when the catalog is loaded or refreshed.
class ProductCatalogMemory {
  static List<Product> _products = const [];

  static List<Product> get products => _products;
  static bool get hasProducts => _products.isNotEmpty;

  static void setProducts(List<Product> products) {
    _products = List<Product>.unmodifiable(products);
  }

  static void clear() {
    _products = const [];
  }
}
