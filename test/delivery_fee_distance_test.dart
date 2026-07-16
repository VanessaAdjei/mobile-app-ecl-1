import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryService distance + fee helpers', () {
    test('formatDistanceText uses metres under 1 km', () {
      expect(DeliveryService.formatDistanceText(0.58), '580 m');
    });

    test('formatDistanceText uses one decimal for km', () {
      expect(DeliveryService.formatDistanceText(9.5), '9.5 km');
    });

    test('normalizeDistanceTextForFeeApi keeps km label', () {
      expect(
        DeliveryService.normalizeDistanceTextForFeeApi('9.5 km'),
        '9.5 km',
      );
    });

    test('parseDistanceTextToKm parses km and metres', () {
      expect(DeliveryService.parseDistanceTextToKm('9.5 km'), 9.5);
      expect(DeliveryService.parseDistanceTextToKm('580 m'), closeTo(0.58, 0.01));
    });

    test('estimateFeeFromCoordinates picks nearest store (Tema address)', () {
      // ECL TEST ACCOUNT coords from checkout logs.
      const temaLat = 5.6930008;
      const temaLng = -0.0337718;

      final stores = [
        {
          'id': 5,
          'description': 'Tema store',
          'lat': '5.6698',
          'lng': '-0.0167',
        },
        {
          'id': 99,
          'description': 'Far store',
          'lat': '6.7000',
          'lng': '-1.5000',
        },
      ];

      final estimate = DeliveryService.estimateFeeFromCoordinates(
        lat: temaLat,
        lng: temaLng,
        stores: stores,
      );

      expect(estimate, isNotNull);
      expect(estimate!['store_id'], 5);
      expect(estimate['distance_text'], isA<String>());
      expect(estimate['distance_km'], isA<double>());
      expect((estimate['distance_km'] as double) > 0, isTrue);
      expect(estimate['delivery_fee'], isA<double>());
    });

    test('calculateDeliveryFeeFromDistanceText matches tier for 9.5 km', () {
      final parsed =
          DeliveryService.calculateDeliveryFeeFromDistanceText('9.5 km');
      expect(parsed, isNotNull);
      expect(parsed!['distanceKm'], 9.5);
      // base 20 + (9.5 - 3) * rate — fee should be > base.
      expect(parsed['fee'], greaterThan(20));
    });

    test('parseCalculateDeliveryFeePayload reads new API shape and rounds money',
        () {
      final parsed = DeliveryService.parseCalculateDeliveryFeePayload({
        'distance': 25.199999999999999289457264239899814128875732421875,
        'delivery_fee': 50.39999999999999857891452847979962825775146484375,
        'xpress_fee': 25.199999999999999289457264239899814128875732421875,
      });

      expect(parsed, isNotNull);
      expect(parsed!['from_api'], isTrue);
      expect(parsed['distance'], closeTo(25.2, 0.0001));
      expect(parsed['delivery_fee'], 50.40);
      expect(parsed['xpress_fee'], 25.20);
    });

    test('roundMoney trims float noise to 2 decimals', () {
      expect(
        DeliveryService.roundMoney(
          50.39999999999999857891452847979962825775146484375,
        ),
        50.40,
      );
      expect(DeliveryService.roundMoney('25.20'), 25.20);
      expect(DeliveryService.roundMoney(null), isNull);
    });
  });
}
