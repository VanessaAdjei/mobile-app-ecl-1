import 'dart:async';

import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/services/category_optimization_service.dart';
import 'package:eclapp/services/homepage_optimization_service.dart';
import 'package:eclapp/services/product_image_preload_service.dart';
import 'package:flutter/foundation.dart';

/// Warms **get-all-products** + categories during onboarding; home opens only when ready.
class HomePreloadService {
  HomePreloadService._();

  static final CategoryOptimizationService _categories =
      CategoryOptimizationService();
  static final HomepageOptimizationService _homepage =
      HomepageOptimizationService();

  static Future<void>? _preloadFuture;

  /// True only when [ProductCache] has the full get-all-products catalog.
  static bool get isCatalogReady => ProductCache.hasProductsInMemory;

  /// Idempotent — starts as soon as first launch is known (terms or onboarding).
  static void startOnboardingPreload() {
    if (_preloadFuture != null) return;
    debugPrint(
        'HomePreloadService: preload started — get-all-products + categories');
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
      unawaited(
        ProductImagePreloadService.warmHomeGridImages(
          catalog: ProductCache.cachedProducts,
          popular: ProductCache.cachedPopularProducts,
          maxWait: const Duration(seconds: 40),
        ),
      );
      unawaited(ensureCategoriesReady(maxWait: const Duration(minutes: 3)));
    } catch (e, st) {
      debugPrint('HomePreloadService: preload error: $e\n$st');
    } finally {
      debugPrint(
        'HomePreloadService: preload finished — '
        'get-all-products=${ProductCache.cachedProducts.length}, '
        'popular=${ProductCache.cachedPopularProducts.length}, '
        'images=${ProductImagePreloadService.downloadedCount}, '
        'categories=${_categories.cachedCategories.length}',
      );
    }
  }

  /// Copies [ProductCache] into [HomepageOptimizationService] so home does not re-fetch.
  static void publishCatalogToHomeServices() {
    if (!ProductCache.hasProductsInMemory) return;
    _homepage.seedFromCatalog(
      allProducts: ProductCache.cachedProducts,
      popularProducts: ProductCache.cachedPopularProducts,
    );
  }

  /// **Hard gate:** home must not open until get-all-products catalog is in memory.
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

    unawaited(
      ProductImagePreloadService.warmHomeGridImages(
        catalog: ProductCache.cachedProducts,
        popular: ProductCache.cachedPopularProducts,
        maxWait: const Duration(seconds: 30),
      ),
    );

    unawaited(ensureCategoriesReady(maxWait: const Duration(seconds: 15)));

    debugPrint(
      'HomePreloadService: ready=$catalogOk '
      '(get-all-products=${ProductCache.cachedProducts.length}, '
      'categories=${_categories.cachedCategories.length})',
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
