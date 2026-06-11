import 'package:google_maps_flutter/google_maps_flutter.dart';

/// User-facing copy for geofence validation on the map picker.
class DeliveryGeofenceCopy {
  DeliveryGeofenceCopy._();

  static const outsideArea =
      'Delivery is not available to this area. '
      'You can switch to Pickup and choose from our shop locations instead.';

  static const cannotVerify =
      'We could not verify delivery for this area. Please try again.';
}

/// Delivery zone boundary returned by `/delivery-geofence`.
class DeliveryGeofence {
  const DeliveryGeofence({
    required this.polygons,
    this.message,
  });

  /// One or more closed rings (first/last point need not match; map draws closed).
  final List<List<LatLng>> polygons;
  final String? message;

  bool get hasPolygons => polygons.any((ring) => ring.length >= 3);
}

/// Result of `/validate-geofence` for a picked map coordinate.
class GeofenceValidationResult {
  const GeofenceValidationResult({
    required this.isValid,
    this.message,
    this.checkedRemotely = true,
  });

  final bool isValid;
  final String? message;

  /// False when the API route is missing or unreachable and a local fallback was used.
  final bool checkedRemotely;
}
