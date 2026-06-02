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
  static Future<void>? _homeGridWarmFuture;

  /// Must match [HomeProductCard] / grid [CachedNetworkImage] disk resize.
  static const int homeThumbDiskSize = 300;

  static int get downloadedCount => _downloaded.length;

  static bool get isHomeGridWarm => _lastHomeGridWarmComplete;

  static bool _lastHomeGridWarmComplete = false;

  static String imageUrlFor(Product product) =>
      ApiConfig.getImageOrStorageUrl(product.thumbnail);

  static String diskCacheKeyFor(String url) =>
      'resized_w${homeThumbDiskSize}_h${homeThumbDiskSize}_$url';

  /// URLs for visible home rows (prefer shuffled section lists when provided).
  static List<String> collectHomeGridUrls({
    required List<Product> catalog,
    List<Product> popular = const [],
    List<Product> visibleProducts = const [],
    int perSection = 8,
    int visiblePerSection = 6,
  }) {
    final urls = <String>{};

    if (visibleProducts.isNotEmpty) {
      for (final p in visibleProducts) {
        final u = imageUrlFor(p);
        if (u.isNotEmpty) urls.add(u);
      }
    } else {
      final sections = categorizeProductsForHome(catalog);
      for (final products in sections.values) {
        for (final p in products.take(perSection)) {
          final u = imageUrlFor(p);
          if (u.isNotEmpty) urls.add(u);
        }
      }
    }

    for (final p in popular.take(12)) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }

    return urls.toList();
  }

  /// Ensures visible home-grid thumbnails are on disk before the grid renders.
  static Future<bool> ensureHomeGridImagesReady({
    required List<Product> catalog,
    List<Product> popular = const [],
    List<Product> visibleProducts = const [],
    Duration maxWait = const Duration(seconds: 40),
    int maxConcurrent = 12,
  }) async {
    if (catalog.isEmpty) {
      _lastHomeGridWarmComplete = true;
      return true;
    }

    if (_homeGridWarmFuture != null) {
      try {
        await _homeGridWarmFuture!.timeout(maxWait);
      } on TimeoutException {
        debugPrint('ProductImagePreload: home grid warm still running');
      }
      return _lastHomeGridWarmComplete;
    }

    final urls = collectHomeGridUrls(
      catalog: catalog,
      popular: popular,
      visibleProducts: visibleProducts,
    );
    if (urls.isEmpty) {
      _lastHomeGridWarmComplete = true;
      return true;
    }

    if (await _areUrlsCached(urls)) {
      _lastHomeGridWarmComplete = true;
      debugPrint(
        'ProductImagePreload: home grid already cached (${urls.length} urls)',
      );
      return true;
    }

    _homeGridWarmFuture = _warmUrls(
      urls,
      maxWait: maxWait,
      maxConcurrent: maxConcurrent,
    );
    try {
      await _homeGridWarmFuture!.timeout(maxWait);
    } on TimeoutException {
      debugPrint('ProductImagePreload: home grid warm timed out');
    } finally {
      _homeGridWarmFuture = null;
      _lastHomeGridWarmComplete = await _areUrlsCached(urls);
    }
    return _lastHomeGridWarmComplete;
  }

  /// Cache thumbnails for the first visible home rows.
  static Future<void> warmHomeGridImages({
    required List<Product> catalog,
    List<Product> popular = const [],
    List<Product> visibleProducts = const [],
    Duration maxWait = const Duration(seconds: 35),
    int maxConcurrent = 12,
  }) async {
    final urls = collectHomeGridUrls(
      catalog: catalog,
      popular: popular,
      visibleProducts: visibleProducts,
    );
    await _warmUrls(urls, maxWait: maxWait, maxConcurrent: maxConcurrent);
  }

  static Future<void> _warmUrls(
    List<String> urls, {
    required Duration maxWait,
    required int maxConcurrent,
  }) async {
    if (urls.isEmpty) return;

    debugPrint('ProductImagePreload: warming ${urls.length} home grid images...');
    final deadline = DateTime.now().add(maxWait);
    var index = 0;
    while (index < urls.length && DateTime.now().isBefore(deadline)) {
      final chunk = urls.skip(index).take(maxConcurrent).toList();
      index += chunk.length;
      await Future.wait(chunk.map(_downloadOne));
    }
    debugPrint(
      'ProductImagePreload: ${_downloaded.length} resized thumbnails cached',
    );
  }

  static Future<bool> _areUrlsCached(List<String> urls) async {
    if (urls.isEmpty) return true;
    var cachedCount = 0;
    for (final url in urls) {
      final key = diskCacheKeyFor(url);
      if (_downloaded.contains(key)) {
        cachedCount++;
        continue;
      }
      final cached = await _cache.getFileFromCache(key);
      if (cached != null) {
        _downloaded.add(key);
        cachedCount++;
        continue;
      }
    }
    // Allow home to open if most visible thumbnails are ready.
    return cachedCount >= (urls.length * 0.85).ceil();
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
    final pending = urls
        .where((u) => !_downloaded.contains(diskCacheKeyFor(u)))
        .take(200)
        .toList();
    if (pending.isEmpty) return;
    debugPrint(
      'ProductImagePreload: background — ${pending.length} more images',
    );
    for (var i = 0; i < pending.length; i += 12) {
      final chunk = pending.skip(i).take(12).toList();
      await Future.wait(chunk.map(_downloadOne));
    }
  }

  static Future<void> _downloadOne(String url) async {
    if (url.isEmpty) return;
    final key = diskCacheKeyFor(url);
    if (_downloaded.contains(key)) return;
    try {
      final cached = await _cache.getFileFromCache(key);
      if (cached != null) {
        _downloaded.add(key);
        return;
      }

      await for (final response in _cache.getImageFile(
        url,
        maxWidth: homeThumbDiskSize,
        maxHeight: homeThumbDiskSize,
      )) {
        if (response is FileInfo) {
          _downloaded.add(key);
          break;
        }
      }
    } catch (e) {
      debugPrint('ProductImagePreload: skip $url ($e)');
    }
  }
}
