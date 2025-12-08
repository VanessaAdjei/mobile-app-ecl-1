// models/refill_medicine.dart
class RefillMedicine {
  final int id;
  final String name;
  final String description;
  final String dosage;
  final String price;
  final String thumbnail;
  final String category;
  final String lastPurchased;
  final bool isRefillable;
  final String? batchNo;
  final String? route;
  final String? otcpom;
  final String? drug;
  final String? wellness;
  final String? selfcare;
  final String? accessories;
  final int quantityInStock;

  RefillMedicine({
    required this.id,
    required this.name,
    required this.description,
    required this.dosage,
    required this.price,
    required this.thumbnail,
    required this.category,
    required this.lastPurchased,
    required this.isRefillable,
    this.batchNo,
    this.route,
    this.otcpom,
    this.drug,
    this.wellness,
    this.selfcare,
    this.accessories,
    required this.quantityInStock,
  });

  factory RefillMedicine.fromJson(Map<String, dynamic> json) {
    // Handle nested product data (like regular products API)
    Map<String, dynamic> productData = json;
    if (json.containsKey('product') &&
        json['product'] is Map<String, dynamic>) {
      productData = json['product'] as Map<String, dynamic>;
      // Merge with root level data for fields like price, batch_no, etc.
      productData = {...productData, ...json};
    }

    return RefillMedicine(
      id: productData['id'] ?? json['id'] ?? 0,
      name: productData['name'] ?? json['name'] ?? 'No name',
      description: productData['description'] ?? json['description'] ?? '',
      dosage: productData['dosage'] ?? json['dosage'] ?? '',
      price: (productData['price'] ?? json['price'] ?? 0).toString(),
      thumbnail: productData['thumbnail'] ??
          productData['image'] ??
          json['thumbnail'] ??
          json['image'] ??
          '',
      category: productData['category'] ?? json['category'] ?? '',
      lastPurchased:
          productData['last_purchased'] ?? json['last_purchased'] ?? '',
      isRefillable:
          productData['is_refillable'] ?? json['is_refillable'] ?? false,
      batchNo: productData['batch_no'] ?? json['batch_no'],
      route: productData['route'] ?? json['route'],
      otcpom: productData['otcpom'] ?? json['otcpom'],
      drug: productData['drug'] ?? json['drug'],
      wellness: productData['wellness'] ?? json['wellness'],
      selfcare: productData['selfcare'] ?? json['selfcare'],
      accessories: productData['accessories'] ?? json['accessories'],
      quantityInStock: productData['quantity_in_stock'] ??
          productData['qty_in_stock'] ??
          json['quantity_in_stock'] ??
          json['qty_in_stock'] ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'dosage': dosage,
      'price': price,
      'thumbnail': thumbnail,
      'category': category,
      'last_purchased': lastPurchased,
      'is_refillable': isRefillable,
      'batch_no': batchNo,
      'route': route,
      'otcpom': otcpom,
      'drug': drug,
      'wellness': wellness,
      'selfcare': selfcare,
      'accessories': accessories,
      'quantity_in_stock': quantityInStock,
    };
  }
}
