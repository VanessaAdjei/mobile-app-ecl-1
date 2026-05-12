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

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? urlName,
    String? status,
    String? batchNo,
    String? price,
    String? thumbnail,
    String? quantity,
    String? category,
    String? route,
    String? otcpom,
    String? drug,
    String? wellness,
    String? selfcare,
    String? accessories,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      urlName: urlName ?? this.urlName,
      status: status ?? this.status,
      batchNo: batchNo ?? this.batchNo,
      price: price ?? this.price,
      thumbnail: thumbnail ?? this.thumbnail,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      route: route ?? this.route,
      otcpom: otcpom ?? this.otcpom,
      drug: drug ?? this.drug,
      wellness: wellness ?? this.wellness,
      selfcare: selfcare ?? this.selfcare,
      accessories: accessories ?? this.accessories,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final productData = json['product'] as Map<String, dynamic>;

    String pickPrice(dynamic wrapper, dynamic nested) {
      double? asPositive(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        final n = double.tryParse(s);
        if (n == null || n <= 0) return null;
        return n;
      }

      final w = wrapper?.toString().trim() ?? '';
      final n = nested?.toString().trim() ?? '';
      if (asPositive(wrapper) != null) return w;
      if (asPositive(nested) != null) return n;
      if (w.isNotEmpty) return w;
      if (n.isNotEmpty) return n;
      return '0';
    }

    return Product(
      id: productData['id'] ?? 0,
      name: productData['name'] ?? 'No name',
      description: productData['description'] ?? '',
      urlName: productData['url_name'] ?? '',
      status: productData['status'] ?? '',
      batchNo: json['batch_no'] ?? '',
      price: pickPrice(json['price'], productData['price']),
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
