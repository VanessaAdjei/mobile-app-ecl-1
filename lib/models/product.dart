// models/product.dart
class Product {
  final int id;
  final String name;
  final String description;
  final String urlName;
  final String status;
  final String batchNo;
  final String price;
  final String thumbnail;
  final String quantity;
  final String category;
  final String route;
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
    required this.batchNo,
    required this.price,
    required this.thumbnail,
    required this.quantity,
    required this.category,
    required this.route,
    this.otcpom,
    this.drug,
    this.wellness,
    this.selfcare,
    this.accessories,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final productData = json['product'] as Map<String, dynamic>;
    return Product(
      id: productData['id'] ?? 0,
      name: productData['name'] ?? 'No name',
      description: productData['description'] ?? '',
      urlName: productData['url_name'] ?? '',
      status: productData['status'] ?? '',
      batchNo: json['batch_no'] ?? '',
      price: (json['price'] ?? 0).toString(),
      thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
      quantity: productData['qty_in_stock']?.toString() ?? '',
      category: productData['category'] ?? '',
      route: productData['route'] ?? '',
      otcpom: productData['otcpom'],
      drug: productData['drug'],
      wellness: productData['wellness'],
      selfcare: productData['selfcare'],
      accessories: productData['accessories'],
    );
  }
}
