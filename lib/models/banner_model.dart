// models/banner_model.dart
class BannerModel {
  final int id;
  final String title;
  final String description;
  final String image;
  final String? link;
  final String status;

  BannerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    this.link,
    required this.status,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      link: json['link'],
      status: json['status'] ?? '',
    );
  }
}
