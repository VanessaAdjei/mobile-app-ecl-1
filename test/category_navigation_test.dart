import 'package:eclapp/utils/category_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('categoryHasSubcategoriesFromApi reads bool from API', () {
    expect(
      categoryHasSubcategoriesFromApi({'id': 1, 'has_subcategories': true}),
      isTrue,
    );
    expect(
      categoryHasSubcategoriesFromApi({'id': 12, 'has_subcategories': false}),
      isFalse,
    );
  });

  test('supplements (id 12) is a leaf category', () {
    expect(
      categoryHasSubcategoriesFromApi({
        'id': 12,
        'name': 'SUPPLEMENTS',
        'has_subcategories': false,
      }),
      isFalse,
    );
  });
}
