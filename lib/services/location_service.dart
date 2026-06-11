// services/location_service.dart
// services/location_service.dart
// services/location_service.dart
// services/location_service.dart
// services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'google_places_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // cache user location so we dont ask for it every time
  Position? _cachedUserLocation;
  DateTime? _lastLocationUpdate;
  static const Duration _locationCacheDuration = Duration(minutes: 5);

  // get user's current location (uses cache)
  Future<Position?> getCurrentLocation() async {
    try {
      // check if we have a cached location that's still good
      if (_cachedUserLocation != null && _lastLocationUpdate != null) {
        final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceUpdate < _locationCacheDuration) {
          debugPrint(
              '📍 Using cached location: ${_cachedUserLocation!.latitude}, ${_cachedUserLocation!.longitude}');
          return _cachedUserLocation;
        }
      }

      // check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return null;
      }

      // check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        return null;
      }

      // get current position with high accuracy
      debugPrint('📍 Getting current location with high accuracy...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      // save the location to cache
      _cachedUserLocation = position;
      _lastLocationUpdate = DateTime.now();

      debugPrint(
          '✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  // calculate distance between two coordinates in kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // use the most accurate distance calculation method
    final distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    debugPrint(
        '📍 Distance calculation: ($lat1, $lon1) to ($lat2, $lon2) = ${distanceInMeters}m');
    return distanceInMeters / 1000;
  }

  // calculate distance from user's location to a store
  Future<double?> calculateDistanceToStore(
      double storeLat, double storeLon) async {
    final userLocation = await getCurrentLocation();
    if (userLocation == null) {
      return null;
    }

    return calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      storeLat,
      storeLon,
    );
  }

  // format distance to show nicely
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceInKm.round()}km';
    }
  }

  // get address from coordinates
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
    } catch (e) {
      debugPrint('❌ Platform reverse geocode failed: $e');
    }

    if (ApiConfig.hasGoogleMapsApiKey) {
      try {
        final google =
            await GooglePlacesService().reverseGeocodeCoordinates(lat, lon);
        if (google != null && google.isNotEmpty) return google;
      } catch (e) {
        debugPrint('❌ Google reverse geocode failed: $e');
      }
    }

    return null;
  }

  // get coordinates from address (reverse geocoding)
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      debugPrint('📍 Geocoding address: $address');
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations[0];
        debugPrint(
            '📍 Found coordinates: ${location.latitude}, ${location.longitude}');
        return {
          'lat': location.latitude,
          'lon': location.longitude,
        };
      }

      debugPrint('❌ No coordinates found for address: $address');
      return null;
    } catch (e) {
      debugPrint('❌ Error geocoding address: $e');
      return null;
    }
  }

  // clear cached location
  void clearCache() {
    _cachedUserLocation = null;
    _lastLocationUpdate = null;
    debugPrint('🗑️ Location cache cleared');
  }

  /// Check if location services are available
  Future<bool> isLocationAvailable() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled on device');
        return false;
      }

      // then check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current location permission: $permission');

      // if permission is denied, ask for it
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Permission after request: $permission');
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ Error checking location availability: $e');
      return false;
    }
  }
}
