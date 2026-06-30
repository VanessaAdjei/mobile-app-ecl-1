import 'package:eclapp/utils/expresspay_amount_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseExpressPayDisplayedAmount', () {
    test('reads GHS amounts from page text', () {
      const text = 'Pay now\nDenomination\nGHS 98.40\nSelect method';
      expect(parseExpressPayDisplayedAmount(text), 98.4);
    });
  });

  group('expressPayAmountIsUndercharged', () {
    test('flags merchandise-only total when fees were expected', () {
      const text = 'Amount due GHS 98.40';
      expect(
        expressPayAmountIsUndercharged(
          pageText: text,
          expectedAmount: 133.4,
        ),
        isTrue,
      );
    });

    test('passes when displayed matches expected', () {
      const text = 'Total GHS 133.40';
      expect(
        expressPayAmountIsUndercharged(
          pageText: text,
          expectedAmount: 133.4,
        ),
        isFalse,
      );
    });

    test('flags undercharge when URL-injected amount is higher than bill', () {
      const text = 'Pay GHS 70.00\nHidden GHS 90.00';
      expect(
        resolveExpressPayPayableAmount(
          pageText: text,
          expectedAmount: 90,
        ),
        70,
      );
      expect(
        expressPayAmountIsUndercharged(
          pageText: text,
          expectedAmount: 90,
        ),
        isTrue,
      );
    });
  });
}
