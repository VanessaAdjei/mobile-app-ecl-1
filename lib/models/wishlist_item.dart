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
    return WishlistItem(
      id: json['id'] ?? 0,
      product: Product.fromJson(json['product'] ?? {}),
      addedAt:
          DateTime.parse(json['added_at'] ?? DateTime.now().toIso8601String()),
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
