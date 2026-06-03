import 'dart:async';

import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/services/banner_cache_service.dart';
import 'package:eclapp/services/category_optimization_service.dart';
import 'package:eclapp/services/homepage_optimization_service.dart';
import 'package:eclapp/services/product_image_preload_service.dart';
import 'package:eclapp/utils/catalog_timer.dart';
import 'package:flutter/foundation.dart';

/// Warms priority catalog first, full catalog in background.
class HomePreloadService {
  HomePreloadService._();

  static final CategoryOptimizationService _categories =
      CategoryOptimizationService();
  static final HomepageOptimizationService _homepage =
      HomepageOptimizationService();
  static final BannerCacheService _banners = BannerCacheService();

  static Future<void>? _preloadFuture;
  static Future<void>? _deferredPreloadFuture;
  static bool _preloadComplete = false;
  static Future<bool>? _ensureReadyForHomeFuture;

  /// Set before navigating home so permission prompts are not blocked on prefs fsync.
  static bool _pendingPermissionsAfterOnboarding = false;

  static void markPermissionsRequestedAfterOnboarding() {
    _pendingPermissionsAfterOnboarding = true;
  }

  /// One-shot signal for HomePage to show OS permission prompts after first paint.
  static bool takePendingPermissionsAfterOnboarding() {
    if (!_pendingPermissionsAfterOnboarding) return false;
    _pendingPermissionsAfterOnboarding = false;
    return true;
  }

  static bool get isCatalogReady => ProductCache.hasProductsInMemory;

  static bool get isPreloadComplete => _preloadComplete;

  static bool get isFullyReadyForHome => ProductCache.hasHomeRenderableCatalog;

  static void startOnboardingPreload() {
    unawaited(_prefetchCatalogIfStale());
    if (_preloadFuture != null) return;
    debugPrint(
      'HomePreloadService: preload started — priority first, full catalog background',
    );
    _preloadFuture = _runPriorityOnboardingPreload();
  }

  @Deprecated('Use startOnboardingPreload')
  static void warmInBackground() => startOnboardingPreload();

  static Future<void> _runPriorityOnboardingPreload() async {
    try {
      if (!ProductCache.hasHomeRenderableCatalog) {
        try {
          await ProductCache.loadFromStorage().timeout(
            const Duration(seconds: 2),
          );
        } on TimeoutException {
          debugPrint('HomePreloadService: disk catalog still loading');
        }
      }

      if (!ProductCache.hasHomeRenderableCatalog) {
        try {
          await ProductCache.ensurePriorityReady(
            maxWait: const Duration(seconds: 10),
          );
        } on TimeoutException {
          debugPrint('HomePreloadService: priority catalog still in flight');
        }
      }

      if (ProductCache.hasHomeRenderableCatalog) {
        publishCatalogToHomeServices();
        final catalogForImages = ProductCache.hasProductsInMemory
            ? ProductCache.cachedProducts
            : ProductCache.cachedPriorityProducts;
        unawaited(
          _safeStep(
            'priority-images',
            ProductImagePreloadService.warmPriorityHomeImages(
              catalog: catalogForImages,
              maxWait: const Duration(seconds: 6),
            ),
          ),
        );
      } else {
        debugPrint('HomePreloadService: no priority/full catalog yet');
      }
    } catch (e, st) {
      debugPrint('HomePreloadService: priority preload error: $e\n$st');
    } finally {
      _preloadComplete = true;
      debugPrint(
        'HomePreloadService: priority preload done — '
        'priority=${ProductCache.cachedPriorityProducts.length}, '
        'full=${ProductCache.cachedProducts.length}',
      );
      _startDeferredOnboardingPreload();
    }
  }

  static Future<void> _prefetchCatalogIfStale() async {
    try {
      await ProductCache.loadFromStorage().timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      debugPrint('HomePreloadService: disk catalog still loading');
    }
    if (!ProductCache.shouldRefreshFromNetwork) {
      debugPrint('HomePreloadService: catalog fresh — skip onboarding prefetch');
      return;
    }
    unawaited(ProductCache.prefetchPriorityFromNetwork());
    unawaited(ProductCache.prefetchFromNetwork());
  }

