import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../cache/product_detail_cache.dart';
import '../models/category_fetch_result.dart';
import '../models/product_model.dart';
import '../cache/product_catalog_memory.dart';
import '../repositories/product_detail_repository.dart';
import '../utils/app_error_utils.dart';
import '../utils/product_detail_parser.dart';
import '../utils/related_products_parser.dart';

/// Product detail + related products use-cases (by url slug).
class ProductDetailService {
  ProductDetailService({ProductDetailRepository? repository})
      : _repository = repository ?? ProductDetailRepositoryImpl();

  final ProductDetailRepository _repository;

  static final Map<String, Future<Product>> _warmInFlight = {};

  /// Reuses navigation warm-up fetch when [ItemPage] opens (same in-flight request).
  static Future<Product>? takeWarmFuture(String urlName) {
    return _warmInFlight[urlName];
  }

  /// Starts loading detail API data before navigation finishes (deduped).
  static void warmProductDetails(String urlName) {
    if (urlName.isEmpty || _warmInFlight.containsKey(urlName)) return;

    if (ProductDetailCache.isMemoryFresh(urlName)) {
      final cached = ProductDetailCache.memoryPeek(urlName);
      if (cached != null) {
        final future = Future<Product>.value(cached);
        _warmInFlight[urlName] = future;
        unawaited(future.whenComplete(() => _warmInFlight.remove(urlName)));
        return;
      }
    }

    final service = ProductDetailService();
    final future = service.fetchProductDetails(
      urlName,
      catalogFallback: const [],
      allowCatalogFallback: false,
      timeout: const Duration(seconds: 15),
    );
    _warmInFlight[urlName] = future;
    unawaited(future.whenComplete(() => _warmInFlight.remove(urlName)));
  }

  Product? _productFromCatalog(String urlName, Iterable<Product> catalog) {
    final indexed = ProductCatalogMemory.findByUrlName(urlName);
    if (indexed != null) return indexed;
    for (final product in catalog) {
      if (product.urlName == urlName && product.id != 0) return product;
    }
    return null;
  }

  /// Detail API with memory/disk cache (still API-sourced data, never list preview).
  ///
  /// Fresh memory (within [ProductDetailCache.memoryFreshDuration]): no network.
  /// Stale disk/memory: returns cache immediately, refreshes in background when
  /// [onStaleRefresh] is set.
  Future<Product> fetchProductDetails(
    String urlName, {
    Iterable<Product> catalogFallback = const [],
    Duration timeout = const Duration(seconds: 30),
    bool allowCatalogFallback = true,
    bool forceRefresh = false,
    void Function(Product product)? onStaleRefresh,
  }) async {
    if (urlName.isEmpty) {
      throw Exception('Product not found');
    }

    if (!forceRefresh) {
      final cached = await ProductDetailCache.read(urlName);
      if (cached != null) {
        if (ProductDetailCache.isMemoryFresh(urlName)) {
          if (kDebugMode) {
            debugPrint('item_detail: memory cache hit "$urlName"');
          }
          return cached;
        }

        if (kDebugMode) {
          debugPrint('item_detail: stale cache hit "$urlName" — refreshing');
        }
        unawaited(
          _fetchProductDetailsFromNetwork(
            urlName,
            catalogFallback: catalogFallback,
            timeout: timeout,
            allowCatalogFallback: false,
          ).then((fresh) {
            onStaleRefresh?.call(fresh);
          }).catchError((_) {}),
        );
        return cached;
      }
    } else {
      await ProductDetailCache.invalidate(urlName);
    }

    try {
      return await _fetchProductDetailsFromNetwork(
        urlName,
        catalogFallback: catalogFallback,
        timeout: timeout,
        allowCatalogFallback: allowCatalogFallback,
      );
    } catch (e) {
      if (!forceRefresh && AppErrorUtils.isTransientTransportError(e)) {
        final offline = await ProductDetailCache.read(urlName);
        if (offline != null) {
          if (kDebugMode) {
            debugPrint('item_detail: offline cache fallback "$urlName"');
          }
          return offline;
        }
      }
      rethrow;
    }
  }

  Future<Product> _fetchProductDetailsFromNetwork(
    String urlName, {
    Iterable<Product> catalogFallback = const [],
    Duration timeout = const Duration(seconds: 30),
    bool allowCatalogFallback = true,
  }) async {
    try {
      final result = await _repository.fetchProductDetails(
        urlName,
        timeout: timeout,
      );
      final transportError = result.error;
      if (transportError != null) {
        if (allowCatalogFallback &&
            AppErrorUtils.isTransientTransportError(transportError)) {
          final catalogProduct = _productFromCatalog(urlName, catalogFallback);
          if (catalogProduct != null) {
            if (kDebugMode) {
              debugPrint(
                'item_detail: catalog fallback for "$urlName" after transport error',
              );
            }
            return catalogProduct;
          }
        }
        _rethrowTransportError(result);
      }

      if (result.statusCode == 404) {
        throw Exception('Product not found');
      }
      if (result.statusCode >= 500) {
        throw Exception(AppErrorUtils.oopsTryAgainMessage);
      }
      if (!result.isHttpOk || result.body == null) {
        throw Exception(
          'Failed to load product details: ${result.statusCode}',
        );
      }

      try {
        final product = parseProductDetailResponse(
          result.body!,
          urlName,
          catalogFallback: catalogFallback,
        );
        await ProductDetailCache.put(urlName, product);
        if (kDebugMode) {
          debugPrint(
            'item_detail: loaded "$urlName" → "${product.name}" (${product.price})',
          );
        }
        return product;
      } catch (e) {
        throw Exception('Failed to parse product data: $e');
      }
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your internet connection and try again.',
      );
    } on SocketException {
      throw Exception(
        'No internet connection. Please check your network settings.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not load product: $e');
    }
  }

  Future<List<Product>> fetchRelatedProducts(
    String urlName, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final result = await _repository.fetchRelatedProducts(
        urlName,
        timeout: timeout,
      );
      _rethrowTransportError(result);

      if (result.statusCode == 404 || !result.isHttpOk || result.body == null) {
        return const [];
      }

      return RelatedProductsParser.fromResponseBody(
        result.body!,
        excludeUrlName: urlName,
      );
    } on TimeoutException {
      return const [];
    } on SocketException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
