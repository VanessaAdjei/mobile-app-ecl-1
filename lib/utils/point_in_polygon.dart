import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Ray-casting point-in-polygon test for delivery geofence rings.
class PointInPolygon {
  PointInPolygon._();

  static bool isInside(LatLng point, List<List<LatLng>> polygons) {
    for (final ring in polygons) {
      if (ring.length >= 3 && _ringContains(point, ring)) {
        return true;
      }
    }
    return false;
  }

  static bool _ringContains(LatLng point, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;

      final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi + 0.0) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}
