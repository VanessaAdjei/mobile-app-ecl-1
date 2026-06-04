import 'package:flutter/foundation.dart';

import '../cache/product_cache.dart';
import '../cache/product_catalog_memory.dart';
import '../models/category_fetch_result.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../utils/product_catalog_parser.dart';

class _TypeaheadLocalSearch {
  const _TypeaheadLocalSearch(this.catalog, this.query, this.limit);
  final List<Product> catalog;
  final String query;
  final int limit;
}

List<Product> _filterTypeaheadOnIsolate(_TypeaheadLocalSearch msg) {
  return filterProductsForTypeaheadList(
    msg.catalog,
    msg.query,
    limit: msg.limit,
  );
}

/// Homepage / ProductCache catalog use-cases.
class ProductCatalogService {
  ProductCatalogService({ProductRepository? repository})
      : _repository = repository ?? ProductRepositoryImpl();

  final ProductRepository _repository;

  static final Map<String, List<Product>> _typeaheadApiCache = {};
  static const int _typeaheadApiCacheMax = 64;

  /// Fast home subset — [get-home-priority], falling back to [popular-products].
  Future<List<Product>> fetchPriorityProducts({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final priorityResult =
        await _repository.fetchHomePriorityProducts(timeout: timeout);
    _rethrowIfTransportError(priorityResult);
    if (priorityResult.isHttpOk && priorityResult.data.isNotEmpty) {
      return compute(
        productsFromApiDataList,
        List<dynamic>.from(priorityResult.data),
      );
    }

    debugPrint(
      'ProductCatalogService: get-home-priority empty or unavailable '
      '(${priorityResult.statusCode}) — using popular-products',
    );
    return fetchPopularProducts(timeout: timeout);
  }

  /// Fetches and parses the full product catalog (get-all-products).
  Future<List<Product>> fetchCatalogProducts({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final bundle = await fetchCatalogBundle(timeout: timeout);
    return bundle.products;
  }

  /// One HTTP call — parsed [Product]s plus raw `data` rows for category search.
  Future<CatalogParseBundle> fetchCatalogBundle({
    Duration timeout = const Duration(seconds: 50),
  }) async {
    final raw = await _repository.fetchAllProductsRaw(timeout: timeout);
    if (raw.error != null) throw raw.error!;
    if (!raw.isHttpOk) return const CatalogParseBundle([], []);
    return compute(parseCatalogBodyBundle, raw.body);
  }

  /// Fetches and parses popular products.
  Future<List<Product>> fetchPopularProducts({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result = await _repository.fetchPopularProducts(timeout: timeout);
    _rethrowIfTransportError(result);
    if (!result.isHttpOk) return const [];
    final rawCount = result.data.length;
    final parsed = await compute(
      productsFromApiDataList,
      List<dynamic>.from(result.data),
    );
    if (parsed.isEmpty && rawCount > 0) {
      debugPrint(
        'ProductCatalogService: popular-products returned $rawCount rows '
        'but none parsed — check API shape',
      );
    }
    return parsed;
  }

  /// Typeahead suggestions — local catalog when cached, else `/api/search/{query}`.
  Future<List<Product>> searchForTypeahead(
    String query, {
    Duration timeout = const Duration(seconds: 4),
    int limit = 7,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    List<Product>? catalog;
    if (ProductCache.hasProductsInMemory) {
      catalog = ProductCache.cachedProducts;
    } else if (ProductCache.hasPriorityProducts) {
      catalog = ProductCache.cachedPriorityProducts;
    } else if (ProductCatalogMemory.hasProducts) {
      catalog = ProductCatalogMemory.products;
    }

    if (catalog != null && catalog.isNotEmpty) {
      if (catalog.length >= kTypeaheadLocalIsolateThreshold) {
        return compute(
          _filterTypeaheadOnIsolate,
          _TypeaheadLocalSearch(catalog, trimmed, limit),
        );
      }
      return filterProductsForTypeaheadList(catalog, trimmed, limit: limit);
    }

    final cacheKey = trimmed.toLowerCase();
    final cached = _typeaheadApiCache[cacheKey];
    if (cached != null) return cached;

    final result =
        await _repository.searchProducts(trimmed, timeout: timeout);
    _rethrowIfTransportError(result);
    if (!result.isHttpOk) return const [];
    final parsed = productsFromSearchApiList(result.data);
    final capped = parsed.length > limit ? parsed.sublist(0, limit) : parsed;
    if (_typeaheadApiCache.length >= _typeaheadApiCacheMax) {
      _typeaheadApiCache.remove(_typeaheadApiCache.keys.first);
    }
    _typeaheadApiCache[cacheKey] = capped;
    return capped;
  }

  void _rethrowIfTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }

  /// Raw catalog rows from get-all-products (`data` array).
  Future<List<dynamic>> fetchCatalogRawItems({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await _repository.fetchAllProducts(timeout: timeout);
    _rethrowIfTransportError(result);
    if (!result.isHttpOk) {
      throw Exception('Failed to load products');
    }
    return List<dynamic>.from(result.data);
  }
}
