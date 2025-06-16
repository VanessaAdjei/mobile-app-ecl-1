import 'package:google_maps_flutter/google_maps_flutter.dart';

class SavedAddress {
  final String address;
  final LatLng location;

  SavedAddress({required this.address, required this.location});

  Map<String, dynamic> toJson() => {
    'address': address,
    'lat': location.latitude,
    'lng': location.longitude,
  };

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      address: json['address'],
      location: LatLng(json['lat'], json['lng']),
    );
  }
}
