// models/cart_item.dart
import 'package:flutter/cupertino.dart';

import '../utils/product_image_url.dart';

class CartItem {
  final String id;
  final String productId;
  final int? serverProductId;
  final String? originalProductId;
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
  bool isSelected;
  /// When non-null (from check-auth), quantity cannot be changed on the cart page.
  final int? servedBy;

  CartItem({
    required this.id,
    required this.productId,
    this.serverProductId,
    this.originalProductId,
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
    this.isSelected = true,
    this.servedBy,
  }) : lastModified = lastModified ?? DateTime.now();

  /// `served_by == null` in check-auth → user may +/- qty; otherwise read-only.
  bool get canAdjustQuantity => servedBy == null;

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Cart checkout treats lines as selected unless the API explicitly opts out.
  static bool _parseIsSelected(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return true;
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes';
    }
    return true;
  }

  static double _resolveUnitPrice(Map<String, dynamic> json) {
    const priceKeys = <String>[
      'price',
      'unit_price',
      'selling_price',
      'product_price',
      'sale_price',
      'retail_price',
    ];
    for (final key in priceKeys) {
      final parsed = _parseDouble(json[key]);
      if (parsed > 0) return parsed;
    }

    final totalPrice = _parseDouble(json['total_price']);
    final quantity = _parseInt(json['qty'] ?? json['quantity']);
    if (totalPrice > 0 && quantity > 0) {
      return totalPrice / quantity;
    }
    return 0.0;
  }

  /// Charge for one cart line (unit price × qty, or line total when unit is missing).
  static double lineCharge(CartItem item) {
    if (item.price > 0) return item.price * item.quantity;
    if (item.totalPrice > 0) return item.totalPrice;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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
      'is_selected': isSelected,
      'served_by': servedBy,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final price = _resolveUnitPrice(json);
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
      image: coerceProductImageSource(json['product_img'] ?? json['image']),
      batchNo: json['batch_no'] ?? '',
      purchaseDate: _parseDate(json['purchase_date']),
      lastModified: _parseDate(json['last_modified']),
      urlName: json['url_name'] ?? '',
      totalPrice: price * quantity,
      isSelected: _parseIsSelected(json['is_selected']),
      servedBy: _parseNullableInt(json['served_by']),
    );
  }

  factory CartItem.fromServerJson(Map<String, dynamic> json) {
    final flat = flattenServerLine(json);
    final price = _resolveUnitPrice(flat);
    final totalPrice = _parseDouble(flat['total_price']);
    var quantity = _parseInt(flat['qty'] ?? flat['quantity']);
    if (price > 0 && totalPrice > 0) {
      final inferredQty = (totalPrice / price).round();
      if (inferredQty > 0 && inferredQty != quantity) {
        quantity = inferredQty;
      }
    }
    final resolvedQty = quantity > 0 ? quantity : 1;
    return CartItem(
      id: flat['id']?.toString() ?? '',
      productId: flat['product_id']?.toString() ?? '',
      serverProductId: flat['product_id'] is int
          ? flat['product_id']
          : int.tryParse(flat['product_id']?.toString() ?? ''),
      originalProductId: flat['product_id']?.toString(),
      name: flat['product_name']?.toString() ??
          flat['name']?.toString() ??
          'Unknown Item',
      price: price,
      quantity: resolvedQty,
      image: coerceProductImageSource(flat['product_img'] ?? flat['image']),
      batchNo: flat['batch_no']?.toString() ?? '',
      urlName: flat['url_name']?.toString() ?? '',
      totalPrice: totalPrice > 0 ? totalPrice : price * resolvedQty,
      isSelected: _parseIsSelected(flat['is_selected']),
      servedBy: _parseNullableInt(flat['served_by']),
    );
  }

  /// Merges nested `product` objects from check-auth / checkout payloads.
  @visibleForTesting
  static Map<String, dynamic> flattenServerLine(Map<String, dynamic> json) {
    final line = Map<String, dynamic>.from(json);
    final product = line['product'];
    if (product is Map) {
      final p = Map<String, dynamic>.from(product);
      line.putIfAbsent(
        'product_name',
        () => p['product_name'] ?? p['name'],
      );
      line.putIfAbsent('product_id', () => p['product_id'] ?? p['id']);
      line.putIfAbsent(
        'product_img',
        () => p['product_img'] ?? p['image'] ?? p['img'],
      );
      line.putIfAbsent('url_name', () => p['url_name'] ?? p['urlName']);
      line.putIfAbsent(
        'price',
        () => p['price'] ?? p['selling_price'] ?? p['unit_price'],
      );
      line.putIfAbsent('batch_no', () => p['batch_no'] ?? p['batchNo']);
    }
    return line;
  }

  void updateQuantity(int newQuantity) {
    quantity = newQuantity;
    lastModified = DateTime.now();
  }

  CartItem copyWith({
    String? id,
    String? productId,
    int? serverProductId,
    String? originalProductId,
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
    bool? isSelected,
    int? servedBy,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      serverProductId: serverProductId ?? this.serverProductId,
      originalProductId: originalProductId ?? this.originalProductId,
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
      isSelected: isSelected ?? this.isSelected,
      servedBy: servedBy ?? this.servedBy,
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
