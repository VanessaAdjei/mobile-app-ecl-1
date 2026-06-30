// pages/homepage.dart

import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import 'bottomnav.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eclapp/widgets/home/home_search_bar.dart';
import 'package:eclapp/widgets/home/home_popular_products_featured.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/product_card.dart';
import '../widgets/home_page_tour.dart';
import '../utils/home_tour_gate.dart';
import '../services/home_preload_service.dart';
import '../services/product_image_preload_service.dart';
import '../services/homepage_optimization_service.dart';
import '../widgets/empty_state.dart';
import 'section_products_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_notification_service.dart';

import '../widgets/clearance_sale_banner.dart';
import '../widgets/home/home_promo_banner_carousel.dart';
import '../widgets/home/home_popular_products_strip.dart';
import '../utils/product_tap_guard.dart';
import '../services/category_optimization_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/app_theme_colors.dart';
import '../utils/category_utils.dart';
import '../utils/app_error_utils.dart';
import 'categories.dart';
import '../cache/product_cache.dart';
import '../utils/catalog_timer.dart';

export '../cache/product_cache.dart';

const String prescribedShieldAsset = 'assets/images/prescribed_shield.png';

TextStyle _homePoppins({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
}) {
  return TextStyle(
    fontFamily: 'Poppins',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

class ImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  static void preloadImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty || _preloadedImages.containsKey(imageUrl)) return;
    _preloadedImages[imageUrl] = true;
    precacheImage(
      CachedNetworkImageProvider(
        imageUrl,
        maxWidth: ProductImagePreloadService.homeThumbDiskSize,
        maxHeight: ProductImagePreloadService.homeThumbDiskSize,
      ),
      context,
      onError: (exception, stackTrace) {
        debugPrint(
            'Skipping homepage preload image (may be missing): $imageUrl');
      },
    );
  }

  static void preloadImages(List<String> imageUrls, BuildContext context) {
    for (final imageUrl in imageUrls) {
      preloadImage(imageUrl, context);
    }
  }

  static void clearPreloadedImages() {
    _preloadedImages.clear();
  }

  static bool isPreloaded(String imageUrl) {
    return _preloadedImages.containsKey(imageUrl);
  }

  static void markPreloaded(String imageUrl) {
    if (imageUrl.isNotEmpty) _preloadedImages[imageUrl] = true;
  }
}

// ─── Home section buckets (shared by sync hydrate + background isolate) ─────
Map<String, List<Product>> categorizeProductsForHome(
    List<Product> allProducts) {
  final otcDrug = <Product>[];
  final prescribed = <Product>[];
  final wellness = <Product>[];
  final selfcare = <Product>[];
  final accessories = <Product>[];

  for (final p in allProducts) {
    final otcpom = p.otcpom?.trim().toLowerCase();
    if (otcpom == 'pom') {
      prescribed.add(p);
    } else if (otcpom == 'otc') {
      // Medication is strictly over-the-counter. Anything not explicitly
      // tagged 'otc' (including prescription items tagged only via `drug`)
      // is intentionally excluded so prescription medicines never appear here.
      otcDrug.add(p);
    }
    if (p.wellness?.trim().isNotEmpty == true) wellness.add(p);
    if (p.selfcare?.trim().isNotEmpty == true) selfcare.add(p);
    if (p.accessories?.trim().isNotEmpty == true) accessories.add(p);
  }

  return {
    'drugs': otcDrug,
    'prescribed': prescribed,
    'wellness': wellness,
    'selfcare': selfcare,
    'accessories': accessories,
  };
}

Map<String, List<Product>> _processProductsIsolate(List<Product> allProducts) =>
    categorizeProductsForHome(allProducts);

class ErrorDisplayWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 50, color: theme.muted),
          const SizedBox(height: 16),
          Text('No Internet Connection',
              style: TextStyle(
                  fontSize: 16, color: theme.ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Please check your connection and try again',
              style: TextStyle(fontSize: 14, color: theme.muted)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.blue),
              label: const Text('Retry', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Buffer below the status bar / Dynamic Island when only the search bar is pinned.
const double _kHomeSearchPinnedTopExtra = 2;

/// Grey search placeholder shown while the catalog loads.
class _HomeSearchSkeleton extends StatelessWidget {
  const _HomeSearchSkeleton({required this.isTablet});

  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final radius = isTablet ? 22.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 20 : 14,
        isTablet ? 12 : 8,
        isTablet ? 20 : 14,
        isTablet ? 6 : 4,
      ),
      child: Container(
        height: isTablet ? 44.0 : 40.0,
        decoration: BoxDecoration(
          color: theme.searchBarBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// Green logo row + search in a pinned [SliverAppBar] (header stays visible on scroll).
class _HomeHeaderSearchFlexibleSpace extends StatelessWidget {
  const _HomeHeaderSearchFlexibleSpace({
    required this.toolbarHeight,
    required this.searchExtent,
    required this.isTablet,
    required this.skeleton,
    required this.tourCartKey,
    required this.searchBarKey,
    required this.products,
  });

  final double toolbarHeight;
  final double searchExtent;
  final bool isTablet;
  final bool skeleton;
  final GlobalKey tourCartKey;
  final GlobalKey<HomeSearchBarState> searchBarKey;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final collapsedHeight = top + _kHomeSearchPinnedTopExtra + searchExtent;
    final headerControlExtent = isTablet ? 44.0 : 40.0;
    final logoHeight = isTablet ? 24.0 : 18.0;

    return Material(
      color: AppThemeColors.headerBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showToolbar = constraints.maxHeight > collapsedHeight + 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showToolbar)
                ColoredBox(
                  color: AppThemeColors.headerBackground,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: toolbarHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: isTablet ? 16 : 12),
                            child: SizedBox(
                              height: headerControlExtent,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Image.asset(
                                  'assets/images/png.png',
                                  height: logoHeight,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: headerControlExtent,
                            child: CartIconButton(
                              key: tourCartKey,
                              iconColor: Colors.white,
                              iconSize: isTablet ? 24 : 22,
                              backgroundColor: Colors.transparent,
                              margin: EdgeInsets.only(right: isTablet ? 12 : 8),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: BoxConstraints.tightFor(
                                width: headerControlExtent,
                                height: headerControlExtent,
                              ),
                              splashRadius: headerControlExtent * 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: AppThemeColors.headerBackground,
                  child: SizedBox(height: top + _kHomeSearchPinnedTopExtra),
                ),
              Expanded(
                child: ColoredBox(
                  color: showToolbar
                      ? Theme.of(context).scaffoldBackgroundColor
                      : AppThemeColors.headerBackground,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: searchExtent,
                      child: skeleton
                          ? _HomeSearchSkeleton(isTablet: isTablet)
                          : HomeSearchBar(
                              key: searchBarKey,
                              isTablet: isTablet,
                              catalogProducts: products,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.showBottomNav = true,
    this.tourMenuKey,
    this.tourShopKey,
  });

  /// When false, [MainTabShell] owns the bottom bar (tab state is preserved).
  final bool showBottomNav;

  /// When set (tab shell), these keys are attached on the shell [CustomBottomNav].
  final GlobalKey? tourMenuKey;
  final GlobalKey? tourShopKey;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoadingPopular = true;
  String? _error;
  String? _popularError;

  List<Product> _products = [];
  List<Product> filteredProducts = [];
  List<Product> popularProducts = [];
  static List<Product> _lastKnownProducts = [];
  static List<Product> _lastKnownPopularProducts = [];

  List<Product> drugsSectionProducts = [];
  List<Product> prescribedProducts = [];
  List<Product> wellnessProducts = [];
  List<Product> selfcareProducts = [];
  List<Product> accessoriesProducts = [];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<HomeSearchBarState> _homeSearchBarKey =
      GlobalKey<HomeSearchBarState>();
  final GlobalKey _tourCartKey = GlobalKey();
  final GlobalKey _tourCategoriesKey = GlobalKey();
  final GlobalKey _tourMedicationKey = GlobalKey();
  final GlobalKey _tourPopularKey = GlobalKey();
  final GlobalKey _tourShopKey = GlobalKey();
  final GlobalKey _tourMenuKey = GlobalKey();
  final ProductCatalogService _catalogService = ProductCatalogService();

  GlobalKey get tourMenuKey => widget.tourMenuKey ?? _tourMenuKey;
  GlobalKey get tourShopKey => widget.tourShopKey ?? _tourShopKey;

  /// Kept for scroll listener stability across hot reload (header uses [SliverAppBar]).
  bool _isScrolled = false;

  List<dynamic> _categories = [];
  bool _isLoadingCategories = false;
  bool _hasTriedLoadingCategories = false;

  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();
  final HomepageOptimizationService _optimizationService =
      HomepageOptimizationService();
  final Map<String, bool> _preloadedImages = {};

  /// Set by pull-to-refresh so [loadProducts] skips the intermediate section
  /// seed and lets [_processProducts] produce the single (reshuffled) update.
  /// Consumed once, then reset.
  bool _forceSectionShuffleOnce = false;

  // ─── Cache / load guard ───────────────────────────────────────────────────
  // true after the first successful fetch; never reset except on explicit
  // pull-to-refresh or reloadHomePage().
  bool _hasBeenLoaded = false;
  bool _isPartialCatalog = false;
  bool _isLoadingContent = false;
  bool _isBackgroundRefreshing = false;
  Future<void>? _refreshFuture;
  bool _homeGridImagesReady = false;
  bool _homeWarmStarted = false;
  int _homeImageWarmGeneration = 0;

  /// Categorize on a worker when the catalog is large enough to jank the UI.
  static const int _isolateProcessThreshold = 50;

  /// Grid sections on home show up to this many cards (backing list is uncapped).
  static const int _homeGridSectionVisibleCount = 6;
  bool _spotlightTourScheduled = false;
  bool _isRoutePushInProgress = false;
  bool _hasMarkedHomeHydrated = false;

  @override
  bool get wantKeepAlive => true;

  /// Prevent duplicate route pushes when users tap repeatedly.
  Future<T?> _pushOnce<T>(Route<T> route) async {
    if (!mounted || _isRoutePushInProgress) return null;
    _isRoutePushInProgress = true;
    try {
      return await Navigator.push<T>(context, route);
    } finally {
      if (mounted) {
        _isRoutePushInProgress = false;
      }
    }
  }

  Future<T?> _pushNamedOnce<T extends Object?>(String routeName,
      {Object? arguments}) async {
    if (!mounted || _isRoutePushInProgress) return null;
    _isRoutePushInProgress = true;
    try {
      return await Navigator.pushNamed<T>(
        context,
        routeName,
        arguments: arguments,
      );
    } finally {
      if (mounted) {
        _isRoutePushInProgress = false;
      }
    }
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _hydrateFromProductCacheSync();
    _hydrateCategoriesSync();
    _restoreSnapshotToState();
    if (ProductCache.hasProductsInMemory) {
      _hasBeenLoaded = true;
      _isPartialCatalog = false;
      HomePreloadService.publishCatalogToHomeServices();
      // Sync hydrate already seeded sections — avoid a second reshuffle via setState.
    } else if (ProductCache.hasPriorityProducts) {
      _hydrateFromPriorityProducts();
      _hasBeenLoaded = true;
      _isPartialCatalog = true;
    }
    ProductCache.addCatalogListener(_onProductCacheUpdated);
    ProductCache.addPriorityListener(_onPriorityCacheUpdated);
    _seedOptimizationFromProductCache();
    unawaited(_bootHomeProducts());

    if (ProductCache.hasProductsInMemory || _products.isNotEmpty) {
      _scheduleSpotlightTourDelayed();
    }
    unawaited(HomeTourGate.armIfTourPending());

    if (ProductImagePreloadService.isHomeGridWarm) {
      _homeGridImagesReady = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _products.isEmpty) return;
      unawaited(_precacheVisibleHomeImages());
    });

    if (_categories.isEmpty && HomePreloadService.cachedCategories.isNotEmpty) {
      _hydrateCategoriesSync();
    } else if (_categories.isEmpty) {
      unawaited(_loadCategories());
    }

    _scrollController.addListener(_onHomeScroll);
  }

  void _onHomeScroll() {
    if (!mounted) return;
    final scrolled = _scrollController.offset > 100;
    if (scrolled == _isScrolled) return;
    setState(() => _isScrolled = scrolled);
  }

  /// Categories preloaded during onboarding — apply before first frame.
  void _hydrateCategoriesSync() {
    final cached = HomePreloadService.cachedCategories;
    if (cached.isEmpty) return;
    _categories = List<dynamic>.from(cached);
    _isLoadingCategories = false;
    _hasTriedLoadingCategories = true;
  }

  void _markHomeHydratedOnce() {
    if (_hasMarkedHomeHydrated) return;
    if (_products.isEmpty) return;
    _hasMarkedHomeHydrated = true;
    CatalogTimer.mark('home_hydrated');
  }

  /// Paint home from the fast priority slice while get-all-products finishes.
  void _hydrateFromPriorityProducts() {
    if (!ProductCache.hasPriorityProducts) return;
    if (ProductCache.hasProductsInMemory) return;

    final priorityProducts =
        List<Product>.from(ProductCache.cachedPriorityProducts);
    _products = priorityProducts;
    filteredProducts = List<Product>.from(priorityProducts);
    _applySectionBuckets(priorityProducts);
    _error = null;
    _isPartialCatalog = true;

    final cachedPopular = ProductCache.cachedPopularProducts;
    if (cachedPopular.isNotEmpty) {
      popularProducts = List<Product>.from(cachedPopular);
      _isLoadingPopular = false;
    } else {
      popularProducts = List<Product>.from(priorityProducts);
      _isLoadingPopular = false;
    }

    _markHomeHydratedOnce();
    debugPrint(
      'HomePage: displayed ${priorityProducts.length} priority products (partial catalog)',
    );
  }

  void _onPriorityCacheUpdated() {
    if (!mounted) return;
    if (ProductCache.hasProductsInMemory) return;
    if (_products.isNotEmpty) return;

    setState(() {
      _hydrateFromPriorityProducts();
      _hasBeenLoaded = true;
      _isPartialCatalog = true;
    });
    _scheduleHomeWarmOnce();
    unawaited(_syncPopularFromCache());
  }

  /// Apply preloaded get-all-products catalog before the first frame.
  void _hydrateFromProductCacheSync() {
    if (!ProductCache.hasProductsInMemory) return;
    final cachedAll = List<Product>.from(ProductCache.cachedProducts);
    _products = cachedAll;
    filteredProducts = List<Product>.from(cachedAll);
    _applySectionBuckets(cachedAll);
    _error = null;
    final cachedPopular = ProductCache.cachedPopularProducts;
    ProductCache.warmPopularFromCatalog();
    if (cachedPopular.isNotEmpty) {
      popularProducts = List<Product>.from(cachedPopular);
    } else if (ProductCache.cachedPopularProducts.isNotEmpty) {
      popularProducts = List<Product>.from(ProductCache.cachedPopularProducts);
    }
    _isLoadingPopular = popularProducts.isEmpty;
    _markHomeHydratedOnce();
  }

  /// Shuffles the full catalog bucket for a home section (no pool cap).
  List<Product> _shuffledSectionPool(List<Product> source) {
    if (source.isEmpty) return [];
    return List<Product>.from(source)..shuffle();
  }

  bool _tryApplyPreparedSectionPools() {
    return HomePreloadService.consumePreparedSectionPools(
      setDrugs: (list) => drugsSectionProducts = list,
      setWellness: (list) => wellnessProducts = list,
      setSelfcare: (list) => selfcareProducts = list,
      setAccessories: (list) => accessoriesProducts = list,
      setPrescribed: (list) => prescribedProducts = list,
    );
  }

  void _applySectionBuckets(List<Product> allProducts) {
    if (_tryApplyPreparedSectionPools()) return;
    final sections = categorizeProductsForHome(allProducts);
    drugsSectionProducts = _shuffledSectionPool(sections['drugs']!);
    prescribedProducts = _shuffledSectionPool(sections['prescribed']!);
    wellnessProducts = _shuffledSectionPool(sections['wellness']!);
    selfcareProducts = _shuffledSectionPool(sections['selfcare']!);
    accessoriesProducts = _shuffledSectionPool(sections['accessories']!);
  }

  bool _sectionPoolUnderfilled(List<Product> section) =>
      section.length < _homeGridSectionVisibleCount;

  bool _nonDrugSectionsNeedMoreProducts() =>
      _sectionPoolUnderfilled(wellnessProducts) ||
      _sectionPoolUnderfilled(selfcareProducts) ||
      _sectionPoolUnderfilled(accessoriesProducts) ||
      _sectionPoolUnderfilled(prescribedProducts);

  /// After priority preload, top up section pools from the full catalog.
  /// Refills when a section has fewer than [_homeGridSectionVisibleCount] items
  /// (priority slice often leaves 1–3 per bucket).
  void _fillNonDrugSectionsFromCatalog(
    List<Product> allProducts, {
    Map<String, List<Product>>? sections,
  }) {
    if (!_nonDrugSectionsNeedMoreProducts()) return;
    final buckets = sections ?? categorizeProductsForHome(allProducts);
    if (_sectionPoolUnderfilled(wellnessProducts) &&
        buckets['wellness']!.isNotEmpty) {
      wellnessProducts = _shuffledSectionPool(buckets['wellness']!);
    }
    if (_sectionPoolUnderfilled(selfcareProducts) &&
        buckets['selfcare']!.isNotEmpty) {
      selfcareProducts = _shuffledSectionPool(buckets['selfcare']!);
    }
    if (_sectionPoolUnderfilled(accessoriesProducts) &&
        buckets['accessories']!.isNotEmpty) {
      accessoriesProducts = _shuffledSectionPool(buckets['accessories']!);
    }
    final prescribedBucket = buckets['prescribed']!;
    if (prescribedBucket.isNotEmpty &&
        prescribedBucket.length > prescribedProducts.length) {
      prescribedProducts = _shuffledSectionPool(prescribedBucket);
    }
  }

  void _topUpMedicationSectionFromCatalog(List<Product> allProducts) {
    final minCount = ProductImagePreloadService.homeMedicationVisibleCount;
    if (drugsSectionProducts.length >= minCount) return;
    final drugs = categorizeProductsForHome(allProducts)['drugs']!;
    if (drugs.isEmpty) return;
    drugsSectionProducts = _shuffledSectionPool(drugs);
  }

  void _onProductCacheUpdated() {
    if (!mounted) return;
    CatalogTimer.mark('listener_fired');

    if (!ProductCache.hasProductsInMemory) return;

    // Full catalog finished loading after priority slice — expand backing list only.
    if (_isPartialCatalog && _products.isNotEmpty) {
      _upgradeToFullCatalogPreservingSections();
      _scheduleHomeWarmOnce();
      _scheduleSpotlightTourDelayed();
      CatalogTimer.summaryOnce();
      return;
    }

    if (_products.isNotEmpty &&
        _products.length == ProductCache.catalogProductCount) {
      return;
    }

    _applyCacheToState(reshuffleSections: _products.isEmpty);
    if (_products.isNotEmpty) {
      if (!_hasBeenLoaded) _hasBeenLoaded = true;
      _scheduleHomeWarmOnce();
      _scheduleSpotlightTourDelayed();
      CatalogTimer.summaryOnce();
    }
  }

  /// Keeps visible medication/popular rows stable when get-all-products completes.
  void _upgradeToFullCatalogPreservingSections() {
    final cachedAll = ProductCache.cachedProducts;
    final cachedPopular = ProductCache.cachedPopularProducts;
    if (cachedAll.isEmpty) return;

    _seedOptimizationFromProductCache();
    setState(() {
      _products = List<Product>.from(cachedAll);
      filteredProducts = List<Product>.from(cachedAll);
      _topUpMedicationSectionFromCatalog(cachedAll);
      _fillNonDrugSectionsFromCatalog(cachedAll);
      _isPartialCatalog = false;
      _hasBeenLoaded = true;
      _error = null;
      if (cachedPopular.isNotEmpty) {
        popularProducts = List<Product>.from(cachedPopular);
        _isLoadingPopular = false;
      }
    });
    _markHomeHydratedOnce();
    _persistSnapshot();
    _warmGridSectionImages();
  }

  /// Instantly populate state from whatever is already in ProductCache.
  /// If cache is warm the user sees content immediately with no skeleton.
  void _restoreSnapshotToState() {
    if (_lastKnownProducts.isEmpty && _lastKnownPopularProducts.isEmpty) return;
    setState(() {
      if (_products.isEmpty && _lastKnownProducts.isNotEmpty) {
        _products = List<Product>.from(_lastKnownProducts);
        filteredProducts = List<Product>.from(_lastKnownProducts);
        _seedSectionsFromProducts(_products);
      }
      if (popularProducts.isEmpty && _lastKnownPopularProducts.isNotEmpty) {
        popularProducts = List<Product>.from(_lastKnownPopularProducts);
        _isLoadingPopular = false;
      }
    });
  }

  void _persistSnapshot() {
    if (_products.isNotEmpty) {
      _lastKnownProducts = List<Product>.from(_products);
    }
    if (popularProducts.isNotEmpty) {
      _lastKnownPopularProducts = List<Product>.from(popularProducts);
    }
  }

  void _seedSectionsFromProducts(List<Product> allProducts) {
    _applySectionBuckets(allProducts);
  }

  void _seedOptimizationFromProductCache() {
    if (ProductCache.hasProductsInMemory) {
      _optimizationService.seedFromCatalog(
        allProducts: ProductCache.cachedProducts,
        popularProducts: ProductCache.cachedPopularProducts,
      );
      return;
    }
    if (ProductCache.hasPriorityProducts) {
      _optimizationService.seedFromCatalog(
        allProducts: ProductCache.cachedPriorityProducts,
        popularProducts: ProductCache.cachedPopularProducts.isNotEmpty
            ? ProductCache.cachedPopularProducts
            : ProductCache.cachedPriorityProducts,
      );
    }
  }

  void _applyCacheToState({bool reshuffleSections = true}) {
    final cachedAll = ProductCache.cachedProducts;
    final cachedPopular = ProductCache.cachedPopularProducts;
    _seedOptimizationFromProductCache();

    final shouldShuffle = reshuffleSections &&
        (drugsSectionProducts.isEmpty || _forceSectionShuffleOnce);
    final shouldFillOthers = !shouldShuffle &&
        cachedAll.isNotEmpty &&
        (_nonDrugSectionsNeedMoreProducts() ||
            drugsSectionProducts.length <
                ProductImagePreloadService.homeMedicationVisibleCount);

    setState(() {
      if (cachedAll.isNotEmpty) {
        _products = List<Product>.from(cachedAll);
        filteredProducts = List<Product>.from(cachedAll);
        if (shouldShuffle) {
          _applySectionBuckets(_products);
        } else if (shouldFillOthers) {
          _topUpMedicationSectionFromCatalog(_products);
          _fillNonDrugSectionsFromCatalog(_products);
        }
        _isPartialCatalog = false;
        _hasBeenLoaded = true;
      } else if (_products.isEmpty && ProductCache.hasPriorityProducts) {
        _hydrateFromPriorityProducts();
        _hasBeenLoaded = true;
      } else if (_products.isEmpty) {
      }

      if (cachedPopular.isNotEmpty) {
        popularProducts = List<Product>.from(cachedPopular);
        _isLoadingPopular = false;
      } else if (_products.isNotEmpty) {
        _isLoadingPopular = popularProducts.isEmpty;
      }

      _error = null;
    });
    if (cachedAll.isNotEmpty || _products.isNotEmpty) {
      _markHomeHydratedOnce();
    }
    _persistSnapshot();
    if (shouldFillOthers || shouldShuffle) {
      _warmGridSectionImages();
    }
  }

  void _scheduleHomeWarmOnce() {
    if (_homeWarmStarted) return;
    _homeWarmStarted = true;
    unawaited(_warmMedicationRowThenRest());
  }

  /// Network only when preloaded catalog was not applied.
  Future<void> _bootHomeProducts() async {
    if (_hasBeenLoaded && _products.isNotEmpty) {
      _scheduleSpotlightTourDelayed();
      _startHomeContentAfterCatalog();
      _schedulePostInitHomeWork();
      return;
    }

    if (!ProductCache.hasProductsInMemory) {
      try {
        await ProductCache.loadFromStorage().timeout(
          const Duration(milliseconds: 1200),
        );
      } on TimeoutException {
        debugPrint('HomePage: disk catalog read still in progress');
      }
    }
    if (!mounted) return;

    ProductCache.warmPopularFromCatalog();

    if (ProductCache.hasProductsInMemory) {
      HomePreloadService.publishCatalogToHomeServices();
      if (_products.isEmpty) {
        _applyCacheToState(reshuffleSections: true);
      }
      _hasBeenLoaded = true;
      _startHomeContentAfterCatalog();
      if (ProductCache.shouldRefreshFromNetwork) {
        unawaited(_refreshCatalogInBackground());
      }
      return;
    }

    if (ProductCache.hasPriorityProducts && _products.isEmpty) {
      if (mounted) {
        setState(() {
          _hydrateFromPriorityProducts();
          _hasBeenLoaded = true;
          _isPartialCatalog = true;
        });
      }
      _scheduleHomeWarmOnce();
      unawaited(_syncPopularFromCache());
    }

    if (ProductCache.shouldRefreshFromNetwork) {
      unawaited(ProductCache.prefetchFromNetwork());
    }
    if (ProductCache.isCatalogLoadInFlight) {
      _schedulePostInitHomeWork();
      return;
    }

    final ready = await ProductCache.ensureCatalogReady(
      maxWait: const Duration(seconds: 3),
    );
    if (!mounted) return;

    if (ready && ProductCache.hasProductsInMemory) {
      ProductCache.warmPopularFromCatalog();
      HomePreloadService.publishCatalogToHomeServices();
      if (_isPartialCatalog) {
        _upgradeToFullCatalogPreservingSections();
      } else if (_products.isEmpty) {
        _applyCacheToState(reshuffleSections: true);
      }
      _hasBeenLoaded = true;
      _startHomeContentAfterCatalog();
      return;
    }

    unawaited(_optimizationService.initialize());
    await _loadAllContent();
  }

  /// Paint all sections immediately; warm images and popular in background.
  void _startHomeContentAfterCatalog() {
    ProductCache.warmPopularFromCatalog();
    final warmedPopular = ProductCache.cachedPopularProducts;
    if (warmedPopular.isNotEmpty &&
        mounted &&
        (popularProducts.isEmpty ||
            popularProducts.length != warmedPopular.length)) {
      setState(() {
        popularProducts = List<Product>.from(warmedPopular);
        _isLoadingPopular = false;
      });
    }
    _scheduleHomeWarmOnce();
    _schedulePostInitHomeWork();
    unawaited(_syncPopularFromCache());
    _scheduleSpotlightTourDelayed();
  }

  /// Ensures the 8 medication cards on home have disk-cached thumbnails.
  Future<void> _ensureMedicationRowImagesReady() async {
    if (_products.isEmpty || !mounted) return;
    if (drugsSectionProducts.isEmpty) {
      _applySectionBuckets(_products);
    }
    final row = drugsSectionProducts
        .take(ProductImagePreloadService.homeMedicationVisibleCount)
        .toList();
    if (row.isNotEmpty) {
      await ProductImagePreloadService.warmMedicationRowImages(
        products: row,
        maxWait: const Duration(seconds: 10),
        maxConcurrent: 8,
      );
    } else {
      await ProductImagePreloadService.warmPriorityHomeImages(
        catalog: _products,
        maxWait: const Duration(seconds: 10),
        maxConcurrent: 8,
      );
    }
  }

  List<Product> _gridSectionProductsForImageWarm() => [
        ...wellnessProducts.take(_homeGridSectionVisibleCount),
        ...selfcareProducts.take(_homeGridSectionVisibleCount),
        ...accessoriesProducts.take(_homeGridSectionVisibleCount),
        ...prescribedProducts.take(_homeGridSectionVisibleCount),
      ];

  Future<void> _warmMedicationRowThenRest() async {
    final gridProducts = _gridSectionProductsForImageWarm();
    if (ProductImagePreloadService.isHomeGridWarm &&
        gridProducts.isNotEmpty &&
        await ProductImagePreloadService.areProductsCached(gridProducts)) {
      if (mounted) {
        await _precacheVisibleHomeImages();
        setState(() {
          _homeGridImagesReady = true;
          _homeImageWarmGeneration++;
        });
      }
      final popularSlice = popularProducts.take(8).toList();
      if (popularSlice.isNotEmpty && mounted) {
        unawaited(_preloadImages(popularSlice));
      }
      return;
    }

    await Future.wait([
      _ensureMedicationRowImagesReady(),
      _warmGridSectionsAwaitable(),
    ]);
    if (mounted) {
      setState(() {
        _homeGridImagesReady = true;
        _homeImageWarmGeneration++;
      });
    }
    final popularSlice = popularProducts.take(8).toList();
    if (popularSlice.isNotEmpty) {
      await ProductImagePreloadService.warmProductListImages(
        products: popularSlice,
        maxWait: const Duration(seconds: 12),
        maxConcurrent: 8,
      );
      if (mounted) unawaited(_preloadImages(popularSlice));
    }
  }

  Future<void> _warmGridSectionsAwaitable() async {
    if (_products.isEmpty || !mounted) return;
    final gridProducts = _gridSectionProductsForImageWarm();
    if (gridProducts.isEmpty) return;
    if (await ProductImagePreloadService.areProductsCached(gridProducts)) {
      if (mounted) await _precacheVisibleHomeImages();
      return;
    }
    await ProductImagePreloadService.warmProductListImages(
      products: gridProducts,
      maxWait: const Duration(seconds: 20),
      maxConcurrent: 18,
    );
    if (mounted) await _precacheVisibleHomeImages();
  }

  /// Warms thumbnails for the exact products in each visible home section row.
  Future<void> _startHomeImageWarm() async {
    if (_products.isEmpty || !mounted) return;
    await _warmMedicationRowThenRest();
  }

  void _scheduleSpotlightTourDelayed() {
    unawaited(HomeTourGate.armIfTourPending());
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _scheduleSpotlightTour();
    });
  }

  SliverAppBar _buildHomeAppBarWithSearch(
    bool isTablet, {
    bool skeleton = false,
  }) {
    final toolbarHeight = isTablet ? 68.0 : 52.0;
    final searchExtent = HomeSearchBar.headerExtent(isTablet: isTablet);
    final top = MediaQuery.viewPaddingOf(context).top;
    final expandedHeight = top + toolbarHeight + searchExtent;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      primary: false,
      backgroundColor: AppThemeColors.headerBackground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      pinned: true,
      floating: false,
      stretch: false,
      expandedHeight: expandedHeight,
      // Match expanded height so logo + cart row never collapse away on scroll.
      collapsedHeight: expandedHeight,
      toolbarHeight: 0,
      flexibleSpace: _HomeHeaderSearchFlexibleSpace(
        toolbarHeight: toolbarHeight,
        searchExtent: searchExtent,
        isTablet: isTablet,
        skeleton: skeleton,
        tourCartKey: _tourCartKey,
        searchBarKey: _homeSearchBarKey,
        products: _products,
      ),
    );
  }

  List<Widget> _buildHomeTopSlivers(
    bool isTablet, {
    bool searchSkeleton = false,
  }) =>
      [
        _buildHomeAppBarWithSearch(isTablet, skeleton: searchSkeleton),
      ];

  List<Product> _visibleHomeProductsForImageWarm() {
    return [
      ...drugsSectionProducts
          .take(ProductImagePreloadService.homeMedicationVisibleCount),
      ...prescribedProducts.take(_homeGridSectionVisibleCount),
      ...wellnessProducts.take(_homeGridSectionVisibleCount),
      ...selfcareProducts.take(_homeGridSectionVisibleCount),
      ...accessoriesProducts.take(_homeGridSectionVisibleCount),
      ...popularProducts.take(12),
    ];
  }

  /// Wellness / Selfcare / Accessories — warm exact row products (await if not done yet).
  void _warmGridSectionImages() {
    if (!mounted || _products.isEmpty) return;
    if (_homeGridImagesReady) return;
    unawaited(() async {
      await _warmGridSectionsAwaitable();
      if (!mounted) return;
      setState(() {
        _homeGridImagesReady = true;
        _homeImageWarmGeneration++;
      });
    }());
  }

  Future<void> _ensureHomeGridImages() async {
    await _startHomeImageWarm();
  }

  Future<void> _syncPopularFromCache() async {
    if (!mounted) return;
    if (popularProducts.isNotEmpty &&
        ProductCache.cachedPopularProducts.isNotEmpty &&
        popularProducts.length == ProductCache.cachedPopularProducts.length) {
      return;
    }
    ProductCache.warmPopularFromCatalog();
    var cached = ProductCache.cachedPopularProducts;
    if (cached.isEmpty) {
      try {
        await ProductCache.ensurePopularReady().timeout(
          const Duration(seconds: 15),
        );
      } on TimeoutException {
        ProductCache.warmPopularFromCatalog();
      }
      cached = ProductCache.cachedPopularProducts;
    }
    if (!mounted || cached.isEmpty) return;
    setState(() {
      popularProducts = List<Product>.from(cached);
      _isLoadingPopular = false;
      _popularError = null;
    });
    _persistSnapshot();
  }

  Future<void> _refreshCatalogInBackground() async {
    if (!mounted || !ProductCache.shouldRefreshFromNetwork) return;
    if (_isBackgroundRefreshing || ProductCache.isCatalogLoadInFlight) return;
    _isBackgroundRefreshing = true;
    if (mounted) setState(() {});
    try {
      await ProductCache.prefetchFromNetwork();
      if (!mounted) return;
      _applyCacheToState(reshuffleSections: false);
    } finally {
      if (mounted) {
        setState(() => _isBackgroundRefreshing = false);
      } else {
        _isBackgroundRefreshing = false;
      }
    }
  }

  void _scheduleSpotlightTour() {
    if (_spotlightTourScheduled) return;
    if (_products.isEmpty) return;
    _spotlightTourScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runSpotlightTourWithRetry());
      });
    });
  }

  /// Context-dependent work (precacheImage, sheets) must run after [initState].
  void _schedulePostInitHomeWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProductImagePreloadService.warmRemainingInBackground(
        catalog: ProductCache.cachedProducts,
        popular: ProductCache.cachedPopularProducts,
      );
      // OS prompts after home paints — never block hydration or first frame.
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 800),
          _requestPermissionsBackground,
        ),
      );
    });
  }

  /// OS notification + location prompts only (no in-app sheet/dialog first).
  Future<void> _requestPermissionsBackground() async {
    if (!mounted) return;

    final pendingFromOnboarding =
        HomePreloadService.takePendingPermissionsAfterOnboarding();

    final prefs = await SharedPreferences.getInstance();
    final afterOnboarding = pendingFromOnboarding ||
        (prefs.getBool('request_permissions_after_onboarding') ?? false);

    if (afterOnboarding) {
      unawaited(prefs.setBool('request_permissions_after_onboarding', false));
    }

    try {
      if (!await NativeNotificationService.areNotificationsEnabled()) {
        if (!mounted) return;
        final granted =
            await NativeNotificationService.requestNotificationPermissionDirect(
          context: context,
        );
        if (granted) {
          unawaited(prefs.setBool('notification_prompt_attempted', true));
          unawaited(NativeNotificationService.setPushNotificationsOptIn(true));
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      if (!mounted) return;
      if (!await NativeNotificationService.isLocationWhenInUseGranted()) {
        if (!mounted) return;
        await NativeNotificationService.requestLocationWhenInUseDirect(
          context: context,
        );
      }
    } on TimeoutException {
      debugPrint('HomePage: permission prompts timed out');
    } catch (e, st) {
      debugPrint('HomePage: permission prompts error: $e\n$st');
    }
  }

  /// Brief layout settle after onboarding before coach marks.
  Future<void> _waitForFirstHomeUiReady() async {
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _runSpotlightTourWithRetry() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final justFinished = prefs.getBool('just_finished_onboarding') ?? false;
    final forceTour =
        justFinished || !(prefs.getBool('has_seen_smart_tips') ?? false);

    if (forceTour) HomeTourGate.arm();

    try {
      if (justFinished) {
        await _waitForFirstHomeUiReady();
        if (!mounted) return;
      }

      final maxAttempts = justFinished ? 16 : 12;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!mounted) return;
        if (_products.isEmpty) {
          await Future<void>.delayed(
            Duration(milliseconds: justFinished ? 80 : 350 * (attempt + 1)),
          );
          if (!mounted) return;
          continue;
        }
        if (attempt > 0) {
          await Future<void>.delayed(
            Duration(milliseconds: justFinished ? 120 : 400 * attempt),
          );
          if (!mounted) return;
        }
        final shown = await HomePageTour.maybeStart(
          context: context,
          targets: HomePageTourTargets(
            searchKey: _homeSearchBarKey,
            cartKey: _tourCartKey,
            categoriesKey: _tourCategoriesKey,
            menuKey: tourMenuKey,
            shopKey: tourShopKey,
            medicationKey: _tourMedicationKey,
            popularKey: _tourPopularKey,
          ),
          scrollController: _scrollController,
          force: forceTour && attempt == 0,
        );
        if (!mounted) return;
        if (shown) {
          if (justFinished) {
            await prefs.setBool('just_finished_onboarding', false);
          }
          return;
        }
      }
      debugPrint('HomePageTour: not shown after retries');
    } finally {
      if (!(prefs.getBool('has_seen_smart_tips') ?? false)) {
        HomeTourGate.release();
      }
    }
  }

  // ─── Content loading ──────────────────────────────────────────────────────

  /// Main entry point for fetching data.
  /// Only runs once unless explicitly reset via refresh or reloadHomePage().
  Future<void> _loadAllContent() async {
    if (!mounted || _isLoadingContent) return;
    // If already loaded, do nothing — cache stays until user reloads.
    if (_hasBeenLoaded) return;

    _isLoadingContent = true;

    try {
      if (!ProductCache.hasProductsInMemory) {
        final catalogWait = ProductCache.isCatalogLoadInFlight
            ? const Duration(seconds: 90)
            : const Duration(seconds: 30);
        final ready =
            await ProductCache.ensureCatalogReady(maxWait: catalogWait);
        if (!mounted) return;
        if (ready && ProductCache.hasProductsInMemory) {
          _applyCacheToState();
          _hasBeenLoaded = true;
          await _processProducts(_products);
          _scheduleSpotlightTour();
          unawaited(_ensureHomeGridImages());
          if (mounted) {
            setState(() {
              _isLoadingPopular = popularProducts.isEmpty;
            });
            _schedulePostInitHomeWork();
          }
          if (ProductCache.shouldRefreshFromNetwork) {
            unawaited(_refreshCatalogInBackground());
          }
          return;
        }
      }

      if (ProductCache.hasProductsInMemory) {
        _applyCacheToState();
        _hasBeenLoaded = true;
        await _processProducts(_products);
        _scheduleSpotlightTour();
        unawaited(_ensureHomeGridImages());
        if (mounted) {
          setState(() {
            _isLoadingPopular = popularProducts.isEmpty;
          });
          _schedulePostInitHomeWork();
        }
        if (ProductCache.shouldRefreshFromNetwork) {
          unawaited(_refreshCatalogInBackground());
        }
        return;
      }

      await Future.wait([
        loadProducts(),
        _fetchPopularProducts(),
      ]);

      await _processProducts(_products);
      _scheduleSpotlightTour();
      unawaited(_ensureHomeGridImages());
      _hasBeenLoaded = true;
    } catch (e) {
      debugPrint('HomePage: Exception in _loadAllContent: $e');
      if (mounted) setState(() => _error = 'Failed to load content');
    } finally {
      _isLoadingContent = false;
      if (mounted)       if (mounted) {
        _schedulePostInitHomeWork();
        _scheduleSpotlightTour();
      }
    }
  }

  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh &&
        ProductCache.hasProductsInMemory &&
        ProductCache.isCacheValid) {
      final cached = ProductCache.cachedProducts;
      if (mounted) {
        setState(() {
          _products = cached;
          filteredProducts = cached;
          _seedSectionsFromProducts(cached);
          _error = null;
        });
        _persistSnapshot();
      }
      unawaited(_processProducts(cached));
      return;
    }

    if (forceRefresh &&
        ProductCache.hasProductsInMemory &&
        ProductCache.isCacheValid) {
      final cached = ProductCache.cachedProducts;
      if (mounted) {
        setState(() {
          _products = List<Product>.from(cached);
          filteredProducts = List<Product>.from(cached);
          _error = null;
        });
        _persistSnapshot();
      }
      await _processProducts(cached);
      return;
    }

    try {
      if (mounted) setState(() => _error = null);

      await ProductCache.prefetchFromNetwork(forceRefresh: forceRefresh);

      if (ProductCache.hasProductsInMemory) {
        final allProducts = ProductCache.cachedProducts;
        _preloadImages(allProducts.take(8).toList());

        final reshufflePending = _forceSectionShuffleOnce;
        if (mounted) {
          setState(() {
            _products = List<Product>.from(allProducts);
            filteredProducts = List<Product>.from(allProducts);
            if (!reshufflePending) {
              _seedSectionsFromProducts(allProducts);
            }
          });
          _persistSnapshot();
        }

        unawaited(_processProducts(allProducts));
      } else {
        _fallbackToCache();
      }
    } on TimeoutException {
      _fallbackToCache(error: 'Connection timed out');
    } catch (e) {
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Connection failed') ||
          s.contains('No internet') ||
          s.contains('TimeoutException');
      _fallbackToCache(error: isConnectivity ? null : 'Error loading products');
    }
  }

  void _fallbackToCache({String? error}) {
    final cached = ProductCache.cachedProducts;
    if (cached.isNotEmpty) {
      _preloadImages(cached.take(8).toList());
      if (mounted) {
        setState(() {
          _products = cached;
          filteredProducts = cached;
          _seedSectionsFromProducts(cached);
          _error = null;
        });
        _persistSnapshot();
      }
      unawaited(_processProducts(cached));
    } else if (mounted) {
      // No cache to fall back to: always surface an error+retry view so a cold
      // offline start can't hang on an infinite spinner.
      setState(() {
        _error = error ?? 'No internet connection';
      });
    }
  }

  /// Re-buckets products; large catalogs always categorize on a worker isolate.
  Future<void> _processProducts(List<Product> allProducts) async {
    if (!mounted) return;

    if (!_forceSectionShuffleOnce && drugsSectionProducts.isNotEmpty) {
      final medicationUnderfilled = drugsSectionProducts.length <
          ProductImagePreloadService.homeMedicationVisibleCount;
      if (!_nonDrugSectionsNeedMoreProducts() && !medicationUnderfilled) {
        return;
      }
      final Map<String, List<Product>> sections;
      if (allProducts.length > _isolateProcessThreshold) {
        sections = await compute(_processProductsIsolate, allProducts);
      } else {
        sections = categorizeProductsForHome(allProducts);
      }
      if (!mounted) return;
      setState(() {
        if (medicationUnderfilled && sections['drugs']!.isNotEmpty) {
          drugsSectionProducts = _shuffledSectionPool(sections['drugs']!);
        }
        _fillNonDrugSectionsFromCatalog(allProducts, sections: sections);
      });
      _warmGridSectionImages();
      if (medicationUnderfilled) {
        unawaited(_ensureMedicationRowImagesReady().then((_) {
          if (mounted) setState(() {});
        }));
      }
      return;
    }

    final useIsolate = _forceSectionShuffleOnce ||
        allProducts.length > _isolateProcessThreshold;

    final Map<String, List<Product>> sections;
    if (useIsolate) {
      sections = await compute(_processProductsIsolate, allProducts);
    } else {
      sections = categorizeProductsForHome(allProducts);
    }
    if (!mounted) return;

    _forceSectionShuffleOnce = false;

    // Always reshuffle so each load/refresh surfaces a different set of
    // products instead of repeatedly showing the head of the list.
    final drugs = _shuffledSectionPool(sections['drugs']!);
    final prescribed = _shuffledSectionPool(sections['prescribed']!);
    final wellness = _shuffledSectionPool(sections['wellness']!);
    final selfcare = _shuffledSectionPool(sections['selfcare']!);
    final accessories = _shuffledSectionPool(sections['accessories']!);

    if (mounted) {
      setState(() {
        drugsSectionProducts = drugs;
        prescribedProducts = prescribed;
        wellnessProducts = wellness;
        selfcareProducts = selfcare;
        accessoriesProducts = accessories;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _preloadImages(_visibleHomeProductsForImageWarm());
        unawaited(_warmVisibleHomeImages());
      });
    }
  }

  Future<void> _warmVisibleHomeImages() async {
    await _startHomeImageWarm();
  }

  Future<void> _fetchPopularProducts({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh &&
        ProductCache.cachedPopularProducts.isNotEmpty &&
        ProductCache.isCacheValid) {
      if (mounted) {
        setState(() {
          popularProducts = ProductCache.cachedPopularProducts;
          _isLoadingPopular = false;
          _popularError = null;
        });
        _persistSnapshot();
      }
      return;
    }

    if (mounted) setState(() => _popularError = null);

    try {
      List<Product> list = await _catalogService.fetchPopularProducts(
        timeout: const Duration(seconds: 8),
      );

      if (!mounted) return;

      if (list.isEmpty && ProductCache.cachedProducts.isNotEmpty) {
        ProductCache.warmPopularFromCatalog();
        list = List<Product>.from(ProductCache.cachedPopularProducts);
      }

      if (list.isNotEmpty) {
        ProductCache.cachePopularProducts(list);
        if (ProductCache.cachedPopularProducts.isEmpty) {
          ProductCache.warmPopularFromCatalog();
        }
      }

      if (ProductCache.cachedPopularProducts.isNotEmpty) {
        setState(() {
          popularProducts = ProductCache.cachedPopularProducts;
          _isLoadingPopular = false;
        });
        _persistSnapshot();
        WidgetsBinding.instance.addPostFrameCallback((_) {});
      } else if (list.isNotEmpty) {
        setState(() {
          popularProducts = const [];
          _isLoadingPopular = false;
        });
      } else {
        _fallbackToPopularCache(error: AppErrorUtils.oopsTitle);
      }
    } on TimeoutException {
      _fallbackToPopularCache(error: 'Connection timed out');
    } catch (e) {
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Connection failed') ||
          s.contains('No internet');
      _fallbackToPopularCache(
        error:
            isConnectivity ? 'No internet connection' : 'Something went wrong',
      );
    }
  }

  void _fallbackToPopularCache({String? error}) {
    final cached = ProductCache.cachedPopularProducts;
    if (!mounted) return;
    if (cached.isNotEmpty) {
      setState(() {
        popularProducts = cached;
        _isLoadingPopular = false;
        _popularError = null;
      });
      _persistSnapshot();
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    } else {
      setState(() {
        _popularError = error;
        _isLoadingPopular = false;
      });
    }
  }

  // ─── Refresh ───────────────────────────────────────────────────────────────
  /// Pull-to-refresh: reshuffles when cache is fresh; revalidates from network
  /// only when [ProductCache.shouldRefreshFromNetwork]. Coalesces rapid pulls.
  Future<void> _handleRefresh() async {
    if (_refreshFuture != null) {
      await _refreshFuture;
      return;
    }

    _refreshFuture = _runPullRefresh();
    try {
      await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _runPullRefresh() async {
    if (_isLoadingContent) return;
    _isLoadingContent = true;
    _forceSectionShuffleOnce = true;

    final needsNetwork = ProductCache.shouldRefreshFromNetwork;

    try {
      if (!needsNetwork && ProductCache.hasProductsInMemory) {
        final cached = ProductCache.cachedProducts;
        ProductCache.warmPopularFromCatalog();
        if (mounted) {
          setState(() {
            _products = List<Product>.from(cached);
            filteredProducts = List<Product>.from(cached);
            _error = null;
          });
        }
        await _processProducts(cached);
        if (ProductCache.cachedPopularProducts.isNotEmpty && mounted) {
          setState(() {
            popularProducts =
                List<Product>.from(ProductCache.cachedPopularProducts);
            _isLoadingPopular = false;
            _popularError = null;
          });
          _persistSnapshot();
        } else {
          await _fetchPopularProducts(forceRefresh: false);
        }
        _hasBeenLoaded = true;
        return;
      }

      final popularFuture = _fetchPopularProducts(forceRefresh: needsNetwork);
      await ProductCache.prefetchFromNetwork(forceRefresh: true);
      if (!mounted) return;
      if (ProductCache.hasProductsInMemory) {
        _applyCacheToState();
        await _processProducts(_products);
        _preloadImages(_products.take(8).toList());
        _persistSnapshot();
      } else {
        _fallbackToCache();
      }
      await popularFuture;
      _hasBeenLoaded = true;
    } catch (e) {
      debugPrint('HomePage: refresh error: $e');
    } finally {
      _isLoadingContent = false;
      if (mounted) {
        setState(() {
          _isLoadingPopular = false;
        });
      }
    }
  }

  /// Called externally (e.g. from another page) to force a reload.
  Future<void> reloadHomePage() => _handleRefresh();

  // ─── Image preload ─────────────────────────────────────────────────────────
  List<Product> _visibleGridAndMedicationProducts() => [
        ...drugsSectionProducts
            .take(ProductImagePreloadService.homeMedicationVisibleCount),
        ..._gridSectionProductsForImageWarm(),
      ];

  Future<void> _precacheVisibleHomeImages() async {
    if (!mounted) return;
    await _preloadImages(_visibleGridAndMedicationProducts());
  }

  Future<void> _preloadImages(List<Product> products) async {
    if (!mounted) return;
    final cache = ProductImagePreloadService.cacheManager;
    for (final p in products) {
      final url = ProductImagePreloadService.imageUrlFor(p);
      if (url.isEmpty || ImagePreloader.isPreloaded(url)) continue;

      final diskKey = ProductImagePreloadService.diskCacheKeyFor(url);
      final fileEntry = await cache.getFileFromCache(diskKey);
      if (!mounted) return;
      if (fileEntry != null) {
        if (!mounted) return;
        try {
          await precacheImage(FileImage(fileEntry.file), context);
          ImagePreloader.markPreloaded(url);
        } catch (e) {
          debugPrint('HomePage: disk precache failed for $url ($e)');
          if (!mounted) return;
          ImagePreloader.preloadImage(url, context);
        }
      } else {
        if (!mounted) return;
        ImagePreloader.preloadImage(url, context);
      }
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    ProductCache.removeCatalogListener(_onProductCacheUpdated);
    ProductCache.removePriorityListener(_onPriorityCacheUpdated);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onHomeScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted && _products.isNotEmpty && _preloadedImages.isEmpty) {
      _preloadImages(_products);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _clearSearch();
      if (_hasBeenLoaded && ProductCache.shouldRefreshFromNetwork) {
        unawaited(_refreshCatalogInBackground());
      }
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<bool> requireAuth(BuildContext context) async {
    if (await AuthService.isLoggedIn()) return true;
    if (!context.mounted) return false;
    final result = await _pushOnce<bool>(
      MaterialPageRoute(
        builder: (context) =>
            SignInScreen(returnTo: ModalRoute.of(context)?.settings.name),
      ),
    );
    return result ?? false;
  }

  void _clearSearch() {
    _homeSearchBarKey.currentState?.clear();
  }

  // ─── Snackbar ──────────────────────────────────────────────────────────────
  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration}) {
    AppErrorUtils.showSnack(
      context,
      message,
      isError: true,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  // ─── Categories ────────────────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty || _isLoadingCategories || !mounted) return;
    _hasTriedLoadingCategories = true;
    setState(() => _isLoadingCategories = true);
    try {
      await _categoryService.initialize();
      final categories = await _categoryService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildRefreshableBody(),
      bottomNavigationBar: widget.showBottomNav
          ? CustomBottomNav(
              selectedIndex: 0,
              tourMenuKey: tourMenuKey,
              tourShopKey: tourShopKey,
            )
          : null,
    );
  }

  Widget _buildSkeletonWithLoading({bool loadingImages = false}) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final message = loadingImages
        ? 'Loading product images...'
        : 'Loading your products...';
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(children: [
      _buildHomeRefreshIndicator(
        child: Shimmer.fromColors(
          baseColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade300,
          highlightColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade100,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ..._buildHomeTopSlivers(isTablet, searchSkeleton: true),
              ...HomePageSkeletonBody.shimmerSlivers(context,
                  isTablet: isTablet),
            ],
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            primary.withValues(alpha: 0.4),
          ),
        ),
      ),
      Positioned(
        top: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(message,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildHomeRefreshIndicator({required Widget child}) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }

  Widget _buildRefreshableBody() {
    if (_products.isNotEmpty && _error != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          if (mounted) {
            setState(() => _error = null);
            _hasBeenLoaded = false;
            _loadAllContent();
          }
        },
      );
    }

    final shouldShowSkeleton = _products.isEmpty;
    if (shouldShowSkeleton) {
      return _buildSkeletonWithLoading(
        loadingImages: _products.isNotEmpty && !_homeGridImagesReady,
      );
    }
    return _buildHomeRefreshIndicator(child: _buildMainScrollBody());
  }

  Widget _buildMainScrollBody() {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth >= 600;
        final cardFontSize =
            isTablet ? 16.0 : (screenWidth < 400 ? 11.0 : 13.0);
        final cardPadding = isTablet ? 16.0 : (screenWidth < 400 ? 6.0 : 8.0);
        final cardImageHeight =
            isTablet ? 70.0 : (screenWidth < 400 ? 55.0 : 75.0);

        return Stack(
          children: [
            ProductTapScrollScope(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ..._buildHomeTopSlivers(isTablet),
                  SliverToBoxAdapter(child: const ClearanceSaleBanner()),
                  SliverToBoxAdapter(child: buildOrderMedicineCard()),
                  SliverToBoxAdapter(
                    child: _buildCategoryScroll(
                      isTablet: isTablet,
                      tourChipsKey: _tourCategoriesKey,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildPopularProductsFeatured(isTablet: isTablet),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: KeyedSubtree(
                        key: _tourMedicationKey,
                        child: _buildProductSection(
                          'Medication',
                          Colors.green[700]!,
                          drugsSectionProducts,
                          'drugs',
                          fontSize: cardFontSize,
                          padding: cardPadding,
                          imageHeight: cardImageHeight,
                          isTablet: isTablet,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildSpecialOffers()),
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Wellness',
                      Colors.purple[700]!,
                      wellnessProducts,
                      'wellness',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                      isTablet: isTablet,
                    ),
                  ),
                  // Popular right now — tour highlights heading + horizontal strip
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _tourPopularKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.green[600]!,
                                    Colors.green[700]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Popular right now',
                                      style: _homePoppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPopularProducts(isTablet: isTablet),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Selfcare',
                      Colors.orange[700]!,
                      selfcareProducts,
                      'selfcare',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                      isTablet: isTablet,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Accessories',
                      Colors.teal[700]!,
                      accessoriesProducts,
                      'accessories',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                      isTablet: isTablet,
                    ),
                  ),
                  if (prescribedProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildProductSection(
                        'PRESCRIPTION ONLY MEDICINE',
                        Colors.red[700]!,
                        prescribedProducts,
                        'prescribed',
                        fontSize: cardFontSize,
                        padding: cardPadding,
                        imageHeight: cardImageHeight,
                        isTablet: isTablet,
                      ),
                    ),
                ],
              ),
            ),
            if (_isBackgroundRefreshing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ─── Category scroll ───────────────────────────────────────────────────────
  Widget _buildCategoryScroll({
    bool isTablet = false,
    Key? tourChipsKey,
  }) {
    if (!_hasTriedLoadingCategories &&
        !_isLoadingCategories &&
        _categories.isEmpty) {
      _hasTriedLoadingCategories = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCategories();
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: isTablet ? 24 : 18, vertical: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[600]!, Colors.green[700]!]),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Row(children: [
            const SizedBox(width: 8),
            const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Shop',
                  style: _homePoppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1)),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pushNamedOnce(AppRoutes.categoryPage),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('See all',
                        style: _homePoppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: Colors.white),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (_isLoadingCategories)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 18),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.only(right: 8),
                child: Shimmer.fromColors(
                  baseColor: context.appColors.isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                  highlightColor: context.appColors.isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade100,
                  child: Container(
                      width: 90,
                      height: 38,
                      decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(19))),
                ),
              ),
            ),
          ),
        )
      else if (_categories.isNotEmpty)
        KeyedSubtree(
          key: tourChipsKey,
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 18),
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryName = category['name']?.toString() ?? '';
                final categoryId =
                    categoryIdFromApi(category['id'], fallback: index);
                final hasSubcategories =
                    categoryHasSubcategoriesFromApi(category);
                final theme = context.appColors;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (hasSubcategories) {
                          _pushOnce(
                            MaterialPageRoute(
                                builder: (context) => SubcategoryPage(
                                    categoryName: categoryName,
                                    categoryId: categoryId)),
                          );
                        } else {
                          _pushOnce(
                            MaterialPageRoute(
                                builder: (context) => ProductListPage(
                                    categoryName: categoryName,
                                    categoryId: categoryId)),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(19),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                              color: AppThemeColors.headerBackground,
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: theme.isDark ? 0.25 : 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(categoryName,
                            style: _homePoppins(
                                fontSize: isTablet ? 12 : 11,
                                fontWeight: FontWeight.w600,
                                color: theme.isDark
                                    ? Colors.white
                                    : Colors.green.shade800,
                                letterSpacing: 0.1)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ]);
  }

  // ─── Special offers ────────────────────────────────────────────────────────
  Widget _buildSpecialOffers() {
    final theme = context.appColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.35 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ]),
        child: Column(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset('assets/images/specialoffer.PNG',
                fit: BoxFit.cover, width: double.infinity, height: 120),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: theme.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SPECIAL OFFER: FREE DELIVERY + 5% OFF',
                  style: _homePoppins(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Text('Free delivery on GHS 150+ · 5% off on GHS 500+',
                  style: TextStyle(
                      color: theme.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  'Enjoy free delivery for orders of GHS 150 and above, plus 5% off all orders of GHS 500 and above.',
                  style:
                      TextStyle(color: theme.muted, fontSize: 11, height: 1.3)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }

  List<Product> _popularProductsForFeatured({int count = 9}) {
    final eligible = ProductCache.withoutPrescriptionProducts(popularProducts);
    return eligible.take(count).toList();
  }

  List<Product> _popularProductsForStrip({int start = 9, int count = 12}) {
    final eligible = ProductCache.withoutPrescriptionProducts(popularProducts);
    if (eligible.length <= start) {
      return eligible.take(count).toList();
    }
    return eligible.skip(start).take(count).toList();
  }

  // ─── Trending picks (under categories) ───────────────────────────────────
  Widget _buildPopularProductsFeatured({bool isTablet = false}) {
    if (_isLoadingPopular) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: 12,
        ),
        child: SizedBox(
          height: isTablet ? 240 : 210,
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    if (_popularError != null || popularProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final featured = _popularProductsForFeatured();
    if (featured.isEmpty) return const SizedBox.shrink();

    return HomePopularProductsFeatured(
      products: featured,
      isTablet: isTablet,
    );
  }

  // ─── Popular right now ─────────────────────────────────────────────────────
  Widget _buildPopularProducts({bool isTablet = false}) {
    if (_isLoadingPopular) {
      return const Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator()));
    }
    if (_popularError != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          setState(() => _popularError = null);
          _hasBeenLoaded = false;
          _loadAllContent();
        },
      );
    }
    final stripProducts = _popularProductsForStrip();
    if (stripProducts.isEmpty) {
      return EmptyStateWidget(
          message: 'Nothing popular right now', icon: Icons.star_border);
    }

    return HomePopularProductsStrip(
      products: stripProducts,
      isTablet: isTablet,
    );
  }

  // ─── Product section ───────────────────────────────────────────────────────
  Widget _buildProductSection(
      String title, Color color, List<Product> products, String category,
      {required double fontSize,
      required double padding,
      required double imageHeight,
      bool isTablet = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: (title.toUpperCase() == 'PRESCRIPTION ONLY MEDICINE')
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset(prescribedShieldAsset,
                        width: isTablet ? 32 : 24, height: isTablet ? 32 : 24),
                    const SizedBox(width: 8),
                    Flexible(
                        child: buildSectionHeading(context, title, color,
                            hideIcon: true)),
                  ])
                : buildSectionHeading(context, title, color),
          ),
          TextButton(
            onPressed: () {
              // Homepage grid shows 6; "See More" opens the full backing list.
              final filtered = switch (category.toLowerCase()) {
                'drugs' => List<Product>.from(drugsSectionProducts),
                'wellness' => List<Product>.from(wellnessProducts),
                'selfcare' => List<Product>.from(selfcareProducts),
                'accessories' => List<Product>.from(accessoriesProducts),
                'prescribed' => List<Product>.from(prescribedProducts),
                _ => List<Product>.from(products),
              };
              _pushOnce(
                MaterialPageRoute(
                    builder: (context) => SectionProductsPage(
                        sectionTitle: title, products: filtered)),
              );
            },
            child: Text('See More',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: products.length > _homeGridSectionVisibleCount
            ? _homeGridSectionVisibleCount
            : products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 3 : 2,
          childAspectRatio: isTablet ? 1.2 : 1.0,
          mainAxisSpacing: isTablet ? 8 : 0,
          crossAxisSpacing: isTablet ? 8 : 0,
        ),
        itemBuilder: (context, index) => HomeProductCard(
          key: ValueKey(
            'home-$_homeImageWarmGeneration-'
            '${products[index].id}-'
            '${ProductImagePreloadService.imageUrlFor(products[index])}',
          ),
          product: products[index],
          fontSize: fontSize * 1.1,
          padding: padding * 0.8,
          imageHeight: imageHeight * 0.85,
          showWishlistButton: true,
          showHero: false,
        ),
      ),
      if (products.isEmpty)
        EmptyStateWidget(
            message: 'No products found in this section.',
            icon: Icons.shopping_bag_outlined),
    ]);
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────
class HomePageSkeletonBody extends StatelessWidget {
  const HomePageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    return CustomScrollView(
      slivers: shimmerSlivers(context, isTablet: isTablet),
    );
  }

  static List<Widget> shimmerSlivers(
    BuildContext context, {
    required bool isTablet,
  }) {
    final theme = context.appColors;

    return [
      SliverToBoxAdapter(
        child: Container(
            height: isTablet ? 220 : 140,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: theme.surface, borderRadius: BorderRadius.circular(12))),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                    height: isTablet ? 110 : 90,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: const SizedBox(height: 8)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(4))),
        ),
      ),
      SliverToBoxAdapter(
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(left: 16, bottom: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 8,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(children: [
                Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: theme.surface, shape: BoxShape.circle)),
                const SizedBox(height: 6),
                Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(4))),
              ]),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(4))),
            Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, __) => _buildProductCardSkeleton(theme),
            childCount: isTablet ? 9 : 6,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 3 : 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
          ),
        ),
      ),
      SliverToBoxAdapter(child: const SizedBox(height: 20)),
    ];
  }

  static Widget _buildProductCardSkeleton(AppThemeColors theme) {
    final block = theme.isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: theme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: Container(
              decoration: BoxDecoration(
                  color: block,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)))),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                            width: 60,
                            height: 16,
                            decoration: BoxDecoration(
                                color: block,
                                borderRadius: BorderRadius.circular(4))),
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: block, shape: BoxShape.circle)),
                      ]),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Home promo banners ────────────────────────────────────────────────────────
