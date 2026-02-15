import 'package:eclapp/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
