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

  factory Product.fromJson(Map<String, dynamic> json) {
    final uomValue = json['uom'];
    String? finalUom;
    if (uomValue is Map<String, dynamic>) {
      finalUom = uomValue['description']?.toString();
    } else if (uomValue is String) {
      finalUom = uomValue;
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      urlName: json['url_name'] ?? '',
      status: json['status'] ?? '',
      price: json['price']?.toString() ?? '0.00',
      thumbnail: json['thumbnail'] ?? '',
      quantity: json['stock']?.toString() ??
          json['qty_in_stock']?.toString() ??
          json['quantity']?.toString() ??
          '',
      batch_no: json['batch_no'] ?? '',
      category: json['category'] ?? '',
      route: json['route'] ?? '',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      otcpom: json['otcpom'],
      drug: json['drug'],
      wellness: json['wellness'],
      selfcare: json['selfcare'],
      accessories: json['accessories'],
      categoryId: json['category_id'],
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
