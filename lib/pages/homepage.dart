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
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/cart_icon_button.dart';
import '../widgets/product_card.dart';
import '../widgets/smart_tips.dart';
import '../services/banner_cache_service.dart';
import '../services/homepage_optimization_service.dart';
import '../widgets/empty_state.dart';
import 'section_products_page.dart';
import 'package:animations/animations.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/clearance_sale_banner.dart';
import '../services/category_optimization_service.dart';
import 'categories.dart';

import 'notification_permission_page.dart';

class _BannerData {
  final String image;
  final String headline;
  final String subtitle;
  _BannerData(
      {required this.image, required this.headline, required this.subtitle});
}

const String prescribedShieldAsset = 'assets/images/prescribed_shield.png';

class ImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  static void preloadImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty || _preloadedImages.containsKey(imageUrl)) return;
    _preloadedImages[imageUrl] = true;
    precacheImage(
      CachedNetworkImageProvider(imageUrl),
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
}

class ProductCache {
  static List<Product> _cachedProducts = [];
  static List<Product> _cachedPopularProducts = [];
  static DateTime? _lastCacheTime;
  static DateTime? _lastShuffleTime;

  static const Duration _cacheValidDuration = Duration(hours: 2);
  static const Duration _staleWhileRevalidateDuration = Duration(hours: 6);
  static const Duration _shuffleInterval = Duration(hours: 1);
  static const String _popularProductsKey = 'cached_popular_products';
  static const String _lastCacheTimeKey = 'last_cache_time';
  static const String _lastShuffleTimeKey = 'last_shuffle_time';

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  static bool get canUseStaleData {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) <
        _staleWhileRevalidateDuration;
  }

  static bool get shouldShuffle {
    if (_lastShuffleTime == null) return true;
    return DateTime.now().difference(_lastShuffleTime!) >= _shuffleInterval;
  }

  static List<Product> get popularProductsWithShuffle {
    if (shouldShuffle) _shufflePopularProducts();
    return _cachedPopularProducts;
  }

  static void cacheProducts(List<Product> products) {
    _cachedProducts = products;
    _lastCacheTime = DateTime.now();
  }

  static void cachePopularProducts(List<Product> products) {
    _cachedPopularProducts = products;
    _lastCacheTime = DateTime.now();
    _lastShuffleTime = DateTime.now();
    _saveToStorage();
  }

  static List<Product> get cachedProducts => _cachedProducts;
  static List<Product> get cachedPopularProducts => _cachedPopularProducts;

  static void clearCache() {
    _cachedProducts.clear();
    _cachedPopularProducts.clear();
    _lastCacheTime = null;
    _lastShuffleTime = null;
    _clearFromStorage();
  }

  static Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTimeString = prefs.getString(_lastCacheTimeKey);
      final lastShuffleTimeString = prefs.getString(_lastShuffleTimeKey);

      if (lastCacheTimeString != null) {
        _lastCacheTime = DateTime.parse(lastCacheTimeString);

        if (isCacheValid) {
          final productsJson = prefs.getString(_popularProductsKey);
          if (productsJson != null) {
            final List<dynamic> productsList = json.decode(productsJson);
            _cachedPopularProducts =
                productsList.map((json) => Product.fromJson(json)).toList();

            if (lastShuffleTimeString != null) {
              _lastShuffleTime = DateTime.parse(lastShuffleTimeString);
            }
          }
        } else {
          _clearFromStorage();
        }
      }
    } catch (e) {
      debugPrint('ProductCache: Error loading from storage: $e');
      _clearFromStorage();
    }
  }

  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson =
          json.encode(_cachedPopularProducts.map((p) => p.toJson()).toList());
      await prefs.setString(_popularProductsKey, productsJson);
      await prefs.setString(
          _lastCacheTimeKey, _lastCacheTime!.toIso8601String());
      if (_lastShuffleTime != null) {
        await prefs.setString(
            _lastShuffleTimeKey, _lastShuffleTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('ProductCache: Error saving to storage: $e');
    }
  }

  static Future<void> _clearFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_popularProductsKey);
      await prefs.remove(_lastCacheTimeKey);
      await prefs.remove(_lastShuffleTimeKey);
    } catch (e) {
      debugPrint('ProductCache: Error clearing from storage: $e');
    }
  }

  static void _shufflePopularProducts() {
    if (_cachedPopularProducts.isNotEmpty) {
      final shuffled = List<Product>.from(_cachedPopularProducts);
      shuffled.shuffle();
      _cachedPopularProducts = shuffled;
      _lastShuffleTime = DateTime.now();
      _saveToStorage();
    }
  }
}

