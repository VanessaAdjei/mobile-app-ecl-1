import '../cache/product_cache.dart';
import '../models/category_fetch_result.dart';
import '../repositories/category_repository.dart';
import '../utils/category_utils.dart';
import '../utils/product_detail_parser.dart';
import 'package:flutter/foundation.dart';

/// Catalog use-cases for categories, subcategories, products, and search.
/// Pages call this service instead of making HTTP requests directly.
class CategoryCatalogService {
  CategoryCatalogService({CategoryRepository? repository})
      : _repository = repository ?? CategoryRepositoryImpl();

  final CategoryRepository _repository;

  /// Dedupes parallel requests for the same category/subcategory list.
  final Map<String, Future<List<Map<String, dynamic>>>> _listInFlight = {};

  /// Leaf categories: `/categories/{id}` → one wrapper id → `/product-categories/{id}`.
  static final Map<int, int> _leafWrapperProductCategoryId = {};

  Future<List<dynamic>> getTopCategories({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result = await _repository.fetchTopCategories(timeout: timeout);
    if (!result.isApiSuccess) {
      throw Exception('Failed to load categories (HTTP ${result.statusCode})');
    }
    return result.data;
  }

  Future<CategoryFetchResult> subcategoryProductsResult(
    int subcategoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _repository.fetchSubcategoryProducts(subcategoryId, timeout: timeout);

  Future<CategoryFetchResult> categorySubcategoriesResult(
    int categoryId, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _repository.fetchCategorySubcategories(categoryId, timeout: timeout);

  /// Products for a leaf category (`has_subcategories: false`) — GET /categories/{id}.
  Future<CategoryFetchResult> categoryProductsResult(
    int categoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      categorySubcategoriesResult(categoryId, timeout: timeout);

  /// Subcategory products — `/product-categories/{id}` or `/categories/{id}`.
  Future<CategoryFetchResult> subcategoryListProductsResult(
    int subcategoryId, {
    required bool hasProductCategories,
    Duration timeout = const Duration(seconds: 15),
  }) {
    if (hasProductCategories) {
      return subcategoryProductsResult(subcategoryId, timeout: timeout);
    }
    return categoryProductsResult(subcategoryId, timeout: timeout);
  }

  /// Parsed rows from a category or subcategory products response.
  List<Map<String, dynamic>> parseCategoryListResult(CategoryFetchResult result) {
    if (!result.isApiSuccess) return const [];
    return normalizeCategoryApiRows(result.data);
  }

  /// `/categories/{id}` may return product rows or subcategory rows.
  /// Leaf categories often return one subcategory wrapper — load its products.
  Future<List<Map<String, dynamic>>> resolveRowsToProducts(
    List<Map<String, dynamic>> rows, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (rows.isEmpty) return const [];
    if (categoryListRowsAreProducts(rows)) return rows;

    if (rows.length == 1 && !categoryListRowsAreProducts(rows)) {
      final subId = categoryIdFromApi(rows.first['id']);
      if (subId > 0) {
        return getSubcategoryListProducts(
          subId,
          hasProductCategories: subcategoryHasProductCategoriesFromApi(rows.first),
          timeout: timeout,
        );
      }
    }

    final batches = await Future.wait(
      rows.map((row) {
        final subId = categoryIdFromApi(row['id']);
        if (subId <= 0) return Future<List<Map<String, dynamic>>>.value(const []);
        return getSubcategoryListProducts(
          subId,
          hasProductCategories: subcategoryHasProductCategoriesFromApi(row),
          timeout: timeout,
        );
      }),
    );

    return batches.expand((batch) => batch).toList();
  }

  Future<List<Map<String, dynamic>>> fetchResolvedCategoryProducts(
    int categoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cachedWrapperId = _leafWrapperProductCategoryId[categoryId];
    if (cachedWrapperId != null) {
      final cached = await getSubcategoryListProducts(
        cachedWrapperId,
        hasProductCategories: true,
        timeout: timeout,
      );
      if (cached.isNotEmpty) return cached;
      _leafWrapperProductCategoryId.remove(categoryId);
    }

    final result = await categoryProductsResult(categoryId, timeout: timeout);
    if (!result.isApiSuccess) return const [];

    final rows = parseCategoryListResult(result);
    if (rows.length == 1 && !categoryListRowsAreProducts(rows)) {
      final subId = categoryIdFromApi(rows.first['id']);
      if (subId > 0) {
        _leafWrapperProductCategoryId[categoryId] = subId;
        return getSubcategoryListProducts(
          subId,
          hasProductCategories: subcategoryHasProductCategoriesFromApi(rows.first),
          timeout: timeout,
        );
      }
    }

    return resolveRowsToProducts(rows, timeout: timeout);
  }

  Future<List<dynamic>> getSubcategories(
    int categoryId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result = await _repository.fetchCategorySubcategories(
      categoryId,
      timeout: timeout,
    );
    if (!result.isApiSuccess) return const [];
    return result.data;
  }

  Future<List<dynamic>> getSubcategoryProducts(
    int subcategoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await _repository.fetchSubcategoryProducts(
      subcategoryId,
      timeout: timeout,
    );
    return parseCategoryListResult(result);
  }

  Future<List<Map<String, dynamic>>> getSubcategoryListProducts(
    int subcategoryId, {
    required bool hasProductCategories,
    Duration timeout = const Duration(seconds: 15),
  }) {
    final key = 'sub:$subcategoryId:${hasProductCategories ? 1 : 0}';
    return _listInFlight.putIfAbsent(key, () async {
      try {
        final result = await subcategoryListProductsResult(
          subcategoryId,
          hasProductCategories: hasProductCategories,
          timeout: timeout,
        );
        return parseCategoryListResult(result);
      } finally {
        _listInFlight.remove(key);
      }
    });
  }

  /// Raw `data` array from get-all-products (each item has nested `product`).
  /// Reuses [ProductCache] — never starts a parallel download while catalog loads.
  Future<List<dynamic>> getRawCatalogItems({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (ProductCache.hasRawCatalogItems) {
      debugPrint(
        'CategoryCatalog: ${ProductCache.cachedRawCatalogItems.length} '
        'raw rows from ProductCache',
      );
      return ProductCache.cachedRawCatalogItems;
    }

    if (ProductCache.isCatalogLoadInFlight || ProductCache.hasProductsInMemory) {
      debugPrint(
        'CategoryCatalog: waiting on ProductCache get-all-products...',
      );
      await ProductCache.ensureCatalogReady(maxWait: timeout);
      if (ProductCache.hasRawCatalogItems) {
        return ProductCache.cachedRawCatalogItems;
      }
    }

    if (!ProductCache.hasProductsInMemory && !ProductCache.isCatalogLoadInFlight) {
      debugPrint('CategoryCatalog: awaiting shared ProductCache prefetch...');
      await ProductCache.prefetchFromNetwork();
      if (ProductCache.hasRawCatalogItems) {
        return ProductCache.cachedRawCatalogItems;
      }
    }

    debugPrint(
      'CategoryCatalog: direct get-all-products (no raw cache — legacy path)',
    );
    final result = await _repository.fetchAllProducts(timeout: timeout);
    if (!result.isHttpOk) return const [];
    return List<dynamic>.from(result.data);
  }

  /// Flattened products with category/subcategory context for search indexing.
  Future<List<Map<String, dynamic>>> getFlattenedCatalog({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final items = await getRawCatalogItems(timeout: timeout);
    return items.map(flattenCatalogItem).toList();
  }

  /// Category-page product shape (includes otcpom fields from full catalog).
  Future<List<dynamic>> getProductsForCategoryCache({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final items = await getRawCatalogItems(timeout: timeout);
    return items.map(convertCatalogItemForCategoryPage).toList();
  }

  Future<List<Map<String, dynamic>>> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result =
        await _repository.searchProducts(query, timeout: timeout);
    if (!result.isHttpOk) return const [];
    return result.data.map<Map<String, dynamic>>((item) {
      final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      return {
        'id': map['id'],
        'name': map['name'] ?? 'Unknown Product',
        'url_name': map['url_name'] ?? '',
        'otcpom': map['otcpom'],
        'thumbnail': map['thumbnail'] ?? map['image'] ?? '',
      };
    }).toList();
  }

  Future<String?> getProductOtcpom(
    int productId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result =
        await _repository.fetchProductById(productId, timeout: timeout);
    if (!result.isApiSuccess) return null;
    return result.dataMap?['otcpom']?.toString();
  }

  /// Builds otcpom / url_name lookup maps from get-all-products response.
  Future<CatalogLookupMaps> buildCatalogLookupMaps({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final items = await getRawCatalogItems(timeout: timeout);
    final otcpomByNameLower = <String, String?>{};
    final urlByProductId = <int, String>{};
    final urlByNameLower = <String, String>{};

    for (final item in items) {
      final productData = item['product'];
      if (productData is! Map) continue;
      final pd = Map<String, dynamic>.from(productData);
      final productName = pd['name']?.toString().toLowerCase();
      final otcpom = pd['otcpom']?.toString();
      if (productName != null && productName.isNotEmpty) {
        otcpomByNameLower[productName] = otcpom;
      }
      final urlName = pd['url_name']?.toString().trim() ??
          item['url_name']?.toString().trim() ??
          slugFromProductLink(item['url']?.toString()) ??
          '';
      if (urlName.isEmpty) continue;
      final productId = _parseIntId(pd['id']);
      if (productId != null) urlByProductId[productId] = urlName;
      final inventoryId = _parseIntId(item['id']);
      if (inventoryId != null) urlByProductId[inventoryId] = urlName;
      final rowProductId = _parseIntId(item['product_id']);
      if (rowProductId != null) urlByProductId[rowProductId] = urlName;
      if (productName != null && productName.isNotEmpty) {
        urlByNameLower[productName] = urlName;
      }
    }

    return CatalogLookupMaps(
      otcpomByNameLower: otcpomByNameLower,
      urlByProductId: urlByProductId,
      urlByNameLower: urlByNameLower,
    );
  }

  static Map<String, dynamic> flattenCatalogItem(dynamic item) {
    final productData =
        item['product'] is Map ? Map<String, dynamic>.from(item['product'] as Map) : <String, dynamic>{};
    return {
      'id': productData['id'],
      'name': productData['name'] ?? 'Unknown Product',
      'url_name': productData['url_name'] ?? '',
      'otcpom': productData['otcpom'],
      'thumbnail': productData['thumbnail'] ?? productData['image'] ?? '',
      'price': item['price'] ?? 0,
      'description': productData['description'] ?? '',
      'category_id': item['category_id'],
      'category_name': item['category_name'],
      'subcategory_id': item['subcategory_id'],
      'subcategory_name': item['subcategory_name'],
    };
  }

  static Map<String, dynamic> convertCatalogItemForCategoryPage(dynamic item) {
    final productData =
        item['product'] is Map ? Map<String, dynamic>.from(item['product'] as Map) : <String, dynamic>{};
    return {
      'id': productData['id'] ?? 0,
      'name': productData['name'] ?? 'No name',
      'description': productData['description'] ?? '',
      'url_name': productData['url_name'] ?? '',
      'status': productData['status'] ?? '',
      'batch_no': item['batch_no'] ?? '',
      'price': (item['price'] ?? 0).toString(),
      'thumbnail': productData['thumbnail'] ?? productData['image'] ?? '',
      'qty_in_stock': productData['qty_in_stock']?.toString() ?? '',
      'category': productData['category'] ?? '',
      'route': productData['route'] ?? '',
      'otcpom': productData['otcpom'],
      'drug': productData['drug'],
      'wellness': productData['wellness'],
      'selfcare': productData['selfcare'],
      'accessories': productData['accessories'],
    };
  }

  static int? _parseIntId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class CatalogLookupMaps {
  final Map<String, String?> otcpomByNameLower;
  final Map<int, String> urlByProductId;
  final Map<String, String> urlByNameLower;

  const CatalogLookupMaps({
    required this.otcpomByNameLower,
    required this.urlByProductId,
    required this.urlByNameLower,
  });
}
