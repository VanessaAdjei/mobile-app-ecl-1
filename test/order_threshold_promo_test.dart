import 'package:eclapp/widgets/order_threshold_promo_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderThresholdPromoBanner free delivery', () {
    test('qualifies at GHS 350+', () {
      expect(
        OrderThresholdPromoBanner.qualifiesForFreeDelivery(349.99),
        isFalse,
      );
      expect(
        OrderThresholdPromoBanner.qualifiesForFreeDelivery(350),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.qualifiesForFreeDelivery(400),
        isTrue,
      );
    });

    test('displayDeliveryFee is zero when subtotal qualifies', () {
      expect(
        OrderThresholdPromoBanner.displayDeliveryFee(400, 25),
        0,
      );
      expect(
        OrderThresholdPromoBanner.displayDeliveryFee(100, 25),
        25,
      );
    });

    test('shippingFreeFromPromo respects shipping_free flag', () {
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': true,
          'subtotal': 50,
        }),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': 'true',
          'subtotal': 50,
        }),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': 1,
          'subtotal': 50,
        }),
        isTrue,
      );
    });

    test('shippingFreeFromPromo uses delivery_threshold and subtotal', () {
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': false,
          'delivery_threshold': 350,
          'subtotal': 83,
        }),
        isFalse,
      );
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': false,
          'delivery_threshold': 350,
          'subtotal': 350,
        }),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.shippingFreeFromPromo({
          'shipping_free': false,
          'delivery_threshold': 200,
          'running_subtotal': 210,
        }),
        isTrue,
      );
    });

    test('effectiveShippingFree combines API flag and cart subtotal', () {
      expect(
        OrderThresholdPromoBanner.effectiveShippingFree(
          apiShippingFree: true,
          merchandiseSubtotal: 50,
          isDelivery: true,
        ),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.effectiveShippingFree(
          apiShippingFree: false,
          merchandiseSubtotal: 375,
          isDelivery: true,
        ),
        isTrue,
      );
      expect(
        OrderThresholdPromoBanner.effectiveShippingFree(
          apiShippingFree: false,
          merchandiseSubtotal: 80,
          isDelivery: true,
        ),
        isFalse,
      );
      expect(
        OrderThresholdPromoBanner.effectiveShippingFree(
          apiShippingFree: false,
          merchandiseSubtotal: 200,
          isDelivery: false,
        ),
        isFalse,
      );
    });
  });
}
