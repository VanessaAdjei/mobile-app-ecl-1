import 'package:eclapp/utils/point_in_polygon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('point inside simple square polygon', () {
    const square = [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];

    expect(
      PointInPolygon.isInside(const LatLng(1, 1), [square]),
      isTrue,
    );
    expect(
      PointInPolygon.isInside(const LatLng(3, 3), [square]),
      isFalse,
    );
  });
}
