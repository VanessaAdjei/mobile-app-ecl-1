import '../config/api_config.dart';
import '../services/category_catalog_service.dart';
import 'product_image_url.dart';

bool _apiBoolFlag(dynamic raw, {bool whenMissing = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = '${raw ?? ''}'.toLowerCase().trim();
  if (text.isEmpty) return whenMissing;
  return text == '1' || text == 'true' || text == 'yes';
}

/// Whether a top-level category opens subcategories or a direct product list.
bool categoryHasSubcategoriesFromApi(dynamic category) {
  if (category is! Map) return false;
  return _apiBoolFlag(category['has_subcategories']);
}

/// Whether a subcategory row loads products from `/product-categories/{id}`.
/// When false, products come from `/categories/{id}` (leaf subcategory).
bool subcategoryHasProductCategoriesFromApi(dynamic subcategory) {
  if (subcategory is! Map) return true;
  return _apiBoolFlag(
    subcategory['has_product_categories'],
    whenMissing: true,
  );
}

/// True when a `/categories` or `/product-categories` row is a product card.
bool isCategoryProductListRow(dynamic row) {
  if (row is! Map) return false;
  final url = row['url']?.toString() ?? '';
  if (url.contains('product-details')) return true;
  if (row['thumbnail'] != null && '${row['thumbnail']}'.trim().isNotEmpty) {
    return true;
  }
  if (row['price'] != null) return true;
  return false;
}

/// Parse category / subcategory id from API JSON.
int categoryIdFromApi(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Resolve category banner image from [image_url] (absolute or relative).
String resolveCategoryImageUrl(dynamic imagePath) {
  final path = coerceProductImageSource(imagePath);
  if (path.isEmpty) return '';

  String built;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    built = path;
  } else {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    if (normalized.startsWith('uploads/')) {
      built = '${ApiConfig.adminBaseUrl}/$normalized';
    } else {
      built = '${ApiConfig.adminBaseUrl}/uploads/category/$normalized';
    }
  }

  return encodeProductImageUrl(built);
}

/// Top-level category image from API row (`image_url`, etc.).
String categoryImageUrlFromApi(dynamic category) {
  if (category is! Map) return '';

  final map = Map<String, dynamic>.from(category);
  for (final key in <String>[
    'image_url',
    'image',
    'thumbnail',
    'image_path',
    'banner',
    'icon',
  ]) {
    final url = resolveCategoryImageUrl(map[key]);
    if (url.isNotEmpty) return url;
  }
  return '';
}

/// True when every row from `/categories/{id}` is a product list item.
bool categoryListRowsAreProducts(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return false;
  return rows.every(isCategoryProductListRow);
}

/// Normalize `/categories/{id}` or `/product-categories/{id}` list payloads.
List<Map<String, dynamic>> normalizeCategoryApiRows(List<dynamic> raw) {
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    if (map['product'] is Map) {
      out.add(CategoryCatalogService.convertCatalogItemForCategoryPage(item));
      continue;
    }
    out.add(map);
  }
  return out;
}
