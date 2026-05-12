// models/wishlist_item.dart
import 'product.dart';

Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

Map<String, dynamic>? _firstListElementMap(dynamic list) {
  if (list is! List || list.isEmpty) return null;
  return _asJsonMap(list.first);
}

/// [Product.fromJson] reads `price` from the wrapper map (sibling of `product`),
/// not from the nested catalog object. Wishlist rows often mirror list APIs:
/// price on the row, on a sibling `inventory` map, or only inside list shapes.
String _wishlistResolvedPriceString(
  Map<String, dynamic> itemJson,
  Map<String, dynamic>? nestedProduct,
) {
  String? pick(Map<String, dynamic>? map) {
    if (map == null) return null;
    const keys = <String>[
      'price',
      'product_price',
      'unit_price',
      'selling_price',
      'sale_price',
      'retail_price',
      'amount',
      'cost',
    ];
    for (final k in keys) {
      if (!map.containsKey(k) || map[k] == null) continue;
      final s = map[k].toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  final candidates = <Map<String, dynamic>?>[
    itemJson,
    nestedProduct,
    _asJsonMap(itemJson['inventory']),
    _asJsonMap(itemJson['batch']),
    _firstListElementMap(itemJson['inventories']),
    _firstListElementMap(itemJson['batches']),
    _firstListElementMap(itemJson['stocks']),
    _asJsonMap(itemJson['data']),
    if (nestedProduct != null) ...[
      _asJsonMap(nestedProduct['inventory']),
      _asJsonMap(nestedProduct['batch']),
      _firstListElementMap(nestedProduct['inventories']),
      _firstListElementMap(nestedProduct['batches']),
      _firstListElementMap(nestedProduct['stocks']),
      _asJsonMap(nestedProduct['data']),
    ],
  ];

  for (final map in candidates) {
    final p = pick(map);
    if (p != null) return p;
  }
  return '0';
}

class WishlistItem {
  final int id;
  final Product product;
  final DateTime addedAt;

  WishlistItem({
    required this.id,
    required this.product,
    required this.addedAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    int wishlistItemId = json['id'] ?? 0;

    Map<String, dynamic> productData;

    if (json.containsKey('product') && json['product'] is Map) {
      // Wishlist API format: product is nested
      // Product.fromJson expects { product: {...}, batch_no: ..., price: ... }
      final nestedProduct = json['product'] as Map<String, dynamic>;
      final batchNo =
          (json['batch_no'] ?? nestedProduct['batch_no'] ?? '').toString();
      productData = {
        'product': nestedProduct,
        'batch_no': batchNo,
        'price': _wishlistResolvedPriceString(json, nestedProduct),
      };
    } else {
      // Fallback: try to use root level data
      // If root has 'product' key, use it; otherwise assume root is product data
      if (json.containsKey('product')) {
        productData = {
          'product': json['product'],
          'batch_no': json['batch_no'] ?? '',
          'price': _wishlistResolvedPriceString(json, null),
        };
      } else {
        // Root level is product data - wrap it
        productData = {
          'product': json,
          'batch_no': json['batch_no']?.toString() ?? '',
          'price': _wishlistResolvedPriceString(json, json),
        };
      }
    }

    // Parse timestamp - could be 'added_at' or 'created_at'
    DateTime addedDate;
    try {
      if (json.containsKey('added_at') && json['added_at'] != null) {
        addedDate = DateTime.parse(json['added_at'].toString());
      } else if (json.containsKey('created_at') && json['created_at'] != null) {
        addedDate = DateTime.parse(json['created_at'].toString());
      } else {
        addedDate = DateTime.now();
      }
    } catch (e) {
      addedDate = DateTime.now();
    }

    // Create product using Product.fromJson
    final product = Product.fromJson(productData);

    return WishlistItem(
      id: wishlistItemId,
      product: product,
      addedAt: addedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': {
        'product': {
          'id': product.id,
          'name': product.name,
          'description': product.description,
          'url_name': product.urlName,
          'status': product.status,
          'thumbnail': product.thumbnail,
          'qty_in_stock': product.quantity,
          'category': product.category,
          'route': product.route,
          'otcpom': product.otcpom,
          'drug': product.drug,
          'wellness': product.wellness,
          'selfcare': product.selfcare,
          'accessories': product.accessories,
        },
        'batch_no': product.batchNo,
        'price': product.price,
      },
      'added_at': addedAt.toIso8601String(),
    };
  }

  WishlistItem copyWith({
    int? id,
    Product? product,
    DateTime? addedAt,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      product: product ?? this.product,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
