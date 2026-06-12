import 'package:eclapp/utils/category_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveCategoryImageUrl keeps absolute admin URLs', () {
    expect(
      resolveCategoryImageUrl(
        'https://adm-ecommerce.ernestchemists.com.gh/uploads/category/foo.png',
      ),
      'https://adm-ecommerce.ernestchemists.com.gh/uploads/category/foo.png',
    );
  });

  test('resolveCategoryImageUrl encodes spaces in category filenames', () {
    expect(
      resolveCategoryImageUrl(
        'https://adm-ecommerce.ernestchemists.com.gh/uploads/category/Medicines ECL.jpg',
      ),
      contains('Medicines%20ECL.jpg'),
    );
  });

  test('categoryImageUrlFromApi reads image_url from category row', () {
    expect(
      categoryImageUrlFromApi({
        'id': 1,
        'name': 'MEDICINES',
        'image_url':
            'https://adm-ecommerce.ernestchemists.com.gh/uploads/category/Medicines ECL.jpg',
      }),
      contains('Medicines%20ECL.jpg'),
    );
  });

  test('resolveCategoryImageUrl builds admin path for relative uploads', () {
    expect(
      resolveCategoryImageUrl('uploads/category/Supplement.png'),
      contains('/uploads/category/Supplement.png'),
    );
  });

  test('categoryHasSubcategoriesFromApi uses API flag only', () {
    expect(
      categoryHasSubcategoriesFromApi({'id': 12, 'has_subcategories': false}),
      isFalse,
    );
    expect(
      categoryHasSubcategoriesFromApi({'id': 1, 'has_subcategories': true}),
      isTrue,
    );
  });

  test('subcategoryHasProductCategoriesFromApi reads has_product_categories', () {
    expect(
      subcategoryHasProductCategoriesFromApi({
        'id': 36,
        'name': 'Hair Care',
        'has_product_categories': true,
      }),
      isTrue,
    );
    expect(
      subcategoryHasProductCategoriesFromApi({
        'id': 99,
        'has_product_categories': false,
      }),
      isFalse,
    );
    expect(
      subcategoryHasProductCategoriesFromApi({'id': 1}),
      isTrue,
    );
  });

  test('isCategoryProductListRow distinguishes products from subcategories', () {
    expect(
      isCategoryProductListRow({
        'id': 269,
        'name': 'Dr Organic Moroccan Argan Oil Conditioner 265ml',
        'price': '60.00',
        'thumbnail': 'https://adm-ecommerce.example/uploads/product/foo.png',
        'url':
            'https://eclcommerce.example/product-details/dr-organic-moroccan-argan-oil-conditioner-265ml-32843e459f',
      }),
      isTrue,
    );
    expect(
      isCategoryProductListRow({
        'id': 36,
        'name': 'Hair Care',
        'route': 'https://eclcommerce.example/category-all/Hair%20Care',
        'has_product_categories': true,
      }),
      isFalse,
    );
  });
}
