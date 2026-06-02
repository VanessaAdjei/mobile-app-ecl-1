import 'dart:async';

import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/services/banner_cache_service.dart';
import 'package:eclapp/services/category_optimization_service.dart';
import 'package:eclapp/services/homepage_optimization_service.dart';
import 'package:eclapp/services/product_image_preload_service.dart';
import 'package:flutter/foundation.dart';

/// Warms catalog, images, categories, and banners while onboarding is visible.
class HomePreloadService {
  HomePreloadService._();

  static final CategoryOptimizationService _categories =
      CategoryOptimizationService();
  static final HomepageOptimizationService _homepage =
      HomepageOptimizationService();
  static final BannerCacheService _banners = BannerCacheService();

  static Future<void>? _preloadFuture;
  static bool _preloadComplete = false;

  /// True only when [ProductCache] has the full get-all-products catalog.
  static bool get isCatalogReady => ProductCache.hasProductsInMemory;

  /// True when onboarding preload finished (catalog + home-grid images at minimum).
  static bool get isPreloadComplete => _preloadComplete;

  /// Home can render product rows with cached thumbnails immediately.
  static bool get isFullyReadyForHome =>
      isCatalogReady && ProductImagePreloadService.isHomeGridWarm;

  /// Idempotent — starts as soon as terms or onboarding is shown.
  static void startOnboardingPreload() {
    if (_preloadFuture != null) return;
    debugPrint(
      'HomePreloadService: preload started — catalog, images, categories, banners',
    );
    _preloadFuture = _runOnboardingPreload();
  }

  @Deprecated('Use startOnboardingPreload')
  static void warmInBackground() => startOnboardingPreload();

  static Future<void> _runOnboardingPreload() async {
    try {
      final catalogOk = await ProductCache.ensureCatalogReady(
        maxWait: const Duration(minutes: 3),
      );
      if (!catalogOk) {
        debugPrint('HomePreloadService: onboarding preload — catalog failed');
        return;
      }

      ProductCache.warmPopularFromCatalog();
      publishCatalogToHomeServices();

      // Run in parallel while the user reads onboarding slides.
      await Future.wait([
        _safeStep('popular', ProductCache.ensurePopularReady()),
        _safeStep(
          'home-grid-images',
          ProductImagePreloadService.ensureHomeGridImagesReady(
            catalog: ProductCache.cachedProducts,
            popular: ProductCache.cachedPopularProducts,
            maxWait: const Duration(minutes: 2),
          ),
        ),
        _safeStep(
          'categories',
          ensureCategoriesReady(maxWait: const Duration(minutes: 2)),
        ),
        _safeStep(
          'banners',
          _warmBanners(maxWait: const Duration(seconds: 60)),
        ),
      ]);
    } catch (e, st) {
      debugPrint('HomePreloadService: preload error: $e\n$st');
    } finally {
      _preloadComplete = true;
      debugPrint(
        'HomePreloadService: preload finished — '
        'get-all-products=${ProductCache.cachedProducts.length}, '
        'popular=${ProductCache.cachedPopularProducts.length}, '
        'images=${ProductImagePreloadService.downloadedCount}, '
        'categories=${_categories.cachedCategories.length}, '
        'banners=${_banners.cachedBanners.length}',
      );
    }
  }

  static Future<void> _safeStep(String label, Future<dynamic> step) async {
    try {
      await step;
    } catch (e, st) {
      debugPrint('HomePreloadService: $label preload failed: $e\n$st');
    }
  }

  static Future<void> _warmBanners({
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    await _banners.initialize();
    try {
      await _banners.getBanners().timeout(maxWait);
    } on TimeoutException {
      debugPrint('HomePreloadService: banner API timed out');
    }
    await _banners.warmBannerImagesToDisk(maxWait: maxWait);
  }

  /// Copies [ProductCache] into [HomepageOptimizationService] so home does not re-fetch.
  static void publishCatalogToHomeServices() {
    if (!ProductCache.hasProductsInMemory) return;
    _homepage.seedFromCatalog(
      allProducts: ProductCache.cachedProducts,
      popularProducts: ProductCache.cachedPopularProducts,
    );
  }

  /// Gate for onboarding completion.
  ///
  /// We require catalog data to be ready, while image warming is best-effort.
  /// This avoids blocking "Get Started" when products are available but
  /// thumbnail preloading is still in progress on slower networks/devices.
  static Future<bool> ensureReadyForHome({
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    if (_preloadFuture != null) {
      try {
        await _preloadFuture!.timeout(maxWait);
      } on TimeoutException {
        debugPrint('HomePreloadService: background preload still running');
      }
    } else {
      startOnboardingPreload();
      try {
        await _preloadFuture!.timeout(maxWait);
      } on TimeoutException {
        debugPrint('HomePreloadService: late preload timed out');
      }
    }

    final catalogOk = await ProductCache.ensureCatalogReady(maxWait: maxWait);
    if (!catalogOk) {
      debugPrint(
        'HomePreloadService: BLOCKED — get-all-products not loaded '
        '(${ProductCache.cachedProducts.length} products)',
      );
      return false;
    }

    ProductCache.warmPopularFromCatalog();
    publishCatalogToHomeServices();

    final remaining = maxWait;
    await Future.wait([
      _safeStep(
        'popular-final',
        ProductCache.ensurePopularReady(),
      ),
      _safeStep(
        'home-grid-images-final',
        ProductImagePreloadService.ensureHomeGridImagesReady(
          catalog: ProductCache.cachedProducts,
          popular: ProductCache.cachedPopularProducts,
          maxWait: remaining,
        ),
      ),
      _safeStep(
        'categories-final',
        ensureCategoriesReady(maxWait: remaining),
      ),
      _safeStep(
        'banners-final',
        _warmBanners(maxWait: remaining),
      ),
    ]);

    _preloadComplete = true;

    final imagesWarm = ProductImagePreloadService.isHomeGridWarm;
    debugPrint(
      'HomePreloadService: ready=$catalogOk '
      '(get-all-products=${ProductCache.cachedProducts.length}, '
      'imagesWarm=$imagesWarm, images=${ProductImagePreloadService.downloadedCount}, '
      'categories=${_categories.cachedCategories.length}, '
      'banners=${_banners.cachedBanners.length})',
    );
    return catalogOk;
  }

  static Future<bool> ensureCategoriesReady({
    Duration maxWait = const Duration(seconds: 45),
  }) async {
    await _categories.initialize();
    if (_categories.hasCachedCategories) {
      return true;
    }

    final deadline = DateTime.now().add(maxWait);
    if (!_categories.isLoadingCategories) {
      unawaited(
        _categories.getCategories().catchError((Object e) {
          debugPrint('HomePreloadService: categories error: $e');
          return <dynamic>[];
        }),
      );
    }

    while (DateTime.now().isBefore(deadline)) {
      if (_categories.hasCachedCategories) {
        return true;
      }
      if (!_categories.isLoadingCategories) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (!_categories.hasCachedCategories && !_categories.isLoadingCategories) {
      try {
        await _categories.getCategories();
      } catch (e) {
        debugPrint('HomePreloadService: categories fetch failed: $e');
      }
    }
    return _categories.hasCachedCategories;
  }

  static List<dynamic> get cachedCategories =>
      List<dynamic>.from(_categories.cachedCategories);
}
