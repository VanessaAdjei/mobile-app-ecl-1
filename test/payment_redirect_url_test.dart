import 'package:eclapp/utils/payment_redirect_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alignExpressPayCheckoutUrl', () {
    test('bumps undercharged amount query param', () {
      const url =
          'https://sandbox.expresspaygh.com/checkout.php?token=abc&amount=115.00';
      final aligned = alignExpressPayCheckoutUrl(url, 135);
      expect(aligned, contains('amount=135.00'));
      expect(aligned, isNot(contains('amount=115')));
    });

    test('leaves URL unchanged when amount already matches', () {
      const url =
          'https://sandbox.expresspaygh.com/api/checkout.php?token=abc&amount=135.00';
      expect(alignExpressPayCheckoutUrl(url, 135), url);
    });

    test('leaves token-only checkout URL unchanged', () {
      const url =
          'https://sandbox.expresspaygh.com/api/checkout.php?token=abc123';
      expect(alignExpressPayCheckoutUrl(url, 133.4), url);
    });
  });

  group('prepareExpressPayPortalUrl', () {
    test('parses bare URL string', () {
      const raw =
          'https://sandbox.expresspaygh.com/api/checkout.php?token=abc123';
      expect(prepareExpressPayPortalUrl(raw), raw);
    });

    test('parses JSON-encoded URL string', () {
      const raw =
          '"https://sandbox.expresspaygh.com/api/checkout.php?token=abc123"';
      expect(
        prepareExpressPayPortalUrl(raw),
        'https://sandbox.expresspaygh.com/api/checkout.php?token=abc123',
      );
    });
  });
}
