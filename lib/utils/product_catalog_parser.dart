import 'dart:convert';

import '../models/product_model.dart';

/// Parse full catalog API body off the UI thread (large JSON).
List<Product> parseCatalogApiResponse(String body) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  final list = data['data'] as List? ?? [];
  return productsFromApiDataList(list);
}

List<Product> productsFromApiDataList(List<dynamic> items) {
  final products = <Product>[];
  for (final raw in items) {
    try {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final productRaw = item['product'];
      if (productRaw is! Map) continue;
      final productData = Map<String, dynamic>.from(productRaw);
      products.add(Product(
        id: productData['id'] ?? 0,
        name: productData['name'] ?? 'No name',
        description: productData['description'] ?? '',
        urlName: productData['url_name'] ?? '',
        status: productData['status'] ?? '',
        batch_no: item['batch_no'] ?? '',
        price: (item['price'] ?? 0).toString(),
        thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
        quantity: item['qty_in_stock']?.toString() ?? '',
        category: productData['category'] ?? '',
        route: productData['route'] ?? '',
        otcpom: productData['otcpom'],
        drug: productData['drug'],
        wellness: productData['wellness'],
        selfcare: productData['selfcare'],
        accessories: productData['accessories'],
      ));
    } catch (_) {
      // skip malformed row
    }
  }
  return products;
}

List<Product> productsFromSearchApiList(List<dynamic> items) {
  return items.map<Product>((item) {
    final map =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return Product(
      id: map['id'] ?? 0,
      name: map['name'] ?? 'No name',
      description: map['tag_description'] ?? '',
      urlName: map['url_name'] ?? '',
      status: map['status'] ?? '',
      batch_no: map['batch_no'] ?? '',
      price: (map['price'] ?? map['selling_price'] ?? 0).toString(),
      thumbnail: map['thumbnail'] ?? map['image'] ?? '',
      quantity: map['quantity']?.toString() ?? '',
      category: map['category'] ?? '',
      route: map['route'] ?? '',
    );
  }).toList();
}
