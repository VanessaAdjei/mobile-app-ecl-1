// models/category.dart
class Category {
  final int id;
  final String name;
  final String description;
  final String image;
  final String status;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.status,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
