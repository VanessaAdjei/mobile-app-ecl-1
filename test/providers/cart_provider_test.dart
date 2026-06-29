import 'package:eclapp/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartProvider.extractCartItemsList', () {
    test('reads cart_items from root payload', () {
      final list = CartProvider.extractCartItemsList({
        'cart_items': [
          {'id': 1, 'product_name': 'A'},
        ],
      });

      expect(list, hasLength(1));
    });

    test('reads items from nested data payload', () {
      final list = CartProvider.extractCartItemsList({
        'success': true,
        'data': {
          'items': [
            {'id': 2, 'product_name': 'B'},
          ],
        },
      });

      expect(list, hasLength(1));
      expect(list!.first['product_name'], 'B');
    });

    test('returns null when no cart list exists', () {
      expect(
        CartProvider.extractCartItemsList({'success': true}),
        isNull,
      );
    });
  });

  group('CartProvider.normalizeProductName', () {
    test('lowercases and trims', () {
      expect(
        CartProvider.normalizeProductName('  PARACETAMOL  '),
        'paracetamol',
      );
    });

    test('replaces hyphens with spaces', () {
      expect(
        CartProvider.normalizeProductName('E-Panol'),
        'e panol',
      );
    });

    test('normalizes "E-Panol" and "E Panol" to same string', () {
      expect(
        CartProvider.normalizeProductName('E-Panol'),
        CartProvider.normalizeProductName('E Panol'),
      );
    });

    test('collapses multiple spaces', () {
      expect(
        CartProvider.normalizeProductName('A   B   C'),
        'a b c',
      );
    });

    test('handles empty string', () {
      expect(CartProvider.normalizeProductName(''), '');
    });
  });
}
