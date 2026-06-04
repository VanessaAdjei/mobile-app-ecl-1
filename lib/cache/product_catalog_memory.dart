import '../models/product_model.dart';

/// In-memory catalog snapshot for fast lookups (e.g. product detail otcpom).
/// Updated by [ProductCache] when the catalog is loaded or refreshed.
class ProductCatalogMemory {
  static List<Product> _products = const [];
  static Map<String, Product> _byUrlName = const {};

  static List<Product> get products => _products;
  static bool get hasProducts => _products.isNotEmpty;

  /// Fast lookup for product detail preview while the detail API loads.
  static Product? findByUrlName(String urlName) {
    if (urlName.isEmpty) return null;
    return _byUrlName[urlName];
  }

  static void setProducts(List<Product> products) {
    _products = List<Product>.unmodifiable(products);
    final index = <String, Product>{};
    for (final p in products) {
      if (p.urlName.isNotEmpty && p.id != 0) {
        index[p.urlName] = p;
      }
    }
    _byUrlName = index;
  }

  static void clear() {
    _products = const [];
    _byUrlName = const {};
  }
}
