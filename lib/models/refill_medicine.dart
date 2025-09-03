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
    return RefillMedicine(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'No name',
      description: json['description'] ?? '',
      dosage: json['dosage'] ?? '',
      price: (json['price'] ?? 0).toString(),
      thumbnail: json['thumbnail'] ?? json['image'] ?? '',
      category: json['category'] ?? '',
      lastPurchased: json['last_purchased'] ?? '',
      isRefillable: json['is_refillable'] ?? false,
      batchNo: json['batch_no'],
      route: json['route'],
      otcpom: json['otcpom'],
      drug: json['drug'],
      wellness: json['wellness'],
      selfcare: json['selfcare'],
      accessories: json['accessories'],
      quantityInStock: json['quantity_in_stock'] ?? 0,
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