Widget buildOrderMedicineCard() => const HomePromoBannerCarousel();

// ─── Helpers ───────────────────────────────────────────────────────────────────
String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return ApiConfig.getImageOrStorageUrl(url);
}

Widget buildSectionHeading(
  BuildContext context,
  String title,
  Color color, {
  bool hideIcon = false,
}) {
  final ink = context.appColors.ink;
  String? assetPath;
  switch (title.toLowerCase()) {
    case 'medication':
      assetPath = 'assets/images/medication_logo.png';
      break;
    case 'wellness':
      assetPath = 'assets/images/wellness_logo.png';
      break;
    case 'selfcare':
    case 'self care':
      assetPath = 'assets/images/selfcare.png';
      break;
    default:
      assetPath = null;
  }
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 3,
      height: 20,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1))
          ]),
    ),
    const SizedBox(width: 8),
    if (!hideIcon) ...[
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4)),
        child: assetPath != null
            ? Image.asset(assetPath, height: 32, width: 32, fit: BoxFit.contain)
            : Icon(_getIconForSection(title), color: color, size: 24),
      ),
      const SizedBox(width: 8),
    ],
    Flexible(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: _homePoppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
                letterSpacing: 0.2),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        Container(
          width: 30,
          height: 1,
          decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [color, color.withOpacity(0.2)])),
        ),
      ]),
    ),
  ]);
}

IconData _getIconForSection(String title) {
  switch (title.toLowerCase()) {
    case 'popular products':
    case 'popular right now':
      return Icons.trending_up;
    case 'wellness':
      return Icons.favorite;
    case 'self care':
      return Icons.spa;
    case 'accessories':
      return Icons.headphones;
    case 'drugs':
      return Icons.medical_services;
    case 'prescription only medicine':
      return Icons.verified_user;
    default:
      return Icons.category;
  }
}

Widget buildCapsuleHeading(String title, Color color) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.06)
                ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_getIconForSection(title), color: color, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: _homePoppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3)),
        ]),
      ),
    ),
  );
}
