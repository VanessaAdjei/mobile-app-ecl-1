// models/wishlist_item.dart
import 'product.dart';

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
    // Handle different API response formats
    // Format 1: { id: 1, product: {...}, added_at: "..." }
    // Format 2: { id: 1, product_id: 77, created_at: "...", product: {...} }
    int wishlistItemId = json['id'] ?? 0;

    // Parse product data - wishlist API returns: {id: 1, product: {...}, ...}
    // Product.fromJson expects: {product: {...}, batch_no: ..., price: ...}
    Map<String, dynamic> productData;

    if (json.containsKey('product') && json['product'] is Map) {
      // Wishlist API format: product is nested
      // We need to wrap it for Product.fromJson which expects {product: {...}, batch_no: ..., price: ...}
      final nestedProduct = json['product'] as Map<String, dynamic>;
      productData = {
        'product': nestedProduct,
        'batch_no': '', // Wishlist doesn't include batch info
        'price': '0', // Wishlist doesn't include price
      };
    } else {
      // Fallback: try to use root level data
      // If root has 'product' key, use it; otherwise assume root is product data
      if (json.containsKey('product')) {
        productData = {
          'product': json['product'],
          'batch_no': json['batch_no'] ?? '',
          'price': json['price'] ?? '0',
        };
      } else {
        // Root level is product data - wrap it
        productData = {
          'product': json,
          'batch_no': '',
          'price': '0',
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