// ─── Background isolate for product processing ───────────────────────────────
Map<String, List<Product>> _processProductsIsolate(List<Product> allProducts) {
  final otcDrug = <Product>[];
  final prescribed = <Product>[];
  final wellness = <Product>[];
  final selfcare = <Product>[];
  final accessories = <Product>[];

  for (final p in allProducts) {
    final isPom = p.otcpom?.trim().toLowerCase() == 'pom';
    if (isPom) {
      prescribed.add(p);
    } else if (p.otcpom?.trim().toLowerCase() == 'otc' ||
        p.drug?.trim().toLowerCase() == 'drug') {
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
  const HomePage({super.key});

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
  final ScrollController _popularScrollController = ScrollController();

  bool _isScrolled = false;

  List<dynamic> _categories = [];
  bool _isLoadingCategories = false;
  bool _hasTriedLoadingCategories = false;

  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();
  final HomepageOptimizationService _optimizationService =
      HomepageOptimizationService();
  final Map<String, bool> _preloadedImages = {};

  Timer? _popularScrollTimer;

  DateTime? _lastSectionShuffleTime;
  static const Duration _sectionShuffleInterval = Duration(hours: 1);

  // ─── Cache / load guard ───────────────────────────────────────────────────
  // true after the first successful fetch; never reset except on explicit
  // pull-to-refresh or reloadHomePage().
  bool _hasBeenLoaded = false;
  bool _isLoadingContent = false;
  Future<void>? _bootstrapFuture;

  @override
  bool get wantKeepAlive => true;

  // ─── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkAndShowWelcomeMessage();

    // Restore last in-memory snapshot immediately when page is recreated.
    _restoreSnapshotToState();

    // Show whatever is in cache immediately (no skeleton if cache exists)
    _applyCacheToState();

    // Load persistent cache + optimization service before first fetch.
    _bootstrapFuture = _initializeServicesInBackground();

    _loadSectionShuffleTimeSync();

    // Trigger real fetch only on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasBeenLoaded) {
        unawaited(_bootstrapAndLoadContent());
      }
    });

    // Categories
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _loadCategories();
    });

    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    _popularScrollController.addListener(() {
      if (mounted) setState(() {});
    });
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

  // Seed section lists immediately so homepage sections render
  // while isolate-based processing is still running.
  void _seedSectionsFromProducts(List<Product> allProducts) {
    if (allProducts.isEmpty) return;
    drugsSectionProducts = allProducts
        .where((p) =>
            p.drug?.toLowerCase() == 'drug' && p.otcpom?.toLowerCase() != 'pom')
        .toList(growable: false);
    prescribedProducts = allProducts
        .where((p) => p.otcpom?.toLowerCase() == 'pom')
        .toList(growable: false);
    wellnessProducts = allProducts
        .where((p) => p.wellness?.toLowerCase() == 'wellness')
        .toList(growable: false);
    selfcareProducts = allProducts
        .where((p) => p.selfcare?.toLowerCase() == 'selfcare')
        .toList(growable: false);
    accessoriesProducts = allProducts
        .where((p) => p.accessories?.toLowerCase() == 'accessories')
        .toList(growable: false);
  }

  void _applyCacheToState() {
    final cachedAll = ProductCache.cachedProducts;
    final cachedPopular = ProductCache.cachedPopularProducts;

    setState(() {
      if (cachedAll.isNotEmpty) {
        _products = cachedAll;
        filteredProducts = cachedAll;
        _seedSectionsFromProducts(cachedAll);
        _isLoading = false;
      } else if (_products.isEmpty) {
        // Show skeleton only when we truly have nothing to render yet.
        _isLoading = true;
      }

      if (cachedPopular.isNotEmpty) {
        popularProducts = cachedPopular;
        _isLoadingPopular = false;
      } else {
        _isLoadingPopular = true;
      }

      _error = null;
    });
    _persistSnapshot();
  }

  Future<void> _initializeServicesInBackground() async {
    await ProductCache.loadFromStorage();
    await _optimizationService.initialize();

    // After storage load, re-apply cache (may now have persisted products)
    if (mounted) _applyCacheToState();
  }

  Future<void> _bootstrapAndLoadContent() async {
    await (_bootstrapFuture ?? Future.value());
    if (!mounted || _hasBeenLoaded) return;
    await _loadAllContent();
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
      // Run both fetches in parallel
      await Future.wait([
        _fetchPopularProducts(),
        loadProducts(),
      ]);

      _hasBeenLoaded = true;
    } catch (e) {
      debugPrint('HomePage: Exception in _loadAllContent: $e');
      if (mounted) setState(() => _error = 'Failed to load content');
    } finally {
      _isLoadingContent = false;
      if (mounted) setState(() => _isLoading = false);
      if (_refreshController.isRefresh) _refreshController.refreshCompleted();
      if (mounted) {
        _optimizationService.preloadAllProductImages(context);
      }
    }
  }

  Future<void> loadProducts() async {
    if (!mounted) return;

    try {
      if (mounted) setState(() => _error = null);

      final response = await http
          .get(Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getAllProducts)))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        final allProducts = dataList.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: item['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
            quantity: item['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        ProductCache.cacheProducts(allProducts);

        // Preload first 8 images immediately
        _preloadImages(allProducts.take(8).toList());

        // Show products right away, then process sections in background
        if (mounted) {
          setState(() {
            _products = allProducts;
            filteredProducts = allProducts;
            _seedSectionsFromProducts(allProducts);
            _isLoading = false;
          });
          _persistSnapshot();
        }

        await _processProducts(allProducts);
      } else {
        _fallbackToCache();
      }
    } on TimeoutException {
      _fallbackToCache(error: 'Connection timed out');
    } on http.ClientException {
      _fallbackToCache(error: 'No internet connection');
    } catch (e) {
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
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
    } else if (error != null && mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  /// Runs product categorisation in a background isolate to avoid UI jank.
  Future<void> _processProducts(List<Product> allProducts) async {
    if (!mounted) return;

    final sections = await compute(_processProductsIsolate, allProducts);
    if (!mounted) return;

    final shouldShuffle = _shouldShuffleSections();

    final drugs = sections['drugs']!;
    final prescribed = sections['prescribed']!;
    final wellness = sections['wellness']!;
    final selfcare = sections['selfcare']!;
    final accessories = sections['accessories']!;

    if (shouldShuffle) {
      drugs.shuffle();
      prescribed.shuffle();
      wellness.shuffle();
      selfcare.shuffle();
      accessories.shuffle();
      _lastSectionShuffleTime = DateTime.now();
      unawaited(_saveSectionShuffleTime());
    }

    if (mounted) {
      setState(() {
        drugsSectionProducts = drugs;
        prescribedProducts = prescribed;
        wellnessProducts = wellness;
        selfcareProducts = selfcare;
        accessoriesProducts = accessories;
      });
    }
  }

  Future<void> _fetchPopularProducts() async {
    if (!mounted) return;

    if (mounted) setState(() => _popularError = null);

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.popularProducts)))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> productsData = data['data'] ?? [];
        if (!mounted) return;

        List<Product> list = productsData.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: item['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? '',
            quantity: item['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        ProductCache.cachePopularProducts(list);

        if (mounted) {
          setState(() {
            popularProducts = list;
            _isLoadingPopular = false;
          });
          _persistSnapshot();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startPopularProductsAutoScroll();
          });
        }
      } else {
        _fallbackToPopularCache(error: 'Server error');
      }
    } on TimeoutException {
      _fallbackToPopularCache(error: 'Connection timed out');
    } on http.ClientException {
      _fallbackToPopularCache(error: 'No internet connection');
    } catch (e) {
      _fallbackToPopularCache(error: 'Something went wrong');
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
        if (mounted) _startPopularProductsAutoScroll();
      });
    } else {
      setState(() {
        _popularError = error;
        _isLoadingPopular = false;
      });
    }
  }

  // ─── Refresh ───────────────────────────────────────────────────────────────
  /// Pull-to-refresh: clears cache and re-fetches everything.
  Future<void> _handleRefresh() async {
    _hasBeenLoaded = false;
    ProductCache.clearCache();
    ImagePreloader.clearPreloadedImages();
    await _loadAllContent();
  }

  /// Called externally (e.g. from another page) to force a reload.
  Future<void> reloadHomePage() async {
    _hasBeenLoaded = false;
    ProductCache.clearCache();
    ImagePreloader.clearPreloadedImages();
    await _loadAllContent();
  }

  // ─── Shuffle helpers ───────────────────────────────────────────────────────
  bool _shouldShuffleSections() {
    if (_lastSectionShuffleTime == null) return true;
    return DateTime.now().difference(_lastSectionShuffleTime!) >=
        _sectionShuffleInterval;
  }

  Future<void> _saveSectionShuffleTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSectionShuffleTime != null) {
        await prefs.setString(
            'section_shuffle_time', _lastSectionShuffleTime!.toIso8601String());
      }
    } catch (_) {}
  }

  void _loadSectionShuffleTimeSync() {
    SharedPreferences.getInstance().then((prefs) {
      final s = prefs.getString('section_shuffle_time');
      if (s != null) _lastSectionShuffleTime = DateTime.parse(s);
    }).catchError((_) {});
  }

  // ─── Image preload ─────────────────────────────────────────────────────────
  void _preloadImages(List<Product> products) {
    final urls = products
        .map((p) => getProductImageUrl(p.thumbnail))
        .where((u) => u.isNotEmpty)
        .toList();
    ImagePreloader.preloadImages(urls, context);
  }

  // ─── Auto-scroll popular ───────────────────────────────────────────────────
  void _startPopularProductsAutoScroll() {
    if (popularProducts.isEmpty || !mounted) return;
    _popularScrollTimer?.cancel();

    _popularScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || popularProducts.isEmpty) {
        timer.cancel();
        return;
      }
      try {
        if (_popularScrollController.hasClients) {
          final current = _popularScrollController.offset;
          final max = _popularScrollController.position.maxScrollExtent;
          const step = 96.0;
          double next = current + step;
          if (next >= max * 0.75) {
            final base = popularProducts.take(6).length;
            final jump = current % (base * 96.0);
            _popularScrollController.jumpTo(jump);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _popularScrollController.hasClients) {
                _popularScrollController.animateTo(jump + step,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut);
              }
            });
          } else {
            _popularScrollController.animateTo(next,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut);
          }
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _popularScrollTimer?.cancel();
    _popularScrollController.dispose();
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
    // On resume: clear search only — do NOT reload data
    if (state == AppLifecycleState.resumed && mounted) {
      _clearSearch();
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<bool> requireAuth(BuildContext context) async {
    if (await AuthService.isLoggedIn()) return true;
    if (!context.mounted) return false;
    final result = await Navigator.push<bool>(
      context,
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

  // ─── Welcome / notification ────────────────────────────────────────────────
  Future<void> _checkAndShowWelcomeMessage() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_shown_welcome_message') ?? false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _showWelcomePage();
        await prefs.setBool('has_shown_welcome_message', true);
      }
    });
  }

  Future<void> _showWelcomePage() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  const SizedBox(height: 20),
                  Image.asset('assets/images/png.png',
                      height: 50, fit: BoxFit.contain),
                  const SizedBox(height: 20),
                  Text('Welcome',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: Colors.grey.shade900,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Text('ERNEST CHEMIST LIMITED',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 40),
                  Text(
                      "We appreciate you choosing us for your health and wellness essentials.",
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Colors.grey.shade700),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(
                      "Thank you. Remember, we are always ready to assist the best way possible.",
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.grey.shade600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 50),
                  Container(
                      width: 60,
                      height: 2,
                      decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Your health, our priority',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _showNotificationPermissionIfNeeded();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('Get Started',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
  }

  Future<void> _showNotificationPermissionIfNeeded() async {
    try {
      if (!mounted) return;
      final status = await Permission.notification.status;
      if (!mounted) return;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const NotificationPermissionPage()));
      }
    } catch (e) {
      debugPrint('Error showing notification permission: $e');
    }
  }

  // ─── Snackbar ──────────────────────────────────────────────────────────────
  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration}) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.green[900],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(duration ?? const Duration(seconds: 2), entry.remove);
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
                    "Hello! I need help with the ECL app. Can you assist me?");
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
                    'support@ernestchemists.com', 'ECL App Support & Inquiry');
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Email copied to clipboard'),
                    ]),
                    backgroundColor: Colors.green.shade600,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  ));
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
    if (_isLoadingCategories || !mounted) return;
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
    final shouldShowSkeleton = _isLoading && _products.isEmpty;
    return Scaffold(
      body: Stack(children: [
        shouldShowSkeleton ? _buildSkeletonWithLoading() : _buildMainContent(),
        const SmartTips(),
      ]),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(children: [
      const HomePageSkeletonBody(),
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
              const Text('Loading your products...',
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

        return SmartRefresher(
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
                  child: _buildCategoryScroll(isTablet: isTablet)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
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
              // Popular Products header
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
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
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Popular Products',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1)),
                      ),
                    ]),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                  child: _buildPopularProducts(isTablet: isTablet)),
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
        );
      }),
    );
  }

  // ─── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar({bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 50 : 40,
          isTablet ? 24 : 16, isTablet ? 12 : 8),
      child: SizedBox(
        height: isTablet ? 56 : 48,
        child: Builder(builder: (context) {
          if (!mounted) return const SizedBox.shrink();
          try {
            return SafeTypeAheadField(
              controller: _searchController,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SearchResultsPage(
                            query: value.trim(), products: _products)),
                  ).then((_) => _clearSearch());
                }
              },
              suggestionsCallback: (pattern) async {
                if (pattern.isEmpty || !mounted) return [];
                try {
                  final response = await http
                      .get(Uri.parse(ApiConfig.getSearchUrl(pattern)))
                      .timeout(const Duration(seconds: 10));
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    final List productsData = data['data'] ?? [];
                    final products = productsData.map<Product>((item) {
                      return Product(
                        id: item['id'] ?? 0,
                        name: item['name'] ?? 'No name',
                        description: item['tag_description'] ?? '',
                        urlName: item['url_name'] ?? '',
                        status: item['status'] ?? '',
                        batch_no: item['batch_no'] ?? '',
                        price: (item['price'] ?? item['selling_price'] ?? 0)
                            .toString(),
                        thumbnail: item['thumbnail'] ?? item['image'] ?? '',
                        quantity: item['quantity']?.toString() ?? '',
                        category: item['category'] ?? '',
                        route: item['route'] ?? '',
                      );
                    }).toList();
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
                  }
                  return [];
                } on TimeoutException {
                  return [];
                } on http.ClientException {
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SearchResultsPage(
                                  query: _searchController.text,
                                  products: _products)),
                        ).then((_) => _clearSearch());
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ItemPage(
                                  urlName: m.urlName.isNotEmpty
                                      ? m.urlName
                                      : suggestion.urlName,
                                  isPrescribed:
                                      m.otcpom?.toLowerCase() == 'pom')),
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
                                if (suggestion.price.isNotEmpty &&
                                    suggestion.price != '0')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('GH₵ ${suggestion.price}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green[700])),
                                  ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SearchResultsPage(
                            query: _searchController.text,
                            products: _products)),
                  ).then((_) => _clearSearch());
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ItemPage(
                            urlName: m.urlName.isNotEmpty
                                ? m.urlName
                                : suggestion.urlName,
                            isPrescribed: m.otcpom?.toLowerCase() == 'pom')),
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
              debounceDuration: const Duration(milliseconds: 10),
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
    );
  }

  // ─── Category scroll ───────────────────────────────────────────────────────
  Widget _buildCategoryScroll({bool isTablet = false}) {
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
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.categoryPage),
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
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 18),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final categoryName = category['name'] ?? '';
              final hasSubcategories = category['has_subcategories'] ?? false;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (hasSubcategories) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SubcategoryPage(
                                  categoryName: categoryName,
                                  categoryId: category['id'])),
                        );
                      } else {
                        Navigator.push(
                          context,
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
    ]);
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
              Text('GET DEAL 10% OFF ON FIRST PURCHASE',
                  style: GoogleFonts.poppins(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Text('Orders above GH₵100.',
                  style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  'Make purchase through the Ernest Chemists e-commerce platform and get a 10% discount of your first purchase.',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 11, height: 1.3)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }

  // ─── Popular products ──────────────────────────────────────────────────────
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
          message: 'No popular products available', icon: Icons.star_border);
    }

    final baseProducts = popularProducts.take(6).toList();
    final infiniteProducts = <Product>[];
    for (int i = 0; i < 10; i++) {
      infiniteProducts.addAll(baseProducts);
    }

    return Container(
      height: isTablet ? 80 : 120,
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        controller: _popularScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: infiniteProducts.length,
        padding: const EdgeInsets.only(right: 2),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final product = infiniteProducts[index];
          final currentOffset = _popularScrollController.hasClients
              ? _popularScrollController.offset
              : 0.0;
          final isInCenter = ((index * 82.0) - currentOffset).abs() < 48.0;

          return AnimatedScale(
            scale: isInCenter ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(top: isInCenter ? 8.0 : 0.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: SizedBox(
                  width: isTablet ? 100 : 80,
                  child: HomeProductCard(
                    product: product,
                    fontSize: isTablet ? 16 : 15,
                    padding: 0,
                    imageHeight: isTablet ? 80 : 100,
                    showWishlistButton: false,
                    showPrice: false,
                    showName: false,
                    showHero: false,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
              final key = title.toLowerCase();
              final filtered = _products.where((p) {
                switch (key) {
                  case 'wellness':
                    return p.wellness?.toLowerCase() == 'wellness';
                  case 'selfcare':
                    return p.selfcare?.toLowerCase() == 'selfcare';
                  case 'accessories':
                    return p.accessories?.toLowerCase() == 'accessories';
                  case 'drugs':
                  case 'drug':
                    return p.drug?.toLowerCase() == 'drug';
                  case 'otc':
                    return p.otcpom?.toLowerCase() == 'otc';
                  default:
                    return p.category.toLowerCase() == key;
                }
              }).toList();
              Navigator.push(
                context,
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
          key: ValueKey(products[index].id),
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

// ─── Order / Banner card ───────────────────────────────────────────────────────
Widget buildOrderMedicineCard() => const _OrderMedicineCard();

class _OrderMedicineCard extends StatefulWidget {
  const _OrderMedicineCard();

  @override
  State<_OrderMedicineCard> createState() => _OrderMedicineCardState();
}

class _OrderMedicineCardState extends State<_OrderMedicineCard> {
  List<BannerModel> banners = [];
  bool _isLoadingBanners = false;
  final BannerCacheService _bannerCacheService = BannerCacheService();

  @override
  void initState() {
    super.initState();
    _initializeBannerCache();
  }

  Future<void> _initializeBannerCache() async {
    await _bannerCacheService.initialize();
    fetchBanners();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBanners) {
      return Container(
          height: 140,
          alignment: Alignment.center,
          child: const CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final bannerHeight = isTablet ? 220.0 : 140.0;

    final bannerData = [
      _BannerData(
          image: 'assets/images/banner1.jpg',
          headline: 'Your Health, Our Priority',
          subtitle: 'Shop medicines, wellness, and more with confidence.'),
      _BannerData(
          image: 'assets/images/banner2.jpg',
          headline: 'Fast Delivery, Trusted Service',
          subtitle: 'Get your essentials delivered quickly and safely.'),
    ];

    const infiniteOffset = 10000;
    int activeBanner = 0;
    final pageController =
        PageController(initialPage: infiniteOffset, viewportFraction: 0.88);

    void startAutoScroll() {
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted || !pageController.hasClients) return;
        pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
        startAutoScroll();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => startAutoScroll());

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: bannerHeight,
        child: PageView.builder(
          controller: pageController,
          onPageChanged: (i) =>
              setState(() => activeBanner = i % bannerData.length),
          itemBuilder: (context, index) {
            final data = bannerData[index % bannerData.length];
            return AnimatedBuilder(
              animation: pageController,
              builder: (context, child) {
                double value = 0;
                if (pageController.position.haveDimensions) {
                  value = pageController.page! - index;
                }
                value = value.clamp(-1.0, 1.0);
                final scale = 1 - (0.15 * value.abs());
                final angle = value * 0.18;
                final translateX = value * (isTablet ? 40 : 24);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(translateX)
                    ..scale(scale, scale)
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: Container(
                    margin: EdgeInsets.symmetric(
                        horizontal: isTablet ? 2 : 1, vertical: 2),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.13),
                              blurRadius: isTablet ? 10 : 7,
                              offset: Offset(0, isTablet ? 4 : 2))
                        ]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset(data.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                    child: Icon(Icons.broken_image,
                                        size: 40, color: Colors.grey[400])))),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: bannerHeight * 0.45,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent
                                  ]),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 22,
                          right: 20,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data.headline,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isTablet ? 18 : 14.5,
                                        shadows: [
                                          Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2))
                                        ])),
                                const SizedBox(height: 5),
                                Text(data.subtitle,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.92),
                                        fontWeight: FontWeight.w400,
                                        fontSize: isTablet ? 13 : 10.5,
                                        height: 1.3,
                                        shadows: [
                                          Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1))
                                        ])),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(bannerData.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: activeBanner == i ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
                color: activeBanner == i
                    ? Colors.white.withOpacity(0.95)
                    : Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8)),
          );
        }),
      ),
    ]);
  }

  Future<void> fetchBanners() async {
    if (!mounted) return;
    try {
      final cached = await _bannerCacheService.getBanners();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          banners = cached;
          _isLoadingBanners = false;
        });
        _bannerCacheService.preloadBannerImages(context);
      }
    } catch (_) {}
    _refreshBannersInBackground();
  }

  Future<void> _refreshBannersInBackground() async {
    try {
      final fresh = await _bannerCacheService.getBanners();
      if (mounted && fresh.isNotEmpty) setState(() => banners = fresh);
    } catch (_) {}
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────
String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return ApiConfig.getProductImageUrl(url);
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
        openBuilder: (context, _) => ItemPage(
          urlName: widget.product.urlName,
          isPrescribed: widget.product.otcpom?.toLowerCase() == 'pom',
        ),
        closedBuilder: (context, openContainer) => HomeProductCard(
          product: widget.product,
          fontSize: widget.fontSize,
          padding: widget.padding,
          imageHeight: widget.imageHeight,
          showWishlistButton: true,
          onTap: () => WidgetsBinding.instance
              .addPostFrameCallback((_) => openContainer()),
          showHero: false,
        ),
      ),
    );
  }
}
