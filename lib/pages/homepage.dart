// pages/homepage.dart

import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import 'bottomnav.dart';
import 'itemdetail.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_results_page.dart';
import 'dart:convert';
import '../widgets/cart_icon_button.dart';
import '../widgets/product_card.dart';
import '../widgets/home_page_tour.dart';
import '../services/home_preload_service.dart';
import '../services/product_image_preload_service.dart';
import '../services/homepage_optimization_service.dart';
import '../widgets/empty_state.dart';
import 'section_products_page.dart';
import 'package:animations/animations.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_notification_service.dart';

import '../widgets/clearance_sale_banner.dart';
import '../widgets/home/home_promo_banner_carousel.dart';
import '../widgets/home/home_popular_products_strip.dart';
import '../services/category_optimization_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/product_detail_navigation.dart';
import '../utils/app_error_utils.dart';
import 'categories.dart';
import '../cache/product_cache.dart';
import '../utils/catalog_timer.dart';

export '../cache/product_cache.dart';

const String prescribedShieldAsset = 'assets/images/prescribed_shield.png';

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
Map<String, List<Product>> categorizeProductsForHome(List<Product> allProducts) {
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

class SafeTypeAheadField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final Future<List<Product>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, Product) itemBuilder;
  final Function(Product) onSuggestionSelected;
  final Widget Function(BuildContext)? noItemsFoundBuilder;
  final bool hideOnEmpty;
  final bool hideOnLoading;
  final Duration debounceDuration;
  final SuggestionsBoxDecoration suggestionsBoxDecoration;
  final double suggestionsBoxVerticalOffset;
  final SuggestionsBoxController? suggestionsBoxController;

  const SafeTypeAheadField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSuggestionSelected,
    this.noItemsFoundBuilder,
    this.hideOnEmpty = true,
    this.hideOnLoading = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    required this.suggestionsBoxDecoration,
    this.suggestionsBoxVerticalOffset = 0,
    this.suggestionsBoxController,
  });

  @override
  State<SafeTypeAheadField> createState() => _SafeTypeAheadFieldState();
}

