// models/cart_item.dart
class CartItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String batchNo;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.batchNo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'batchNo': batchNo,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      price: json['price'] as double,
      quantity: json['quantity'] as int,
      imageUrl: json['imageUrl'] as String,
      batchNo: json['batchNo'] as String,
    );
  }
}
