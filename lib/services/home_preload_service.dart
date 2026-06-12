import 'dart:async';
import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/homepage.dart' show categorizeProductsForHome;
import 'package:eclapp/services/banner_cache_service.dart';
import 'package:eclapp/services/category_optimization_service.dart';
import 'package:eclapp/services/homepage_optimization_service.dart';
import 'package:eclapp/services/product_image_preload_service.dart';
import 'package:eclapp/utils/catalog_timer.dart';
import 'package:eclapp/utils/flutter_test_env.dart';
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
  static Future<void>? _categoryTreePreloadFuture;
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

  static const int _sectionPoolSize = 40;
  static const int _visiblePerSection = 6;

  static List<Product> _preparedWellness = [];
  static List<Product> _preparedSelfcare = [];
  static List<Product> _preparedAccessories = [];
  static List<Product> _preparedPrescribed = [];
  static List<Product> _preparedDrugs = [];
  static bool _homeSectionsPrepared = false;

  static bool get hasPreparedHomeSections => _homeSectionsPrepared;

  static List<Product> _shuffledPool(List<Product> source, {int pool = _sectionPoolSize}) {
    if (source.isEmpty) return [];
    if (source.length <= pool) {
      return List<Product>.from(source)..shuffle();
    }
    final copy = List<Product>.from(source)..shuffle();
    return copy.take(pool).toList();
  }

  /// Same shuffle home will use — avoids cache miss on different random 6.
  static void prepareHomeSectionPools() {
    final catalog = ProductCache.cachedProducts;
    if (catalog.isEmpty) return;
    final sections = categorizeProductsForHome(catalog);
    _preparedWellness = _shuffledPool(sections['wellness']!);
    _preparedSelfcare = _shuffledPool(sections['selfcare']!);
    _preparedAccessories = _shuffledPool(sections['accessories']!);
    _preparedPrescribed = _shuffledPool(sections['prescribed']!);
    _preparedDrugs = _shuffledPool(sections['drugs']!);
    _homeSectionsPrepared = true;
    debugPrint(
      'HomePreloadService: prepared home sections '
      '(wellness=${_preparedWellness.length}, selfcare=${_preparedSelfcare.length}, '
      'accessories=${_preparedAccessories.length})',
    );
  }

  /// The 6 cards per grid section + medication row — pre-warmed before home opens.
  static List<Product> preparedVisibleHomeProducts() {
    if (!_homeSectionsPrepared) prepareHomeSectionPools();
    return [
      ..._preparedDrugs.take(ProductImagePreloadService.homeMedicationVisibleCount),
      ..._preparedWellness.take(_visiblePerSection),
      ..._preparedSelfcare.take(_visiblePerSection),
      ..._preparedAccessories.take(_visiblePerSection),
      ..._preparedPrescribed.take(_visiblePerSection),
    ];
  }

  /// One-shot: returns prepared lists so home does not re-shuffle (images already cached).
  static bool consumePreparedSectionPools({
    required void Function(List<Product> drugs) setDrugs,
    required void Function(List<Product> wellness) setWellness,
    required void Function(List<Product> selfcare) setSelfcare,
    required void Function(List<Product> accessories) setAccessories,
    required void Function(List<Product> prescribed) setPrescribed,
  }) {
    if (!_homeSectionsPrepared) return false;
    setDrugs(List<Product>.from(_preparedDrugs));
    setWellness(List<Product>.from(_preparedWellness));
    setSelfcare(List<Product>.from(_preparedSelfcare));
    setAccessories(List<Product>.from(_preparedAccessories));
    setPrescribed(List<Product>.from(_preparedPrescribed));
    _homeSectionsPrepared = false;
    return true;
  }

  static Future<void> warmPreparedVisibleSectionImages() async {
    final products = preparedVisibleHomeProducts();
    if (products.isEmpty) return;
    await ProductImagePreloadService.warmProductListImages(
      products: products,
      maxWait: const Duration(seconds: 90),
      maxConcurrent: 20,
    );
  }

  /// Before leaving onboarding: full catalog from API + visible section images on disk.
  static Future<bool> ensureOnboardingReadyForHome({
    Duration maxWait = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    if (_preloadFuture == null) startOnboardingPreload();

    var remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero && _deferredPreloadFuture != null) {
      try {
        await _deferredPreloadFuture!.timeout(remaining);
      } on TimeoutException {
        debugPrint('HomePreloadService: onboarding preload timed out');
      }
    } else if (remaining > Duration.zero) {
      await _runDeferredOnboardingPreload().timeout(remaining);
    }

    if (!ProductCache.hasProductsInMemory) return false;
    publishCatalogToHomeServices();

    if (!ProductImagePreloadService.isHomeGridWarm) {
      prepareHomeSectionPools();
      remaining = deadline.difference(DateTime.now());
      if (remaining > Duration.zero) {
        try {
          await warmPreparedVisibleSectionImages().timeout(remaining);
        } on TimeoutException {
          debugPrint('HomePreloadService: section image warm timed out');
        }
      }
    }

    remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      try {
        await ensureCategoriesReady(maxWait: remaining);
      } on TimeoutException {
        debugPrint('HomePreloadService: categories preload timed out');
      }
    }

    remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      try {
        await ensureSubcategoriesReady(maxWait: remaining);
      } on TimeoutException {
        debugPrint('HomePreloadService: subcategories preload timed out');
      }
    }

    remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      try {
        await ensureCategoryImagesReady(maxWait: remaining);
      } on TimeoutException {
        debugPrint('HomePreloadService: category image warm timed out');
      }
    }

    return ProductImagePreloadService.isHomeGridWarm;
  }

  static void startOnboardingPreload() {
    if (isFlutterTest) {
      _preloadComplete = true;
      return;
    }
    unawaited(_prefetchCatalogIfStale());
    _startCategoryTreePreload();
    if (_preloadFuture != null) return;
    debugPrint(
      'HomePreloadService: preload started — priority first, full catalog background',
    );
    _preloadFuture = _runPriorityOnboardingPreload();
  }

  /// Categories + subcategories while the user is on onboarding slides.
  static void _startCategoryTreePreload() {
    if (isFlutterTest) return;
    if (_categoryTreePreloadFuture != null) return;
    _categoryTreePreloadFuture = _runCategoryTreePreload();
    unawaited(_categoryTreePreloadFuture);
  }

  static Future<void> _awaitCategoryTreePreload() async {
    _startCategoryTreePreload();
    await (_categoryTreePreloadFuture ?? Future<void>.value());
  }

  static Future<void> _runCategoryTreePreload() async {
    try {
      final categoriesReady = await ensureCategoriesReady(
        maxWait: const Duration(minutes: 2),
      );
      if (!categoriesReady) return;
      await ensureSubcategoriesReady(maxWait: const Duration(minutes: 2));
      await ensureCategoryImagesReady(maxWait: const Duration(seconds: 60));
    } catch (e, st) {
      debugPrint('HomePreloadService: category tree preload error: $e\n$st');
    }
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
        await _safeStep(
          'priority-images',
          ProductImagePreloadService.warmPriorityHomeImages(
            catalog: catalogForImages,
            maxWait: const Duration(seconds: 10),
            maxConcurrent: 8,
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
      debugPrint(
          'HomePreloadService: catalog fresh — skip onboarding prefetch');
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
      await _safeStep(
        'full-catalog',
        ProductCache.ensureCatalogReady(maxWait: const Duration(minutes: 2)),
      );
      prepareHomeSectionPools();
      await _safeStep(
        'home-section-images',
        warmPreparedVisibleSectionImages(),
      );
      await Future.wait([
        _safeStep('popular', ProductCache.ensurePopularReady()),
        _safeStep(
          'category-tree',
          _awaitCategoryTreePreload(),
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
        'subcategory_groups=${_categories.cachedSubcategoriesByCategoryId.length}, '
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

  static List<String> _collectCategoryImageUrls() {
    final urls = <String>{
      ...ProductImagePreloadService.collectCategoryImageUrls(
        _categories.cachedCategories,
      ),
    };
    for (final subcategories
        in _categories.cachedSubcategoriesByCategoryId.values) {
      urls.addAll(
        ProductImagePreloadService.collectCategoryImageUrls(subcategories),
      );
    }
    return urls.toList();
  }

  static Future<bool> ensureCategoryImagesReady({
    Duration maxWait = const Duration(seconds: 45),
  }) async {
    await _categories.initialize();
    if (!_categories.hasCachedCategories) {
      final categoriesReady = await ensureCategoriesReady(maxWait: maxWait);
      if (!categoriesReady) return false;
    }

    final urls = _collectCategoryImageUrls();
    if (urls.isEmpty) return true;

    try {
      return await ProductImagePreloadService.warmCategoryImageUrls(
        urls: urls,
        maxWait: maxWait,
        maxConcurrent: 10,
      );
    } catch (e) {
      debugPrint('HomePreloadService: category images error: $e');
      return false;
    }
  }

  static Future<bool> ensureSubcategoriesReady({
    Duration maxWait = const Duration(seconds: 45),
  }) async {
    await _categories.initialize();
    if (!_categories.hasCachedCategories) {
      final categoriesReady = await ensureCategoriesReady(maxWait: maxWait);
      if (!categoriesReady) return false;
    }
    if (_categories.hasPrefetchedAllSubcategories) return true;

    final deadline = DateTime.now().add(maxWait);
    if (!_categories.isPrefetchingSubcategories) {
      unawaited(
        _categories.prefetchAllSubcategories(maxWait: maxWait).catchError(
          (Object e) {
            debugPrint('HomePreloadService: subcategories error: $e');
            return false;
          },
        ),
      );
    }

    while (DateTime.now().isBefore(deadline)) {
      if (_categories.hasPrefetchedAllSubcategories) return true;
      if (!_categories.isPrefetchingSubcategories) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (!_categories.hasPrefetchedAllSubcategories &&
        !_categories.isPrefetchingSubcategories) {
      try {
        return await _categories.prefetchAllSubcategories(
          maxWait: deadline.difference(DateTime.now()),
        );
      } catch (e) {
        debugPrint('HomePreloadService: subcategories fetch failed: $e');
      }
    }
    return _categories.hasPrefetchedAllSubcategories;
  }

  static List<dynamic> get cachedCategories =>
      List<dynamic>.from(_categories.cachedCategories);

  static Map<int, List<dynamic>> get cachedSubcategoriesByCategoryId =>
      _categories.cachedSubcategoriesByCategoryId;
}
