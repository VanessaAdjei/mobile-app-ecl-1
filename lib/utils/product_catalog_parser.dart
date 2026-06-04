import 'dart:convert';

import '../models/product_model.dart';
import 'product_detail_parser.dart';
import 'product_image_url.dart';

/// True when the API body indicates success (`success: true` or `status: "success"`).
bool isCatalogApiBodySuccess(Map<String, dynamic> body) {
  if (body['success'] == true) return true;
  final status = body['status']?.toString().trim().toLowerCase();
  if (status == 'success') return true;
  if (body['success'] == false) return false;
  if (status == 'error' || status == 'failed' || status == 'failure') {
    return false;
  }
  // Legacy responses: `data` array without explicit status/success flags.
  return body['data'] is List;
}

/// `data` array from a get-all-products JSON body.
List<dynamic> extractCatalogDataListFromBody(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const [];
  final data = Map<String, dynamic>.from(decoded);
  if (!isCatalogApiBodySuccess(data)) return const [];
  final list = data['data'];
  if (list is! List) return const [];
  return List<dynamic>.from(list);
}

/// Parsed products + raw rows for category search indexing.
class CatalogParseBundle {
  const CatalogParseBundle(
    this.products,
    this.rawItems, {
    this.apiSuccess = false,
  });
  final List<Product> products;
  final List<dynamic> rawItems;
  final bool apiSuccess;
}

CatalogParseBundle parseCatalogBodyBundle(String body) {
  if (body.trim().isEmpty) {
    return const CatalogParseBundle([], [], apiSuccess: false);
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    return const CatalogParseBundle([], [], apiSuccess: false);
  }
  final data = Map<String, dynamic>.from(decoded);
  final apiSuccess = isCatalogApiBodySuccess(data);
  final rawItems = extractCatalogDataListFromBody(body);
  return CatalogParseBundle(
    productsFromApiDataList(rawItems),
    rawItems,
    apiSuccess: apiSuccess,
  );
}

/// Parse full catalog API body off the UI thread (large JSON).
List<Product> parseCatalogApiResponse(String body) {
  return productsFromApiDataList(extractCatalogDataListFromBody(body));
}

List<Product> productsFromApiDataList(List<dynamic> items) {
  final products = <Product>[];
  for (final raw in items) {
    try {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final productRaw = item['product'];
      if (productRaw is Map) {
        products.add(_productFromCatalogRow(item, productRaw));
        continue;
      }
      // popular-products / get-home-priority may return flat product rows
      if (item.containsKey('name') || item.containsKey('url_name')) {
        products.add(_productFromFlatMap(item));
      }
    } catch (_) {
      // skip malformed row
    }
  }
  return products;
}

int _intId(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _stringField(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is Map) {
    return value['description']?.toString() ??
        value['name']?.toString() ??
        fallback;
  }
  return value.toString();
}

String? _optionalString(dynamic value) {
  final s = _stringField(value, '').trim();
  return s.isEmpty ? null : s;
}

/// Avoid `1.6499999999999999` from JSON doubles in UI and cart.
String _formatCatalogPrice(dynamic raw) {
  if (raw == null) return '0.00';
  final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  if (n == null || n.isNaN) return '0.00';
  if (n == n.roundToDouble() && n.abs() < 1e15) {
    return n.round().toString();
  }
  return n.toStringAsFixed(2);
}

String _urlNameFromRow(
  Map<String, dynamic> item,
  Map<String, dynamic> productData,
) {
  final fromNested = _stringField(productData['url_name']);
  if (fromNested.isNotEmpty) return fromNested;
  return _stringField(item['url_name']);
}

String _nameFromCatalogRow(
  Map<String, dynamic> item,
  Map<String, dynamic> productData,
  String urlName,
) {
  final explicit = _stringField(productData['name']).trim();
  if (explicit.isNotEmpty && explicit.toLowerCase() != 'no name') {
    return explicit;
  }
  final rowName = _stringField(item['name']).trim();
  if (rowName.isNotEmpty) return rowName;
  if (urlName.isNotEmpty) {
    return extractProductNameFromUrlSlug(urlName);
  }
  return 'Unknown Product';
}

int _productIdFromRow(
  Map<String, dynamic> item,
  Map<String, dynamic> productData,
) {
  final productId = _intId(item['product_id']);
  if (productId != 0) return productId;
  final rowId = _intId(item['id']);
  if (rowId != 0) return rowId;
  return _intId(productData['id']);
}

