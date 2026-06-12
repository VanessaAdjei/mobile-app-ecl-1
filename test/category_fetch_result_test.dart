import 'package:eclapp/models/category_fetch_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractDataList reads flat data array', () {
    final list = CategoryFetchResult.extractDataList({
      'success': true,
      'data': [
        {'id': 36, 'name': 'Hair Care', 'has_product_categories': true},
      ],
    });

    expect(list, hasLength(1));
    expect(list.first['name'], 'Hair Care');
  });

  test('extractDataList reads nested products array', () {
    final list = CategoryFetchResult.extractDataList({
      'success': true,
      'data': {
        'products': [
          {'id': 1, 'name': 'Vitamin C'},
        ],
      },
    });

    expect(list, hasLength(1));
    expect(list.first['name'], 'Vitamin C');
  });
}
