import 'package:eclapp/services/delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryService.billingCheckoutPayloadFromResponse', () {
    test('extracts promo, closest store, and delivery fee from get-billing shape',
        () {
      final payload = DeliveryService.billingCheckoutPayloadFromResponse({
        'data': {
          'billingAddr': {
            'fname': 'Test',
            'distance_text': '58 m',
          },
          'closest_store': {
            'distance_text': '58 m',
            'duration_text': '1 min',
            'delivery_fee': '20.00',
          },
          'delivery_fee': '20.00',
          'promo_details': {
            'subtotal': 83,
            'running_subtotal': 83,
            'shipping_free': false,
          },
          'selected_store_description': 'Airport Retail',
        },
      });

      expect(payload, isNotNull);
      expect(payload!['promo_details'], isA<Map>());
      expect(payload['closest_store'], isA<Map>());
      expect(payload['delivery_fee'], '20.00');
      expect(payload['selected_store_description'], 'Airport Retail');
    });

    test('returns null when response has address only', () {
      final payload = DeliveryService.billingCheckoutPayloadFromResponse({
        'data': {
          'billingAddr': {
            'fname': 'Test',
            'addr_1': 'Main St',
          },
        },
      });

      expect(payload, isNull);
    });
  });
}
