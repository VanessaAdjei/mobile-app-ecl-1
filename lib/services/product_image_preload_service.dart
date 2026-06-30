import 'dart:async';

import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/utils/category_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Downloads product thumbnails into [DefaultCacheManager] (same as grid cards).
class ProductImagePreloadService {
  ProductImagePreloadService._();

  static final DefaultCacheManager _cache = DefaultCacheManager();
  static final Set<String> _downloaded = {};

  /// Same store [CachedNetworkImage] must use so preloads are visible on cards.
  static CacheManager get cacheManager => _cache;
  static Future<void>? _gridWarmFuture;
  static Future<void>? _homeGridWarmFuture;
  static Future<void>? _categoryWarmFuture;

  static bool _lastCategoryImagesWarmComplete = false;

  /// Must match [HomeProductCard] / grid [CachedNetworkImage] disk resize.
  static const int homeThumbDiskSize = 300;

  /// Must match category grid [CachedNetworkImage] disk resize.
  static const int categoryThumbDiskSize = 400;

  /// First medication row images to warm before home paints (grid may show more).
  static const int homeMedicationVisibleCount = 8;

  static int get downloadedCount => _downloaded.length;

  static bool get isHomeGridWarm => _lastHomeGridWarmComplete;

  static bool get isCategoryImagesWarm => _lastCategoryImagesWarmComplete;

  static bool _lastHomeGridWarmComplete = false;

  static String imageUrlFor(Product product) {
    var source = product.thumbnail.trim();
    if (source.isEmpty && product.galleryImages.isNotEmpty) {
      source = product.galleryImages.first.trim();
    }
    return ApiConfig.getImageOrStorageUrl(source);
  }

  /// Disk key used by [ImageCacheManager.getImageFile] when `key` is the image URL.
  static String diskCacheKeyFor(String url) =>
      'resized_w${homeThumbDiskSize}_h${homeThumbDiskSize}_$url';

  static String categoryDiskCacheKeyFor(String url) =>
      'resized_w${categoryThumbDiskSize}_h${categoryThumbDiskSize}_$url';

  static List<String> collectCategoryImageUrls(Iterable<dynamic> rows) {
    final urls = <String>{};
    for (final row in rows) {
      final url = categoryImageUrlFromApi(row);
      if (url.isNotEmpty) urls.add(url);
    }
    return urls.toList();
  }

  /// True when a resized thumbnail is already on disk (see [diskCacheKeyFor]).
  static bool isUrlCached(String url) {
    if (url.isEmpty) return false;
    return _downloaded.contains(diskCacheKeyFor(url));
  }

  /// True when every product in [products] has a resized thumbnail on disk.
  static Future<bool> areProductsCached(List<Product> products) async {
    final urls = <String>[];
    for (final p in products) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    if (urls.isEmpty) return true;
    return _areUrlsCached(urls);
  }

  /// Larger pool pre-cached during onboarding so home shuffle still hits disk cache.
  static const int onboardingGridPoolPerSection = 40;

  static List<Product> onboardingGridWarmProducts(List<Product> catalog) {
    if (catalog.isEmpty) return const [];
    final sections = categorizeProductsForHome(catalog);
    return [
      ...sections['wellness']!.take(onboardingGridPoolPerSection),
      ...sections['selfcare']!.take(onboardingGridPoolPerSection),
      ...sections['accessories']!.take(onboardingGridPoolPerSection),
      ...sections['prescribed']!.take(20),
    ];
  }

  /// Warms thumbnails for the exact [products] shown on home (after section shuffle).
  static Future<int> warmProductListImages({
    required List<Product> products,
    Duration maxWait = const Duration(seconds: 30),
    int maxConcurrent = 18,
  }) async {
    final urls = <String>[];
    for (final p in products) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    if (urls.isEmpty) return 0;

    if (await _areUrlsCached(urls)) {
      _lastHomeGridWarmComplete = true;
      return urls.length;
    }

    _lastHomeGridWarmComplete = false;
    await _warmUrls(
      urls,
      maxWait: maxWait,
      maxConcurrent: maxConcurrent,
    );
    _lastHomeGridWarmComplete = await _areUrlsCached(urls);
    return urls.length;
  }

  /// Warms the exact products shown in the home medication row (after shuffle).
  static Future<void> warmMedicationRowImages({
    required List<Product> products,
    Duration maxWait = const Duration(seconds: 10),
    int maxConcurrent = 8,
  }) async {
    final urls = <String>[];
    for (final p in products.take(homeMedicationVisibleCount)) {
      final u = imageUrlFor(p);
      if (u.isNotEmpty) urls.add(u);
    }
    if (urls.isEmpty) return;
    await _warmUrls(
      urls,
      maxWait: maxWait,
      maxConcurrent: maxConcurrent,
    );
  }

  /// Medication row thumbnails — first OTC slice when row list not built yet.
  static Future<void> warmPriorityHomeImages({
    required List<Product> catalog,
    Duration maxWait = const Duration(seconds: 10),
    int maxConcurrent = 8,
    int medicationVisible = homeMedicationVisibleCount,
  }) async {
    if (catalog.isEmpty) return;
    final sections = categorizeProductsForHome(catalog);
    final drugs = sections['drugs'] ?? const <Product>[];
    await warmMedicationRowImages(
      products: drugs.take(medicationVisible).toList(),
      maxWait: maxWait,
      maxConcurrent: maxConcurrent,
    );
  }

