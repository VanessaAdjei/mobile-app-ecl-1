// pages/savedaddresses.dart

/// Simple location class to replace Google Maps dependency
class SimpleLocation {
  final double latitude;
  final double longitude;

  const SimpleLocation(this.latitude, this.longitude);

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
      };

  factory SimpleLocation.fromJson(Map<String, dynamic> json) {
    return SimpleLocation(
      json['lat'] as double,
      json['lng'] as double,
    );
  }

  @override
  String toString() => 'SimpleLocation($latitude, $longitude)';
}

class SavedAddress {
  final String address;
  final SimpleLocation? location;

  SavedAddress({required this.address, this.location});

  Map<String, dynamic> toJson() => {
        'address': address,
        if (location != null) ...location!.toJson(),
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      address: json['address'] as String,
      location: json['lat'] != null && json['lng'] != null
          ? SimpleLocation.fromJson(json)
          : null,
    );
  }

  @override
  String toString() => 'SavedAddress(address: $address, location: $location)';
}
