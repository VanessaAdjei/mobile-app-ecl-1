// pages/ProductModel.dart
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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      urlName: json['url_name'],
      status: json['status'],
      price: json['price']?.toString() ?? '0.00',
      thumbnail: json['thumbnail'] ?? '',
      quantity: json['quantity'] ?? '',
      batch_no: json['batch_no'] ?? '',
      category: json['category'] ?? '',
      route: json['route'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      otcpom: json['otcpom'],
      drug: json['drug'],
      wellness: json['wellness'],
      selfcare: json['selfcare'],
      accessories: json['accessories'],
    );
  }
}