  static void _startDeferredOnboardingPreload() {
    if (_deferredPreloadFuture != null) return;
    _deferredPreloadFuture = _runDeferredOnboardingPreload();
    unawaited(_deferredPreloadFuture);
  }

  static Future<void> _runDeferredOnboardingPreload() async {
    try {
      await Future.wait([
        _safeStep(
          'full-catalog',
          ProductCache.ensureCatalogReady(
            maxWait: const Duration(minutes: 2),
          ),
        ),
        _safeStep('popular', ProductCache.ensurePopularReady()),
        _safeStep(
          'home-grid-images',
          ProductImagePreloadService.ensureHomeGridImagesReady(
            catalog: ProductCache.cachedProducts,
            popular: ProductCache.cachedPopularProducts,
            maxWait: const Duration(minutes: 2),
            maxConcurrent: 4,
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
      debugPrint('HomePreloadService: deferred preload error: $e\n$st');
    } finally {
      debugPrint(
        'HomePreloadService: deferred preload finished — '
        'full=${ProductCache.cachedProducts.length}, '
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

  static void publishCatalogToHomeServices() {
    if (ProductCache.hasProductsInMemory) {
      _homepage.seedFromCatalog(
        allProducts: ProductCache.cachedProducts,
        popularProducts: ProductCache.cachedPopularProducts,
      );
      return;
    }
    if (ProductCache.hasPriorityProducts) {
      _homepage.seedFromCatalog(
        allProducts: ProductCache.cachedPriorityProducts,
        popularProducts: ProductCache.cachedPopularProducts.isNotEmpty
            ? ProductCache.cachedPopularProducts
            : ProductCache.cachedPriorityProducts,
      );
    }
  }

  static Future<bool> ensureReadyForHome({
    Duration maxWait = const Duration(seconds: 3),
  }) async {
    if (_ensureReadyForHomeFuture != null) {
      return _ensureReadyForHomeFuture!;
    }

    _ensureReadyForHomeFuture = _runEnsureReadyForHome(maxWait);
    try {
      final ok = await _ensureReadyForHomeFuture!;
      CatalogTimer.mark('gate_passed');
      return ok;
    } finally {
      _ensureReadyForHomeFuture = null;
    }
  }

  static Future<bool> _runEnsureReadyForHome(Duration maxWait) async {
    CatalogTimer.mark('ensure_start');

    if (_preloadFuture == null) {
      startOnboardingPreload();
    }

    if (ProductCache.hasProductsInMemory) {
      publishCatalogToHomeServices();
      _startDeferredOnboardingPreload();
      CatalogTimer.mark('gate_passed_immediate');
      return true;
    }

    try {
      await ProductCache.loadFromStorage().timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      debugPrint('HomePreloadService: disk read timed out');
    }

    if (ProductCache.hasProductsInMemory) {
      publishCatalogToHomeServices();
      _startDeferredOnboardingPreload();
      CatalogTimer.mark('gate_passed_immediate');
      return true;
    }

    if (ProductCache.isCatalogLoadInFlight ||
        ProductCache.isPriorityLoadInFlight) {
      _startDeferredOnboardingPreload();
      CatalogTimer.mark('gate_passed_inflight');
      debugPrint(
        'HomePreloadService: catalog in flight — passing gate, skeleton will cover',
      );
      return true;
    }

    unawaited(ProductCache.prefetchFromNetwork());
    const pollInterval = Duration(milliseconds: 300);
    const maxPolls = 10;
    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(pollInterval);
      if (ProductCache.hasProductsInMemory ||
          ProductCache.isCatalogLoadInFlight) {
        _startDeferredOnboardingPreload();
        CatalogTimer.mark('gate_passed_after_poll');
        return true;
      }
    }

    _startDeferredOnboardingPreload();
    CatalogTimer.mark('gate_timeout_pass');
    debugPrint('HomePreloadService: gate timeout — passing anyway');
    return true;
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
