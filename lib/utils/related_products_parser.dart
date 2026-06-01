import '../models/product_model.dart';

/// Parses `GET /related-products/{urlName}` responses.
class RelatedProductsParser {
  static List<Product> fromResponseBody(
    Map<String, dynamic> body, {
    String? excludeUrlName,
  }) {
    final raw = body['data'];
    if (raw is! List) return const [];

    final exclude = excludeUrlName?.trim().toLowerCase();
    final products = <Product>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final product = _mapItem(Map<String, dynamic>.from(entry));
      if (product == null) continue;
      if (exclude != null && exclude.isNotEmpty &&
          product.urlName.toLowerCase() == exclude) {
        continue;
      }
      products.add(product);
    }

    return products;
  }

  static Product? _mapItem(Map<String, dynamic> item) {
    try {
      final nested = item['product'];
      final productMap =
          nested is Map ? Map<String, dynamic>.from(nested) : null;

      final urlName = _string(item['url_name']) ??
          _string(productMap?['url_name']) ??
          '';

      if (urlName.isEmpty) return null;

      return Product(
        id: _int(item['product_id']) ??
            _int(item['id']) ??
            _int(productMap?['id']) ??
            0,
        name: _string(item['name']) ??
            _string(item['product_name']) ??
            _string(productMap?['name']) ??
            '',
        description: _string(item['description']) ??
            _string(productMap?['description']) ??
            '',
        urlName: urlName,
        status: _string(item['status']) ??
            _string(productMap?['status']) ??
            '',
        batch_no: _string(item['batch_no']) ?? '',
        price: _string(item['price']) ??
            _string(productMap?['price']) ??
            '0.00',
        thumbnail: _string(item['thumbnail']) ??
            _string(item['product_img']) ??
            _string(productMap?['thumbnail']) ??
            _string(productMap?['product_img']) ??
            '',
        quantity: _string(item['qty_in_stock']) ??
            _string(item['quantity']) ??
            _string(productMap?['qty_in_stock']) ??
            '',
        category: _string(item['category']) ??
            _string(productMap?['category']) ??
            '',
        route: '',
        otcpom: _string(item['otcpom']) ?? _string(productMap?['otcpom']),
        uom: _string(item['uom']) ??
            _string(item['unit_of_measure']) ??
            _string(productMap?['uom']) ??
            _string(productMap?['unit_of_measure']),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