String _thumbnailFromMaps(
  Map<String, dynamic> row,
  Map<String, dynamic> productData,
) {
  final fromFields = coerceProductImageSource(
    productData['thumbnail'] ??
        productData['image'] ??
        row['thumbnail'] ??
        row['image'] ??
        row['product_img'] ??
        row['product_image'],
  );
  if (fromFields.isNotEmpty) return fromFields;

  for (final images in [productData['images'], row['images']]) {
    if (images is! List) continue;
    for (final entry in images) {
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      final url = coerceProductImageSource(
        m['image_url'] ?? m['url'] ?? m['src'] ?? m['thumbnail'],
      );
      if (url.isNotEmpty) return url;
    }
  }
  return '';
}

List<String> _galleryUrlsFromMaps(
  Map<String, dynamic> row,
  Map<String, dynamic> productData,
) {
  final out = <String>[];
  void add(dynamic raw) {
    final url = coerceProductImageSource(raw);
    if (url.isNotEmpty && !out.contains(url)) out.add(url);
  }

  add(_thumbnailFromMaps(row, productData));

  for (final images in [productData['images'], row['images']]) {
    if (images is! List) continue;
    for (final entry in images) {
      if (entry is Map) {
        final m = Map<String, dynamic>.from(entry);
        add(m['image_url'] ?? m['url'] ?? m['src'] ?? m['thumbnail'] ?? m);
      } else {
        add(entry);
      }
    }
  }
  return out;
}

Product _productFromCatalogRow(
  Map<String, dynamic> item,
  Map<dynamic, dynamic> productRaw,
) {
  final productData = Map<String, dynamic>.from(productRaw);
  final urlName = _urlNameFromRow(item, productData);
  final gallery = _galleryUrlsFromMaps(item, productData);
  final thumb = gallery.isNotEmpty
      ? gallery.first
      : _thumbnailFromMaps(item, productData);

  return Product(
    id: _productIdFromRow(item, productData),
    name: _nameFromCatalogRow(item, productData, urlName),
    description: _stringField(productData['description']),
    urlName: urlName,
    status: _stringField(productData['status']),
    batch_no: _stringField(item['batch_no'] ?? productData['batch_no']),
    price: _formatCatalogPrice(item['price'] ?? productData['price']),
    thumbnail: thumb,
    galleryImages: gallery,
    quantity: _stringField(
      item['qty_in_stock'] ?? item['stock'] ?? item['quantity'],
    ),
    category: _stringField(productData['category'] ?? item['category']),
    route: _stringField(productData['route'] ?? item['route']),
    otcpom: _optionalString(productData['otcpom'] ?? item['otcpom']),
    drug: _optionalString(productData['drug'] ?? item['drug']),
    wellness: _optionalString(productData['wellness'] ?? item['wellness']),
    selfcare: _optionalString(productData['selfcare'] ?? item['selfcare']),
    accessories:
        _optionalString(productData['accessories'] ?? item['accessories']),
    categoryId: _intId(item['category_id'] ?? productData['category_id']),
    uom: _optionalString(productData['uom'] ?? item['uom']),
  );
}

Product _productFromFlatMap(Map<String, dynamic> map) {
  final nested = map['product'];
  final productData = nested is Map ? Map<String, dynamic>.from(nested) : map;
  return _productFromCatalogRow(map, productData);
}

List<Product> productsFromSearchApiList(List<dynamic> items) {
  return items.map<Product>((item) {
    final map =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final urlName = _stringField(map['url_name']);
    return Product(
      id: _intId(map['id'] ?? map['product_id']),
      name: _stringField(map['name']).isNotEmpty
          ? _stringField(map['name'])
          : extractProductNameFromUrlSlug(urlName),
      description: _stringField(map['tag_description'] ?? map['description']),
      urlName: urlName,
      status: _stringField(map['status']),
      batch_no: _stringField(map['batch_no']),
      price: '',
      thumbnail: coerceProductImageSource(map['thumbnail'] ?? map['image']),
      quantity: _stringField(map['quantity'] ?? map['qty_in_stock']),
      category: _stringField(map['category']),
      route: _stringField(map['route']),
    );
  }).toList();
}