class _SafeTypeAheadFieldState extends State<SafeTypeAheadField> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !mounted) return const SizedBox.shrink();

    try {
      return TypeAheadField<Product>(
        textFieldConfiguration: TextFieldConfiguration(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: 'Search medicines, products...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      if (mounted && !_isDisposed) {
                        widget.controller.clear();
                        setState(() {});
                      }
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (value) {
            if (mounted && !_isDisposed) widget.onSubmitted(value);
          },
        ),
        suggestionsCallback: (pattern) async {
          if (pattern.isEmpty || !mounted || _isDisposed) return [];
          try {
            return await widget.suggestionsCallback(pattern);
          } catch (e) {
            return [];
          }
        },
        itemBuilder: (context, suggestion) {
          if (!mounted || _isDisposed) return const SizedBox.shrink();
          return widget.itemBuilder(context, suggestion);
        },
        onSuggestionSelected: (suggestion) {
          if (mounted && !_isDisposed) widget.onSuggestionSelected(suggestion);
        },
        noItemsFoundBuilder: widget.noItemsFoundBuilder,
        hideOnEmpty: widget.hideOnEmpty,
        hideOnLoading: widget.hideOnLoading,
        debounceDuration: widget.debounceDuration,
        suggestionsBoxDecoration: widget.suggestionsBoxDecoration,
        suggestionsBoxVerticalOffset: widget.suggestionsBoxVerticalOffset,
        suggestionsBoxController: widget.suggestionsBoxController,
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

class ErrorDisplayWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No Internet Connection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Please check your connection and try again',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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

class SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double shrinkOffset) builder;

  SliverSearchBarDelegate({required this.builder});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: shrinkOffset > 0
          ? Theme.of(context).appBarTheme.backgroundColor
          : Colors.white,
      child: builder(shrinkOffset),
    );
  }

  @override
  double get maxExtent => 96.0;

  @override
  double get minExtent => 96.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
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
  bool _isLoading = true;
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

  final RefreshController _refreshController = RefreshController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _tourSearchKey = GlobalKey();
  final GlobalKey _tourCartKey = GlobalKey();
  final GlobalKey _tourCategoriesKey = GlobalKey();
  final GlobalKey _tourMedicationKey = GlobalKey();
  final GlobalKey _tourPopularKey = GlobalKey();
  final GlobalKey _tourShopKey = GlobalKey();
  final GlobalKey _tourMenuKey = GlobalKey();
  final ProductCatalogService _catalogService = ProductCatalogService();

  GlobalKey get tourMenuKey => widget.tourMenuKey ?? _tourMenuKey;
  GlobalKey get tourShopKey => widget.tourShopKey ?? _tourShopKey;

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
  /// Grid sections on home (Wellness, Selfcare, etc.) show up to this many cards.
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

    _scrollController.addListener(() {
    if (!mounted) return;
      if (_scrollController.offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

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
    _isLoading = false;
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
    _isLoading = false;
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

  /// Fast shuffle — only randomize a small pool per section (not 1000+ items).
  List<Product> _shuffledSectionPool(List<Product> source, {int pool = 40}) {
    if (source.isEmpty) return [];
    if (source.length <= pool) {
      return List<Product>.from(source)..shuffle();
    }
    final copy = List<Product>.from(source)..shuffle();
    return copy.take(pool).toList();
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
    if (_sectionPoolUnderfilled(prescribedProducts) &&
        buckets['prescribed']!.isNotEmpty) {
      prescribedProducts = _shuffledSectionPool(buckets['prescribed']!);
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
      _isLoading = false;
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
        _isLoading = false;
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

    final shouldShuffle =
        reshuffleSections && (drugsSectionProducts.isEmpty || _forceSectionShuffleOnce);
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
        _isLoading = false;
        _hasBeenLoaded = true;
      } else if (_products.isEmpty && ProductCache.hasPriorityProducts) {
        _hydrateFromPriorityProducts();
        _hasBeenLoaded = true;
      } else if (_products.isEmpty) {
        _isLoading = true;
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
  Future<void> _startHomeImageWarm({bool skipMedicationRow = false}) async {
    if (_products.isEmpty || !mounted) return;
    await _warmMedicationRowThenRest();
  }

  void _scheduleSpotlightTourDelayed() {
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _scheduleSpotlightTour();
    });
  }

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
          await NativeNotificationService.testNotification();
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      if (!await NativeNotificationService.isLocationWhenInUseGranted()) {
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
    final justFinished = prefs.getBool('just_finished_onboarding') ?? false;
    final forceTour =
        justFinished || !(prefs.getBool('has_seen_smart_tips') ?? false);

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
        continue;
      }
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: justFinished ? 120 : 400 * attempt),
        );
      }
      final shown = await HomePageTour.maybeStart(
        context: context,
        targets: HomePageTourTargets(
          searchKey: _tourSearchKey,
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
      if (shown) {
        if (justFinished) {
          await prefs.setBool('just_finished_onboarding', false);
        }
        return;
      }
    }
    debugPrint('HomePageTour: not shown after retries');
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
        final ready = await ProductCache.ensureCatalogReady(maxWait: catalogWait);
        if (!mounted) return;
        if (ready && ProductCache.hasProductsInMemory) {
          _applyCacheToState();
          _hasBeenLoaded = true;
          await _processProducts(_products);
          _scheduleSpotlightTour();
          unawaited(_ensureHomeGridImages());
          if (mounted) {
            setState(() {
              _isLoading = false;
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
              _isLoading = false;
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
      if (mounted) setState(() => _isLoading = false);
      if (_refreshController.isRefresh) _refreshController.refreshCompleted();
      if (mounted) {
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
          _isLoading = false;
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
          _isLoading = false;
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
            _isLoading = false;
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
            _isLoading = false;
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
            _isLoading = false;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
        });
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
        error: isConnectivity ? 'No internet connection' : 'Something went wrong',
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
      });
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
      _completePullRefresh();
      return;
    }

    _refreshFuture = _runPullRefresh();
    try {
      await _refreshFuture;
    } finally {
      _refreshFuture = null;
      _completePullRefresh();
    }
  }

  void _completePullRefresh() {
    if (mounted && _refreshController.isRefresh) {
      _refreshController.refreshCompleted();
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
            _isLoading = false;
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
          _isLoading = false;
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
        try {
          await precacheImage(FileImage(fileEntry.file), context);
          ImagePreloader.markPreloaded(url);
        } catch (e) {
          debugPrint('HomePage: disk precache failed for $url ($e)');
          ImagePreloader.preloadImage(url, context);
        }
      } else {
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
    searchController.dispose();
    _searchController.dispose();
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

  // ─── Contact helpers ───────────────────────────────────────────────────────
  _launchPhoneDialer(String phoneNumber) async {
    if (!mounted) return;
    final status = await Permission.phone.request();
    if (!mounted) return;
    if (status.isGranted) {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  _launchWhatsApp(String phoneNumber, String message) async {
    if (phoneNumber.isEmpty || message.isEmpty) return;
    if (!phoneNumber.startsWith('+')) return;
    final url =
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (!context.mounted) return;
      showTopSnackBar(
          context, 'Could not open WhatsApp. Please ensure it is installed.');
    }
  }

  void _launchEmail(String email, String subject) async {
    try {
      final body =
          'Hello,\n\nI would like to contact Ernest Chemists Limited for support.\n\nBest regards,';
      final uri = Uri.parse(
          'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showEmailAlternatives(email);
      }
    } catch (_) {
      _showEmailAlternatives(email);
    }
  }

  void makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty && mounted) {
      _searchController.clear();
      setState(() {});
    }
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

  // ─── Contact bottom sheet ──────────────────────────────────────────────────
  void _showContactOptions(String phoneNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                  offset: const Offset(0, -5))
            ]),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(
              padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade50, Colors.blue.shade50]),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                  padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade200,
                              blurRadius: 6,
                            offset: const Offset(0, 1))
                      ]),
                  child: Image.asset('assets/images/png.png',
                      width: 20, height: 20, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 8),
                Column(children: [
                  Text("We're Here to Help!",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800)),
                  Text('Choose your preferred way to get in touch',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                          height: 1.1)),
                ]),
              ]),
                ),
                const SizedBox(height: 16),
                _buildModernContactOption(
                  icon: Icons.phone_rounded,
                  title: 'Call Us',
                  subtitle: 'Speak directly with our team',
                  phone: '0302908674',
                  color: Colors.green.shade600,
                  onTap: () {
                    Navigator.pop(context);
                    _launchPhoneDialer(phoneNumber);
                    makePhoneCall(phoneNumber);
                  },
                ),
                const SizedBox(height: 8),
                _buildModernContactOption(
                  icon: Icons.message_rounded,
                  title: 'WhatsApp',
                  subtitle: 'Chat with us instantly',
                  phone: 'Chat Now',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.pop(context);
                    _launchWhatsApp(phoneNumber,
                        "Hello! I need help with the Ernest Chemist app. Can you assist me?");
                  },
                ),
                const SizedBox(height: 8),
                _buildModernContactOption(
                  icon: Icons.email_rounded,
                  title: 'Email Us',
                  subtitle: 'Send us a detailed message',
                  phone: 'support@ernestchemists.com',
                  color: Colors.blue.shade600,
                  onTap: () {
                    Navigator.pop(context);
                _launchEmail(
                    'support@ernestchemists.com', 'Ernest Chemist Support & Inquiry');
                  },
                ),
          ]),
            ),
          ),
    );
  }

  Widget _buildModernContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String phone,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
            Container(
            padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0.05)
                    ]),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
            Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
              const SizedBox(height: 2),
              Text(subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600, height: 1.2)),
              const SizedBox(height: 4),
                  Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(phone,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color)),
                      ),
            ]),
            ),
            Container(
            padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child:
                Icon(Icons.arrow_forward_ios_rounded, color: color, size: 12),
          ),
        ]),
      ),
    );
  }

  void _showEmailAlternatives(String email) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
              Icon(Icons.email_outlined, color: Colors.green.shade600),
              const SizedBox(width: 8),
          Text('Email Not Available',
                style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'No email app found on your device. Here are alternative ways to contact us:',
                style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey.shade700)),
              const SizedBox(height: 16),
          Text('Email Address:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
                    Expanded(
                  child: Text(email,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500))),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: email));
                        Navigator.pop(context);
                  AppErrorUtils.showSnack(
                    context,
                    'Email copied to clipboard',
                    isError: false,
                            duration: const Duration(seconds: 2),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.copy, color: Colors.white, size: 16),
                        ),
                        ),
            ]),
              ),
              const SizedBox(height: 12),
              Text(
                'You can copy the email address and use it in your preferred email app.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic)),
        ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.poppins(
                    color: Colors.green.shade600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
      if (mounted)
          setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Only block on catalog — product cards show placeholders while images warm.
    final shouldShowSkeleton = _products.isEmpty;
    return Scaffold(
      body: shouldShowSkeleton
          ? _buildSkeletonWithLoading(
              loadingImages:
                  _products.isNotEmpty && !_homeGridImagesReady,
            )
          : _buildMainContent(),
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
    final message = loadingImages
        ? 'Loading product images...'
        : 'Loading your products...';
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(children: [
      const HomePageSkeletonBody(),
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

  Widget _buildMainContent() {
    if (_error != null) {
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

    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
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
            SmartRefresher(
          controller: _refreshController,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                toolbarHeight: isTablet ? 80 : 60,
                floating: false,
                pinned: false,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isTablet ? 16 : 1),
                      child: Image.asset('assets/images/png.png',
                          height: isTablet ? 32 : 20),
                    ),
                    CartIconButton(
                      key: _tourCartKey,
                      iconColor: Colors.white,
                      iconSize: isTablet ? 28 : 24,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: SliverSearchBarDelegate(
                    builder: (s) => _buildSearchBar(isTablet: isTablet)),
              ),
              SliverToBoxAdapter(child: const ClearanceSaleBanner()),
              SliverToBoxAdapter(child: buildOrderMedicineCard()),
              SliverToBoxAdapter(
                child: _buildCategoryScroll(
                  isTablet: isTablet,
                  tourChipsKey: _tourCategoriesKey,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: KeyedSubtree(
                    key: _tourMedicationKey,
                    child: _buildProductSection(
                      'Medication',
                      Colors.green[700]!,
                      _getLimitedProducts(drugsSectionProducts),
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
                  _getLimitedProducts(wellnessProducts),
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
                                  color: Colors.white.withValues(alpha: 0.2),
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
                                  style: GoogleFonts.poppins(
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
                  _getLimitedProducts(selfcareProducts),
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
                  _getLimitedProducts(accessoriesProducts),
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
                    _getLimitedProducts(prescribedProducts),
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

  // ─── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar({bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 50 : 40,
          isTablet ? 24 : 16, isTablet ? 12 : 8),
      child: KeyedSubtree(
        key: _tourSearchKey,
      child: SizedBox(
        height: isTablet ? 56 : 48,
        child: Builder(builder: (context) {
          if (!mounted) return const SizedBox.shrink();
            try {
              return SafeTypeAheadField(
                controller: _searchController,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                  _pushOnce(
                      MaterialPageRoute(
                        builder: (context) => SearchResultsPage(
                            query: value.trim(), products: _products)),
                    ).then((_) => _clearSearch());
                  }
                },
                suggestionsCallback: (pattern) async {
                if (pattern.isEmpty || !mounted) return [];
                try {
                  final products = await _catalogService.searchForTypeahead(
                    pattern,
                    timeout: const Duration(seconds: 10),
                  );
                      if (products.length > 1) {
                        return [
                          Product(
                            id: -1,
                            name: '__VIEW_MORE__',
                            description: '',
                            urlName: '',
                            status: '',
                            price: '',
                            thumbnail: '',
                            quantity: '',
                            batch_no: '',
                            category: '',
                          route: ''),
                          ...products.take(6),
                        ];
                      }
                      return products;
                  } on TimeoutException {
                    return [];
                } catch (_) {
                    return [];
                  }
                },
                itemBuilder: (context, Product suggestion) {
                if (!mounted) return const SizedBox.shrink();
                  if (suggestion.name == '__VIEW_MORE__') {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12)),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.list, color: Colors.green[700]),
                      title: Text('View All Results',
                          style: GoogleFonts.poppins(
                            color: Colors.green[700],
                              fontWeight: FontWeight.bold)),
                      ),
                    );
                  }
                final matching = _products.firstWhere(
                    (p) => p.id == suggestion.id || p.name == suggestion.name,
                    orElse: () => suggestion);
                  final imageUrl = getProductImageUrl(
                    matching.thumbnail.isNotEmpty
                        ? matching.thumbnail
                          : suggestion.thumbnail);
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                            offset: const Offset(0, 1))
                      ],
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.06))),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                      final m = _products.firstWhere(
                          (p) =>
                              p.id == suggestion.id ||
                              p.name == suggestion.name,
                          orElse: () => suggestion);
                        if (suggestion.name == '__VIEW_MORE__') {
                        _pushOnce(
                            MaterialPageRoute(
                              builder: (context) => SearchResultsPage(
                                query: _searchController.text,
                                  products: _products)),
                          ).then((_) => _clearSearch());
                        } else {
                        _pushOnce(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProductDetailNavigation.itemPage(
                                    urlName: m.urlName.isNotEmpty
                                        ? m.urlName
                                        : suggestion.urlName,
                                    product: m,
                                  )),
                          ).then((_) => _clearSearch());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                      child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                memCacheHeight: 200,
                            fadeInDuration: const Duration(milliseconds: 100),
                            placeholder: (_, __) => const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (_, __, ___) => Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: Colors.grey[400]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(suggestion.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                        color: Colors.black87)),
                              ]),
                        ),
                      ]),
                      ),
                    ),
                  );
                },
                onSuggestionSelected: (Product suggestion) {
                final m = _products.firstWhere(
                    (p) => p.id == suggestion.id || p.name == suggestion.name,
                    orElse: () => suggestion);
                  if (suggestion.name == '__VIEW_MORE__') {
                  _pushOnce(
                      MaterialPageRoute(
                        builder: (context) => SearchResultsPage(
                          query: _searchController.text,
                            products: _products)),
                    ).then((_) => _clearSearch());
                  } else {
                  _pushOnce(
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailNavigation.itemPage(
                              urlName: m.urlName.isNotEmpty
                                  ? m.urlName
                                  : suggestion.urlName,
                              product: m,
                            )),
                    ).then((_) => _clearSearch());
                  }
                },
                noItemsFoundBuilder: (context) => Padding(
                padding: const EdgeInsets.all(12),
                  child: Text('No products found',
                      style: TextStyle(color: Colors.grey)),
                ),
                hideOnEmpty: true,
                hideOnLoading: false,
              debounceDuration: const Duration(milliseconds: 350),
                suggestionsBoxDecoration: SuggestionsBoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 18),
                  elevation: isTablet ? 15 : 10,
                ),
              );
          } catch (_) {
              return const SizedBox.shrink();
            }
        }),
        ),
      ),
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
                        style: GoogleFonts.poppins(
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
                                style: GoogleFonts.poppins(
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
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 90,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                final categoryName = category['name'] ?? '';
                final hasSubcategories = _categoryHasSubcategories(category);
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
                                  categoryId: category['id'])),
                          );
                        } else {
                        _pushOnce(
                            MaterialPageRoute(
                              builder: (context) => ProductListPage(
                                categoryName: categoryName,
                                  categoryId: category['id'])),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(19),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: Colors.green.shade700, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                          ],
                        ),
                      child: Text(categoryName,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
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

  bool _categoryHasSubcategories(dynamic category) {
    if (category is! Map) return false;

    final id = int.tryParse('${category['id']}');
    // Keep homepage category navigation aligned with Categories page behavior.
    const forcedSubcategoryIds = {1, 2, 3, 4, 6, 7, 8, 9, 11};
    if (id != null && forcedSubcategoryIds.contains(id)) return true;

    final raw = category['has_subcategories'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = '${raw ?? ''}'.toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes';
  }

  // ─── Special offers ────────────────────────────────────────────────────────
  Widget _buildSpecialOffers() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
        Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
            decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SPECIAL OFFER: FREE DELIVERY + 5% OFF',
                      style: GoogleFonts.poppins(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Text('Free delivery on GHS 150+ · 5% off on GHS 500+',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
                    Text(
                      'Enjoy free delivery for orders of GHS 150 and above, plus 5% off all orders of GHS 500 and above.',
                      style: TextStyle(
                      color: Colors.grey[600], fontSize: 11, height: 1.3)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
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
    if (popularProducts.isEmpty) {
      return EmptyStateWidget(
          message: 'Nothing popular right now', icon: Icons.star_border);
    }

    return HomePopularProductsStrip(
      products: popularProducts,
      isTablet: isTablet,
    );
  }

  // ─── Product section ───────────────────────────────────────────────────────
  List<Product> _getLimitedProducts(List<Product> products, {int limit = 8}) =>
      products.take(limit).toList();

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
                        child:
                            buildSectionHeading(title, color, hideIcon: true)),
                  ])
                : buildSectionHeading(title, color),
              ),
              TextButton(
                onPressed: () {
              // The section cards are capped on homepage; "See More" should open
              // the full backing list for that section.
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
          itemCount: products.length > 6 ? 6 : products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 3 : 2,
          childAspectRatio: isTablet ? 1.2 : 1.0,
          mainAxisSpacing: isTablet ? 8 : 0,
          crossAxisSpacing: isTablet ? 8 : 0,
        ),
        itemBuilder: (context, index) => AnimatedVisibilityProductCard(
              key: ValueKey(
                'home-$_homeImageWarmGeneration-'
                '${products[index].id}-'
                '${ProductImagePreloadService.imageUrlFor(products[index])}',
              ),
              product: products[index],
              fontSize: fontSize * 1.1,
              padding: padding * 0.8,
              imageHeight: imageHeight * 0.85,
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
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CustomScrollView(slivers: [
          SliverAppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF4CAF50),
          toolbarHeight: isTablet ? 80 : 60,
          flexibleSpace: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      width: isTablet ? 100 : 85,
                      height: isTablet ? 40 : 35,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8))),
                  Container(
                      width: 40,
                height: 40,
                decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle)),
                ]),
                ),
              ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchBarSkeletonDelegate(isTablet: isTablet),
            ),
          SliverToBoxAdapter(
              child: Container(
              height: isTablet ? 220 : 140,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12))),
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
                color: Colors.white,
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
                color: Colors.white,
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
                    decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(height: 6),
                  Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                      color: Colors.white,
                          borderRadius: BorderRadius.circular(4))),
                ]),
                    ),
                  ),
                ),
              ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      width: 150,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4))),
                  Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4))),
                ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, __) => _buildProductCardSkeleton(),
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
      ]),
    );
  }

  Widget _buildProductCardSkeleton() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
          flex: 3,
                  child: Container(
              decoration: BoxDecoration(
                    color: Colors.grey[200],
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
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                Container(
                  width: 60,
                            height: 16,
                  decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4))),
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle)),
                      ]),
                ]),
          ),
        ),
      ]),
    );
  }
}

