// models/product_model.dart
class Product {
  final int id;
  final String name;
  final String description;
  final String urlName;
  final String status;
  final String price;
  final String thumbnail;
  final String quantity;
  final String batch_no;
  final String category;
  final String? route;
  final List<String> tags;
  final String? otcpom;
  final String? drug;
  final String? wellness;
  final String? selfcare;
  final String? accessories;
  final int? categoryId;
  final String? uom;
  /// Resolved gallery URLs from product detail API (may be empty).
  final List<String> galleryImages;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.urlName,
    required this.status,
    required this.price,
    required this.thumbnail,
    required this.quantity,
    required this.category,
    required this.route,
    required this.batch_no,
    this.tags = const [],
    this.otcpom,
    this.drug,
    this.wellness,
    this.selfcare,
    this.accessories,
    this.categoryId,
    this.uom,
    this.galleryImages = const [],
  });

  static List<String> _galleryImagesFromJson(dynamic raw) {
    if (raw == null || raw is! List) return const [];
    return raw
        .map((e) => (e ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is Map) {
      return value['description']?.toString() ??
          value['name']?.toString() ??
          fallback;
    }
    return value.toString();
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null || value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final uomValue = json['uom'];
    String? finalUom;
    if (uomValue is Map<String, dynamic>) {
      finalUom = uomValue['description']?.toString();
    } else if (uomValue is String) {
      finalUom = uomValue;
    }

    return Product(
      id: _asInt(json['id'] ?? json['product_id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      urlName: _asString(json['url_name'] ?? json['urlname']),
      status: _asString(json['status']),
      price: _asString(json['price'] ?? json['unit_price'], '0.00'),
      thumbnail: _asString(
        json['thumbnail'] ?? json['image'] ?? json['product_img'],
      ),
      quantity: _asString(
        json['stock'] ?? json['qty_in_stock'] ?? json['quantity'],
      ),
      batch_no: _asString(json['batch_no']),
      category: _asString(json['category']),
      route: _asString(json['route']),
      tags: _asStringList(json['tags']),
      otcpom: json['otcpom']?.toString(),
      drug: json['drug']?.toString(),
      wellness: json['wellness']?.toString(),
      selfcare: json['selfcare']?.toString(),
      accessories: json['accessories']?.toString(),
      categoryId: _asInt(json['category_id']),
      uom: finalUom,
      galleryImages: _galleryImagesFromJson(json['gallery_images']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'url_name': urlName,
      'status': status,
      'price': price,
      'thumbnail': thumbnail,
      'quantity': quantity,
      'batch_no': batch_no,
      'category': category,
      'route': route,
      'tags': tags,
      'otcpom': otcpom,
      'drug': drug,
      'wellness': wellness,
      'selfcare': selfcare,
      'accessories': accessories,
      'category_id': categoryId,
      'uom': uom,
      'gallery_images': galleryImages,
    };
  }
}
