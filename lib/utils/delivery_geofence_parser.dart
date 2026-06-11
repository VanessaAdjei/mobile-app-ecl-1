import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/delivery_geofence.dart';

/// Parses `/delivery-geofence` and `/validate-geofence` payloads.
class DeliveryGeofenceParser {
  DeliveryGeofenceParser._();

  static DeliveryGeofence? parseGeofenceResponse(dynamic decoded) {
    if (decoded == null) return null;

    final root = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : null;
    if (root == null) return null;

    final message = _string(root['message']);
    final data = root['data'] ?? root['geofence'] ?? root;
    final polygons = <List<LatLng>>[];

    _collectPolygons(data, polygons);
    if (polygons.isEmpty && data != root) {
      _collectPolygons(root, polygons);
    }

    if (polygons.isEmpty) return null;
    return DeliveryGeofence(polygons: polygons, message: message);
  }

  static GeofenceValidationResult? parseValidationResponse(dynamic decoded) {
    if (decoded == null) return null;

    final root = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : null;
    if (root == null) return null;

    final nested = root['data'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : root;

    final valid = _readBool(payload['valid']) ??
        _readBool(payload['inside']) ??
        _readBool(payload['is_valid']) ??
        _readBool(payload['is_inside']) ??
        _readBool(root['valid']) ??
        _readBool(root['inside']);

    if (valid == null) return null;

    final message = _string(payload['message']) ??
        _string(root['message']) ??
        (valid ? 'Location is within the delivery area' : DeliveryGeofenceCopy.outsideArea);

    return GeofenceValidationResult(isValid: valid, message: message);
  }

  static void _collectPolygons(dynamic node, List<List<LatLng>> out) {
    if (node == null) return;

    if (node is List) {
      final ring = _parseCoordinateRing(node);
      if (ring != null && ring.length >= 3) {
        out.add(ring);
        return;
      }
      for (final item in node) {
        _collectPolygons(item, out);
      }
      return;
    }

    if (node is! Map) return;
    final map = Map<String, dynamic>.from(node);

    if (_looksLikeGeoJsonPolygon(map)) {
      final ring = _parseGeoJsonPolygon(map);
      if (ring != null && ring.length >= 3) out.add(ring);
      return;
    }

    for (final key in const [
      'polygon',
      'polygons',
      'coordinates',
      'boundary',
      'boundaries',
      'points',
      'vertices',
      'geofence',
      'delivery_area',
      'areas',
    ]) {
      if (map.containsKey(key)) {
        _collectPolygons(map[key], out);
      }
    }
  }

  static bool _looksLikeGeoJsonPolygon(Map<String, dynamic> map) {
    final type = _string(map['type'])?.toLowerCase();
    return type == 'polygon' && map['coordinates'] is List;
  }

  static List<LatLng>? _parseGeoJsonPolygon(Map<String, dynamic> map) {
    final coordinates = map['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) return null;

    dynamic ring = coordinates.first;
    if (ring is List && ring.isNotEmpty && ring.first is List) {
      if (ring.first is List && (ring.first as List).isNotEmpty) {
        final firstInner = (ring.first as List).first;
        if (firstInner is List) {
          ring = ring.first;
        }
      }
    }
    return _parseCoordinateRing(ring);
  }

  static List<LatLng>? _parseCoordinateRing(dynamic ring) {
    if (ring is! List || ring.isEmpty) return null;

    if (ring.first is Map) {
      final points = <LatLng>[];
      for (final item in ring) {
        final point = _parseLatLngFromMap(item);
        if (point != null) points.add(point);
      }
      return points.length >= 3 ? points : null;
    }

    if (ring.first is List) {
      final points = <LatLng>[];
      for (final item in ring) {
        final point = _parseLatLngFromPair(item);
        if (point != null) points.add(point);
      }
      return points.length >= 3 ? points : null;
    }

    if (ring.length >= 4 && ring.every((e) => e is num)) {
      final points = <LatLng>[];
      for (var i = 0; i + 1 < ring.length; i += 2) {
        final lat = (ring[i] as num).toDouble();
        final lng = (ring[i + 1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
      return points.length >= 3 ? points : null;
    }

    return null;
  }

  static LatLng? _parseLatLngFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final lat = _readDouble(map['lat'] ?? map['latitude']);
    final lng = _readDouble(map['lng'] ?? map['longitude'] ?? map['lon']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static LatLng? _parseLatLngFromPair(dynamic raw) {
    if (raw is! List || raw.length < 2) return null;
    final a = (raw[0] as num).toDouble();
    final b = (raw[1] as num).toDouble();

    // GeoJSON uses [lng, lat]; many APIs use [lat, lng].
    if (a.abs() <= 90 && b.abs() > 90) {
      return LatLng(a, b);
    }
    if (b.abs() <= 90 && a.abs() > 90) {
      return LatLng(b, a);
    }
    return LatLng(a, b);
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }
}