class _SearchBarSkeletonDelegate extends SliverPersistentHeaderDelegate {
  final bool isTablet;
  _SearchBarSkeletonDelegate({required this.isTablet});

  @override
  double get minExtent => isTablet ? 80 : 70;
  @override
  double get maxExtent => isTablet ? 80 : 70;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
          height: isTablet ? 55 : 50,
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25))),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate _) => false;
}

// ─── Home promo banners ────────────────────────────────────────────────────────
Widget buildOrderMedicineCard() => const HomePromoBannerCarousel();

// ─── Helpers ───────────────────────────────────────────────────────────────────
String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return ApiConfig.getImageOrStorageUrl(url);
}

Widget buildSectionHeading(String title, Color color, {bool hideIcon = false}) {
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                  letterSpacing: 0.3)),
        ]),
      ),
    ),
  );
}

// ─── Animated product card ─────────────────────────────────────────────────────
class AnimatedVisibilityProductCard extends StatefulWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;

  const AnimatedVisibilityProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
  });

  @override
  State<AnimatedVisibilityProductCard> createState() =>
      _AnimatedVisibilityProductCardState();
}

class _AnimatedVisibilityProductCardState
    extends State<AnimatedVisibilityProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction > 0.1 && !_visible) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    } else if (info.visibleFraction == 0 && _visible) {
      setState(() => _visible = false);
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? UniqueKey(),
      onVisibilityChanged: _onVisibilityChanged,
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openColor: Theme.of(context).scaffoldBackgroundColor,
        closedColor: Colors.transparent,
        closedElevation: 0,
        openElevation: 0,
        transitionDuration: const Duration(milliseconds: 200),
        closedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
        openBuilder: (context, _) => ProductDetailNavigation.itemPage(
          urlName: widget.product.urlName,
          product: widget.product,
        ),
        closedBuilder: (context, openContainer) => HomeProductCard(
          product: widget.product,
          fontSize: widget.fontSize,
          padding: widget.padding,
          imageHeight: widget.imageHeight,
          showWishlistButton: true,
          onTap: () {
            ProductDetailNavigation.routeArguments(
              urlName: widget.product.urlName,
              product: widget.product,
            );
            WidgetsBinding.instance
                .addPostFrameCallback((_) => openContainer());
          },
          showHero: false,
        ),
      ),
    );
  }
}
