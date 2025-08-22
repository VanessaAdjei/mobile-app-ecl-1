// pages/cart_item.dart
import 'package:flutter/cupertino.dart';

class CartItem {
  final String id;
  final String productId;
  final int? serverProductId;
  final String? originalProductId; // Add field to preserve original product ID
  final String name;
  final double price;
  final double? originalPrice;
  int quantity;
  final String image;
  final String batchNo;
  final DateTime? purchaseDate;
  DateTime? lastModified;
  final String urlName;
  final double totalPrice;

  CartItem({
    required this.id,
    required this.productId,
    this.serverProductId,
    this.originalProductId, // Add to constructor
    required this.name,
    required this.price,
    this.originalPrice,
    this.quantity = 1,
    required this.image,
    required this.batchNo,
    this.purchaseDate,
    DateTime? lastModified,
    required this.urlName,
    required this.totalPrice,
  }) : lastModified = lastModified ?? DateTime.now();

  // Helper methods for parsing
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
  
    
    return {
      'id': id,
      'product_name': name,
      'price': price,
      'qty': quantity,
      'product_img': image,
      'url_name': urlName,
      'batch_no': batchNo,
      'product_id': productId,
      'original_product_id': originalProductId,
      'server_product_id': serverProductId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    debugPrint('🛒 Creating CartItem from JSON: ${json['product_name']}');
    debugPrint('🛒 JSON data: $json');
    
    final price = _parseDouble(json['price']);
    final quantity = _parseInt(json['qty'] ?? json['quantity']);
    
    return CartItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      serverProductId: json['server_product_id'] != null 
          ? int.tryParse(json['server_product_id'].toString()) 
          : null,
      originalProductId: json['original_product_id']?.toString(),
      name: json['product_name'] ?? json['name'] ?? '',
      price: price,
      originalPrice: json['original_price'] != null 
          ? _parseDouble(json['original_price']) 
          : null,
      quantity: quantity,
      image: json['product_img'] ?? json['image'] ?? '',
      batchNo: json['batch_no'] ?? '',
      purchaseDate: _parseDate(json['purchase_date']),
      lastModified: _parseDate(json['last_modified']),
      urlName: json['url_name'] ?? '',
      totalPrice: price * quantity,
    );
  }

  factory CartItem.fromServerJson(Map<String, dynamic> json) {
    final cartItemId = json['id']?.toString() ?? '';
    final serverProductId = json['product_id']?.toString() ?? '';

    debugPrint('🔍 CREATING CART ITEM FROM SERVER JSON ===');
    debugPrint('Raw JSON: $json');
    debugPrint('Cart Item ID: $cartItemId');
    debugPrint('Server Product ID: $serverProductId');
    debugPrint('Product Name: ${json['product_name']}');
    debugPrint('Batch No: ${json['batch_no']}');
    debugPrint('==========================================');

    // Calculate correct quantity from total_price if qty seems wrong
    final price = _parseDouble(json['price']);
    final totalPrice = _parseDouble(json['total_price']);
    final reportedQty = _parseInt(json['qty']);

    // If total_price is greater than price * reported_qty, calculate correct quantity
    int correctQuantity = reportedQty;
    if (price > 0 && totalPrice > 0) {
      final calculatedQty = (totalPrice / price).round();
      if (calculatedQty != reportedQty) {
        debugPrint('🔧 QUANTITY CORRECTION ===');
        debugPrint('Reported Qty: $reportedQty');
        debugPrint('Price: $price');
        debugPrint('Total Price: $totalPrice');
        debugPrint('Calculated Qty: $calculatedQty');
        debugPrint('Using calculated quantity: $calculatedQty');
        debugPrint('==========================');
        correctQuantity = calculatedQty;
      }
    }

    return CartItem(
      id: cartItemId,
      productId: serverProductId, // Keep server product ID as productId
      serverProductId: json['product_id'] is int
          ? json['product_id']
          : int.tryParse(json['product_id']?.toString() ?? ''),
      originalProductId: null, // Will be set when merging with existing items
      name: json['product_name']?.toString() ?? 'Unknown Item',
      price: price,
      quantity: correctQuantity,
      image: json['product_img']?.toString() ?? '',
      batchNo: json['batch_no']?.toString() ?? '',
      urlName: json['url_name']?.toString() ?? '',
      totalPrice: totalPrice,
    );
  }

  void updateQuantity(int newQuantity) {
    quantity = newQuantity;
    lastModified = DateTime.now();
  }

  // Remove duplicate totalPrice getter since it's already defined in the class
  CartItem copyWith({
    String? id,
    String? productId,
    int? serverProductId,
    String? originalProductId, // Add to copyWith
    String? name,
    double? price,
    double? originalPrice,
    int? quantity,
    String? image,
    String? batchNo,
    DateTime? purchaseDate,
    DateTime? lastModified,
    String? urlName,
    double? totalPrice,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      serverProductId: serverProductId ?? this.serverProductId,
      originalProductId:
          originalProductId ?? this.originalProductId, // Add to copyWith
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
      batchNo: batchNo ?? this.batchNo,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      lastModified: lastModified ?? this.lastModified,
      urlName: urlName ?? this.urlName,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          batchNo == other.batchNo;

  @override
  int get hashCode => productId.hashCode ^ batchNo.hashCode;
}
