class Store {
  final String name;
  final String city;
  final String region;

  Store({
    required this.name,
    required this.city,
    required this.region,
  });
}

class City {
  final String name;
  final String region;

  City({
    required this.name,
    required this.region,
  });
}
