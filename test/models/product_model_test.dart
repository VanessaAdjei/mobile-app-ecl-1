import 'package:eclapp/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('fromJson parses full product correctly', () {
      final json = {
        'id': 42,
        'name': 'Paracetamol 500mg',
        'description': 'Pain relief tablets',
        'url_name': 'paracetamol-500mg',
        'status': 'active',
        'price': '12.50',
        'thumbnail': 'https://example.com/img.png',
        'stock': '100',
        'batch_no': 'BATCH001',
        'category': 'Pain Relief',
        'route': '/products/paracetamol',
        'tags': ['pain', 'fever'],
        'category_id': 5,
      };

      final product = Product.fromJson(json);

      expect(product.id, 42);
      expect(product.name, 'Paracetamol 500mg');
      expect(product.description, 'Pain relief tablets');
      expect(product.urlName, 'paracetamol-500mg');
      expect(product.price, '12.50');
      expect(product.quantity, '100');
      expect(product.batch_no, 'BATCH001');
      expect(product.category, 'Pain Relief');
      expect(product.tags, ['pain', 'fever']);
      expect(product.categoryId, 5);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final product = Product.fromJson(json);

      expect(product.id, 0);
      expect(product.name, '');
      expect(product.description, '');
      expect(product.price, '0.00');
      expect(product.quantity, '');
      expect(product.tags, isEmpty);
      expect(product.route, '');
    });

    test('fromJson extracts quantity from stock, qty_in_stock, or quantity', () {
      expect(Product.fromJson({'stock': '50'}).quantity, '50');
      expect(Product.fromJson({'qty_in_stock': '30'}).quantity, '30');
      expect(Product.fromJson({'quantity': '20'}).quantity, '20');
    });

    test('fromJson handles uom as map or string', () {
      final productFromMap = Product.fromJson({
        'uom': {'description': 'Tablets'},
      });
      expect(productFromMap.uom, 'Tablets');

      final productFromString = Product.fromJson({'uom': 'Capsules'});
      expect(productFromString.uom, 'Capsules');
    });

    test('toJson round-trips correctly', () {
      final product = Product(
        id: 1,
        name: 'Test Product',
        description: 'Desc',
        urlName: 'test',
        status: 'active',
        price: '9.99',
        thumbnail: 'img.png',
        quantity: '10',
        category: 'Cat',
        route: '/route',
        batch_no: 'B1',
        tags: ['a', 'b'],
      );

      final json = product.toJson();
      final restored = Product.fromJson(json);

      expect(restored.id, product.id);
      expect(restored.name, product.name);
      expect(restored.price, product.price);
      expect(restored.tags, product.tags);
    });
  });
}
