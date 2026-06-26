import 'package:eclapp/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartItem', () {
    test('fromJson parses cart item correctly', () {
      final json = {
        'id': 'cart-1',
        'product_id': 'prod-123',
        'product_name': 'Paracetamol',
        'price': 10.50,
        'qty': 2,
        'product_img': 'https://example.com/img.png',
        'batch_no': 'BATCH001',
        'url_name': 'paracetamol',
        'is_selected': true,
      };

      final item = CartItem.fromJson(json);

      expect(item.id, 'cart-1');
      expect(item.productId, 'prod-123');
      expect(item.name, 'Paracetamol');
      expect(item.price, 10.50);
      expect(item.quantity, 2);
      expect(item.totalPrice, 21.0);
      expect(item.batchNo, 'BATCH001');
      expect(item.isSelected, true);
    });

    test('fromJson handles numeric price as int or string', () {
      expect(CartItem.fromJson({'price': 5, 'qty': 1}).price, 5.0);
      expect(CartItem.fromJson({'price': '7.50', 'qty': 1}).price, 7.5);
    });

    test('fromServerJson corrects quantity when total_price differs', () {
      final json = {
        'id': '1',
        'product_id': '100',
        'product_name': 'Item',
        'price': 10.0,
        'total_price': 30.0,
        'qty': 2,
        'product_img': '',
        'batch_no': '',
        'url_name': '',
      };

      final item = CartItem.fromServerJson(json);

      expect(item.quantity, 3);
      expect(item.totalPrice, 30.0);
    });

    test('fromServerJson uses unit_price when price is missing', () {
      final item = CartItem.fromServerJson({
        'id': '1',
        'product_id': '100',
        'product_name': 'Item',
        'unit_price': 12.5,
        'qty': 2,
        'total_price': 25.0,
        'product_img': '',
        'batch_no': '',
        'url_name': '',
      });

      expect(item.price, 12.5);
      expect(item.totalPrice, 25.0);
    });

    test('fromServerJson parses is_selected explicitly', () {
      expect(
        CartItem.fromServerJson({
          'id': '1',
          'product_id': '1',
          'product_name': 'A',
          'price': 5,
          'qty': 1,
        }).isSelected,
        isTrue,
      );
      expect(
        CartItem.fromServerJson({
          'id': '1',
          'product_id': '1',
          'product_name': 'A',
          'price': 5,
          'qty': 1,
          'is_selected': 0,
        }).isSelected,
        isFalse,
      );
      expect(
        CartItem.fromServerJson({
          'id': '1',
          'product_id': '1',
          'product_name': 'A',
          'price': 5,
          'qty': 1,
          'is_selected': false,
        }).isSelected,
        isFalse,
      );
    });

    test('lineCharge uses total_price when unit price is zero', () {
      final item = CartItem(
        id: '1',
        productId: 'p1',
        name: 'P',
        price: 0,
        image: '',
        batchNo: 'B1',
        urlName: '',
        totalPrice: 18,
        quantity: 2,
      );

      expect(CartItem.lineCharge(item), 18);
    });

    test('fromServerJson parses served_by for quantity lock', () {
      final unlocked = CartItem.fromServerJson({
        'id': '1',
        'product_id': '100',
        'product_name': 'OTC Item',
        'price': 5.0,
        'qty': 2,
        'total_price': 10.0,
        'served_by': null,
      });
      final locked = CartItem.fromServerJson({
        'id': '2',
        'product_id': '101',
        'product_name': 'Rx Item',
        'price': 5.0,
        'qty': 1,
        'total_price': 5.0,
        'served_by': 1,
      });

      expect(unlocked.canAdjustQuantity, isTrue);
      expect(locked.canAdjustQuantity, isFalse);
      expect(locked.servedBy, 1);
    });

    test('copyWith preserves unchanged fields', () {
      final item = CartItem(
        id: '1',
        productId: 'p1',
        name: 'Product',
        price: 10.0,
        image: 'img.png',
        batchNo: 'B1',
        urlName: 'url',
        totalPrice: 10.0,
      );

      final updated = item.copyWith(quantity: 3);

      expect(updated.name, 'Product');
      expect(updated.quantity, 3);
      expect(updated.totalPrice, 10.0);
    });

    test('equality uses productId and batchNo', () {
      final a = CartItem(
        id: '1',
        productId: 'p1',
        name: 'A',
        price: 1,
        image: '',
        batchNo: 'B1',
        urlName: '',
        totalPrice: 1,
      );
      final b = CartItem(
        id: '2',
        productId: 'p1',
        name: 'B',
        price: 2,
        image: '',
        batchNo: 'B1',
        urlName: '',
        totalPrice: 2,
      );
      final c = CartItem(
        id: '1',
        productId: 'p2',
        name: 'A',
        price: 1,
        image: '',
        batchNo: 'B1',
        urlName: '',
        totalPrice: 1,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('updateQuantity modifies quantity and lastModified', () {
      final item = CartItem(
        id: '1',
        productId: 'p1',
        name: 'P',
        price: 5,
        image: '',
        batchNo: 'B1',
        urlName: '',
        totalPrice: 5,
      );

      item.updateQuantity(4);

      expect(item.quantity, 4);
      expect(item.lastModified, isNotNull);
    });
  });
}
