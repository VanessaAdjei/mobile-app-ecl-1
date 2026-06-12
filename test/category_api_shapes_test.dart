import 'package:eclapp/models/category_fetch_result.dart';
import 'package:eclapp/utils/category_utils.dart';
import 'package:eclapp/utils/product_detail_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const personalCareSubcategories = {
    'success': true,
    'data': [
      {
        'id': 36,
        'name': 'Hair Care',
        'route':
            'https://eclcommerce.ernestchemists.com.gh/category-all/Hair%20Care',
        'has_product_categories': true,
      },
      {
        'id': 37,
        'name': 'Beauty & Skin Care',
        'route':
            'https://eclcommerce.ernestchemists.com.gh/category-all/Beauty%20&%20Skin%20Care',
        'has_product_categories': true,
      },
    ],
  };

  const hairCareProducts = {
    'success': true,
    'data': [
      {
        'id': 269,
        'name': 'Dr Organic Moroccan Argan Oil Conditioner 265ml',
        'price': '60.00',
        'thumbnail':
            'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/_1747995636_Dr Organic Moroccan Argan Oil Conditioner 265ml.png',
        'url':
            'https://eclcommerce.ernestchemists.com.gh/product-details/dr-organic-moroccan-argan-oil-conditioner-265ml-32843e459f',
        'otcpom': null,
      },
      {
        'id': 246,
        'name': 'Dr Organic Aloe Vera Conditioner 265ml',
        'price': '0.00',
        'thumbnail':
            'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/_1743592732_Dr Organic Aloe Vera Conditioner 265ml.png',
        'url':
            'https://eclcommerce.ernestchemists.com.gh/product-details/dr-organic-aloe-vera-conditioner-265ml-7cac636440',
        'otcpom': null,
      },
    ],
  };

  test('subcategory list parses from success/data array', () {
    final rows = normalizeCategoryApiRows(
      CategoryFetchResult.extractDataList(personalCareSubcategories),
    );

    expect(rows, hasLength(2));
    expect(rows.first['name'], 'Hair Care');
    expect(subcategoryHasProductCategoriesFromApi(rows.first), isTrue);
    expect(isCategoryProductListRow(rows.first), isFalse);
  });

  test('categoryListRowsAreProducts detects flat product payloads', () {
    final rows = normalizeCategoryApiRows(
      CategoryFetchResult.extractDataList(hairCareProducts),
    );
    expect(categoryListRowsAreProducts(rows), isTrue);
  });

  test('leaf category /categories/{id} returns subcategory wrapper not products', () {
    final wrapper = normalizeCategoryApiRows(
      CategoryFetchResult.extractDataList({
        'success': true,
        'data': [
          {
            'id': 54,
            'name': 'SUPPLEMENTS',
            'route': 'https://eclcommerce.example/category-all/SUPPLEMENTS',
            'has_product_categories': true,
          },
        ],
      }),
    );
    expect(categoryListRowsAreProducts(wrapper), isFalse);
    expect(subcategoryHasProductCategoriesFromApi(wrapper.first), isTrue);
  });

  test('categoryListRowsAreProducts rejects subcategory payloads', () {
    final rows = normalizeCategoryApiRows(
      CategoryFetchResult.extractDataList(personalCareSubcategories),
    );
    expect(categoryListRowsAreProducts(rows), isFalse);
  });

  test('product list parses flat rows with string price and null otcpom', () {
    final rows = normalizeCategoryApiRows(
      CategoryFetchResult.extractDataList(hairCareProducts),
    );

    expect(rows, hasLength(2));
    expect(rows.first['price'], '60.00');
    expect(rows.first['otcpom'], isNull);
    expect(isCategoryProductListRow(rows.first), isTrue);

    final slug = slugFromProductLink(rows.first['url'] as String);
    expect(
      slug,
      'dr-organic-moroccan-argan-oil-conditioner-265ml-32843e459f',
    );
  });
}
