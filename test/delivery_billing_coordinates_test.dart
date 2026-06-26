import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryService.attachBillingCoordinates', () {
    test('adds lat/lng and aliases when both coordinates are set', () {
      final body = <String, dynamic>{'name': 'Test'};
      DeliveryService.attachBillingCoordinates(
        body,
        lat: 5.6037,
        lng: -0.1870,
      );

      expect(body['lat'], 5.6037);
      expect(body['lng'], -0.1870);
      expect(body['latitude'], 5.6037);
      expect(body['longitude'], -0.1870);
      expect(body['coordinates'], [5.6037, -0.1870]);
    });

    test('skips coordinates when lat or lng is null', () {
      final body = <String, dynamic>{};
      DeliveryService.attachBillingCoordinates(body, lat: 5.6, lng: null);
      DeliveryService.attachBillingCoordinates(body, lat: null, lng: -0.1);

      expect(body.containsKey('lat'), isFalse);
      expect(body.containsKey('lng'), isFalse);
    });
  });
}
