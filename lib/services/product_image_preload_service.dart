import 'dart:async';

import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Downloads product thumbnails into [DefaultCacheManager] (same as grid cards).
class ProductImagePreloadService {
  ProductImagePreloadService._();

  static final DefaultCacheManager _cache = DefaultCacheManager();
  static final Set<String> _downloaded = {};
  static Future<void>? _gridWarmFuture;

  static int get downloadedCount => _downloaded.length;

  static String imageUrlFor(Product product) =>
      ApiConfig.getImageOrStorageUrl(product.thumbnail);

  /// URLs for the first rows on home (all sections + popular strip).
  static List<String> collectHomeGridUrls({
    required List<Product> catalog,
    List<Product> popular = const [],
    int perSection = 8,
  }) {
    final urls = <String>{};
    final sections = categorizeProductsForHome(catalog);
    for (final products in sections.values) {
      for (final p in products.take(perSection)) {
        final u = imageUrlFor(p);
        if (u.isNotEmpty) urls.add(u);
      }
    }
    for (final p in popular.take(12)) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    return urls.toList();
  }

  /// During onboarding — cache thumbnails before home opens.
  static Future<void> warmHomeGridImages({
    required List<Product> catalog,
    List<Product> popular = const [],
    Duration maxWait = const Duration(seconds: 35),
    int maxConcurrent = 12,
  }) async {
    final urls = collectHomeGridUrls(catalog: catalog, popular: popular);
    if (urls.isEmpty) return;

    debugPrint(
        'ProductImagePreload: warming ${urls.length} home grid images...');
    final deadline = DateTime.now().add(maxWait);
    var index = 0;
    while (index < urls.length && DateTime.now().isBefore(deadline)) {
      final chunk = urls.skip(index).take(maxConcurrent).toList();
      index += chunk.length;
      await Future.wait(chunk.map(_downloadOne));
    }
    debugPrint(
        'ProductImagePreload: ${_downloaded.length} images in disk cache');
  }

  static void warmRemainingInBackground({
    required List<Product> catalog,
    List<Product> popular = const [],
  }) {
    if (_gridWarmFuture != null) return;
    _gridWarmFuture = _warmAll(catalog, popular).whenComplete(() {
      _gridWarmFuture = null;
    });
    unawaited(_gridWarmFuture);
  }

  static Future<void> _warmAll(
    List<Product> catalog,
    List<Product> popular,
  ) async {
    final urls = <String>{};
    for (final p in catalog) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    for (final p in popular) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    final pending =
        urls.where((u) => !_downloaded.contains(u)).take(200).toList();
    if (pending.isEmpty) return;
    debugPrint(
        'ProductImagePreload: background — ${pending.length} more images');
    for (var i = 0; i < pending.length; i += 12) {
      final chunk = pending.skip(i).take(12).toList();
      await Future.wait(chunk.map(_downloadOne));
    }
  }

  static Future<void> _downloadOne(String url) async {
    if (url.isEmpty || _downloaded.contains(url)) return;
    try {
      await _cache.downloadFile(url);
      _downloaded.add(url);
    } catch (e) {
      debugPrint('ProductImagePreload: skip $url ($e)');
    }
  }
}
