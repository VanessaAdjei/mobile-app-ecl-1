import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/category_fetch_result.dart';
import '../models/product_model.dart';
import '../repositories/product_detail_repository.dart';
import '../utils/app_error_utils.dart';
import '../utils/product_detail_parser.dart';
import '../utils/related_products_parser.dart';

/// Product detail + related products use-cases (by url slug).
class ProductDetailService {
  ProductDetailService({ProductDetailRepository? repository})
      : _repository = repository ?? ProductDetailRepositoryImpl();

  final ProductDetailRepository _repository;

  Future<Product> fetchProductDetails(
    String urlName, {
    Iterable<Product> catalogFallback = const [],
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final result = await _repository.fetchProductDetails(
        urlName,
        timeout: timeout,
      );
      _rethrowTransportError(result);

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
    Duration timeout = const Duration(seconds: 10),
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