  /// URLs for visible home rows (prefer shuffled section lists when provided).
  static List<String> collectHomeGridUrls({
    required List<Product> catalog,
    List<Product> popular = const [],
    List<Product> visibleProducts = const [],
    int perSection = 5,
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

    for (final p in popular.take(8)) {
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
    int maxConcurrent = 6,
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
  /// Downloads category banners to disk (no [BuildContext] — for onboarding).
  static Future<bool> warmCategoryImageUrls({
    required List<String> urls,
    Duration maxWait = const Duration(seconds: 60),
    int maxConcurrent = 10,
  }) async {
    if (urls.isEmpty) {
      _lastCategoryImagesWarmComplete = true;
      return true;
    }

    if (_categoryWarmFuture != null) {
      try {
        await _categoryWarmFuture!.timeout(maxWait);
      } on TimeoutException {
        debugPrint('ProductImagePreload: category warm still running');
      }
      return _lastCategoryImagesWarmComplete;
    }

    if (await _areCategoryUrlsCached(urls)) {
      _lastCategoryImagesWarmComplete = true;
      debugPrint(
        'ProductImagePreload: ${urls.length} category images already cached',
      );
      return true;
    }

    _categoryWarmFuture = _warmCategoryUrls(
      urls,
      maxWait: maxWait,
      maxConcurrent: maxConcurrent,
    );
    try {
      await _categoryWarmFuture!.timeout(maxWait);
    } on TimeoutException {
      debugPrint('ProductImagePreload: category image warm timed out');
    } finally {
      _categoryWarmFuture = null;
      _lastCategoryImagesWarmComplete = await _areCategoryUrlsCached(urls);
    }
    return _lastCategoryImagesWarmComplete;
  }

  static Future<void> warmHomeGridImages({
    required List<Product> catalog,
    List<Product> popular = const [],
    List<Product> visibleProducts = const [],
    Duration maxWait = const Duration(seconds: 35),
    int maxConcurrent = 6,
  }) async {
    if (visibleProducts.isNotEmpty) {
      await warmProductListImages(
        products: visibleProducts,
        maxWait: maxWait,
        maxConcurrent: maxConcurrent,
      );
      return;
    }

    final urls = collectHomeGridUrls(
      catalog: catalog,
      popular: popular,
      visibleProducts: visibleProducts,
    );
    if (urls.isEmpty) {
      _lastHomeGridWarmComplete = true;
      return;
    }
    try {
      await _warmUrls(urls, maxWait: maxWait, maxConcurrent: maxConcurrent);
    } finally {
      _lastHomeGridWarmComplete = await _areUrlsCached(urls);
    }
  }

  static Future<void> _warmCategoryUrls(
    List<String> urls, {
    required Duration maxWait,
    required int maxConcurrent,
  }) async {
    if (urls.isEmpty) return;

    debugPrint(
      'ProductImagePreload: warming ${urls.length} category images...',
    );
    final deadline = DateTime.now().add(maxWait);
    var index = 0;
    while (index < urls.length && DateTime.now().isBefore(deadline)) {
      final chunk = urls.skip(index).take(maxConcurrent).toList();
      index += chunk.length;
      await Future.wait(
        chunk.map((url) => _downloadCategoryOne(url)),
        eagerError: false,
      );
    }
    debugPrint(
      'ProductImagePreload: category warm finished '
      '(${urls.where(isCategoryUrlCached).length}/${urls.length} cached)',
    );
  }

  static Future<bool> _areCategoryUrlsCached(List<String> urls) async {
    if (urls.isEmpty) return true;
    var cachedCount = 0;
    for (final url in urls) {
      if (await _isCategoryUrlCached(url)) {
        cachedCount++;
      }
    }
    return cachedCount >= (urls.length * 0.85).ceil();
  }

  static bool isCategoryUrlCached(String url) {
    if (url.isEmpty) return false;
    return _downloaded.contains(categoryDiskCacheKeyFor(url));
  }

  static Future<bool> _isCategoryUrlCached(String url) async {
    if (url.isEmpty) return false;
    final key = categoryDiskCacheKeyFor(url);
    if (_downloaded.contains(key)) return true;
    final cached = await _cache.getFileFromCache(key);
    if (cached != null) {
      _downloaded.add(key);
      return true;
    }
    return false;
  }

  static Future<void> _downloadCategoryOne(String url) async {
    if (url.isEmpty) return;
    final key = categoryDiskCacheKeyFor(url);
    if (_downloaded.contains(key)) return;
    try {
      if (await _isCategoryUrlCached(url)) return;

      await for (final response in _cache.getImageFile(
        url,
        key: url,
        maxWidth: categoryThumbDiskSize,
        maxHeight: categoryThumbDiskSize,
      )) {
        if (response is FileInfo) {
          _downloaded.add(key);
          break;
        }
      }
    } catch (e) {
      debugPrint('ProductImagePreload: skip category $url ($e)');
    }
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
      await Future.wait(
        chunk.map((url) => _downloadOne(url)),
        eagerError: false,
      );
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
        .take(60)
        .toList();
    if (pending.isEmpty) return;
    debugPrint(
      'ProductImagePreload: background — ${pending.length} more images',
    );
    for (var i = 0; i < pending.length; i += 4) {
      final chunk = pending.skip(i).take(4).toList();
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
        key: url,
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
