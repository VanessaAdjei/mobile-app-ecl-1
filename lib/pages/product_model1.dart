class Product1 {
  final String? name;
  final String? price;
  final String? thumbnail;
  final String? urlName;
  final String? description;

  Product1({
    this.name,
    this.price,
    this.thumbnail,
    this.urlName,
    this.description,
  });

  factory Product1.fromJson(Map<String, dynamic> json) {
    return Product1(
      name: json['name'],
      price: json['price'],
      thumbnail: json['thumbnail'],
      urlName: json['route'].split('/').last,  // Extract url_name from route
      description: json['description'],
    );
  }
}
