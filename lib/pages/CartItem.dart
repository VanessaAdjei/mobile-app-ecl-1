// pages/CartItem.dart
import 'package:flutter/cupertino.dart';

class CartItem {
  final String id;
  final String productId;
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
      'productId': productId,
      'name': name,
      'price': price,
      if (originalPrice != null) 'originalPrice': originalPrice,
      'quantity': quantity,
      'image': image,
      'batch_no': batchNo,
      'lastModified': lastModified?.toIso8601String(),
      if (purchaseDate != null) 'purchaseDate': purchaseDate?.toIso8601String(),
      'url_name': urlName,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      productId:
          json['productId']?.toString() ?? json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      price: _parseDouble(json['price']),
      originalPrice: json['originalPrice'] != null
          ? _parseDouble(json['originalPrice'])
          : null,
      quantity: _parseInt(json['quantity'] ?? json['qty']),
      image: json['image']?.toString() ?? '',
      batchNo: json['batch_no']?.toString() ?? '',
      lastModified: _parseDate(json['lastModified']),
      purchaseDate: _parseDate(json['purchaseDate']),
      urlName: json['url_name']?.toString() ?? '',
      totalPrice: _parseDouble(json['totalPrice']),
    );
  }

  factory CartItem.fromServerJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      name: json['product_name']?.toString() ?? 'Unknown Item',
      price: _parseDouble(json['price']),
      quantity: _parseInt(json['qty']),
      image: json['product_img']?.toString() ?? '',
      batchNo: json['batch_no']?.toString() ?? '',
      urlName: json['url_name']?.toString() ?? '',
      totalPrice: _parseDouble(json['totalPrice']),
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
