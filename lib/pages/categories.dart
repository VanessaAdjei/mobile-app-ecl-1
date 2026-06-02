// pages/categories.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eclapp/pages/itemdetail.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/app_back_button.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/config/api_config.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../utils/app_error_utils.dart';
import '../utils/product_detail_parser.dart';
import '../widgets/error_display.dart';
import 'package:eclapp/pages/bulk_purchase_page.dart';
import 'package:eclapp/pages/bottomnav.dart';
import '../services/category_optimization_service.dart';
import '../services/category_catalog_service.dart';
import '../cache/product_catalog_memory.dart';
import 'package:flutter/foundation.dart';
import 'package:animations/animations.dart';

/// List/subcategory APIs often send `url_name` or `slug`; [ItemPage] needs that slug.
/// Skips full `http` URLs so we do not pass an image URL as [urlName].
String? slugForProductDetailPage(dynamic product) {
  if (product is! Map) return null;
  final p = Map<String, dynamic>.from(product);
  String? pick(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return null;
    return s;
  }

  for (final key in <String>[
    'urlname',
    'url_name',
    'slug',
    'url_slug',
    'permalink',
  ]) {
    final v = pick(p[key]);
    if (v != null) return v;
  }

  final fromUrl = slugFromProductLink(p['url']?.toString());
  if (fromUrl != null) return fromUrl;

  final inv = p['inventory'];
  if (inv is Map) {
    final im = Map<String, dynamic>.from(inv);
    for (final key in <String>['urlname', 'url_name', 'slug']) {
      final v = pick(im[key]);
      if (v != null) return v;
    }
  }

  final nested = p['product'];
  if (nested is Map) {
    final pm = Map<String, dynamic>.from(nested);
    for (final key in <String>['urlname', 'url_name', 'slug']) {
      final v = pick(pm[key]);
      if (v != null) return v;
    }
  }

  final route = pick(p['route']);
  if (route != null) {
    final fromRoute = slugFromProductLink(route);
    if (fromRoute != null) return fromRoute;
    if (route.contains('/')) {
      final segs = route.split('/').where((s) => s.trim().isNotEmpty).toList();
      if (segs.isNotEmpty) return segs.last;
    }
  }

  return null;
}

int? _parseIntId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// Subcategory list rows often omit `url_name`; fill from catalog maps (product id / name).
void mergeUrlNameFromCatalogMaps(
  List<dynamic> items,
  Map<int, String> urlByProductId,
  Map<String, String> urlByNameLower,
) {
  for (var i = 0; i < items.length; i++) {
    final raw = items[i];
    if (raw is! Map) continue;
    final p = Map<String, dynamic>.from(raw);
    if (slugForProductDetailPage(p) != null) continue;

    String? found;
    for (final key in <String>['id', 'product_id', 'inventory_id']) {
      final id = _parseIntId(p[key]);
      if (id != null) {
        final u = urlByProductId[id];
        if (u != null && u.isNotEmpty) {
          found = u;
          break;
        }
      }
    }
    if (found == null || found.isEmpty) {
      final nested = p['product'];
      if (nested is Map) {
        final nm = Map<String, dynamic>.from(nested);
        for (final key in <String>['id', 'product_id']) {
          final id = _parseIntId(nm[key]);
          if (id != null) {
            final u = urlByProductId[id];
            if (u != null && u.isNotEmpty) {
              found = u;
              break;
            }
          }
        }
      }
    }
    if (found == null || found.isEmpty) {
      final name = p['name']?.toString().toLowerCase().trim();
      if (name != null && name.isNotEmpty) {
        found = urlByNameLower[name];
      }
    }
    if (found != null && found.isNotEmpty) {
      p['url_name'] = found;
      items[i] = p;
    }
  }
}

/// Lookup maps from disk/memory catalog caches (no network).
CatalogLookupMaps buildLocalCatalogLookupMaps() {
  final otcpomByNameLower = <String, String?>{};
  final urlByProductId = <int, String>{};
  final urlByNameLower = <String, String>{};

  void absorb(int id, String name, String urlName, String? otcpom) {
    final nameLower = name.toLowerCase().trim();
    if (nameLower.isNotEmpty) {
      otcpomByNameLower[nameLower] = otcpom;
    }
    if (urlName.isEmpty) return;
    urlByProductId[id] = urlName;
    if (nameLower.isNotEmpty) {
      urlByNameLower[nameLower] = urlName;
    }
  }

  for (final p in ProductCatalogMemory.products) {
    absorb(p.id, p.name, p.urlName, p.otcpom);
  }
  for (final p in ProductCache.cachedProducts) {
    absorb(p.id, p.name, p.urlName, p.otcpom);
  }
  for (final raw in CategoryCache.cachedAllProducts) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final id = _parseIntId(m['id']);
    if (id == null) continue;
    absorb(
      id,
      m['name']?.toString() ?? '',
      m['url_name']?.toString().trim() ?? '',
      m['otcpom']?.toString(),
    );
  }

  return CatalogLookupMaps(
    otcpomByNameLower: otcpomByNameLower,
    urlByProductId: urlByProductId,
    urlByNameLower: urlByNameLower,
  );
}

String? _lookupUrlNameInMaps(
  int? id,
  String? nameLower,
  Map<int, String> urlByProductId,
  Map<String, String> urlByNameLower,
) {
  if (id != null) {
    final byId = urlByProductId[id];
    if (byId != null && byId.isNotEmpty) return byId;
  }
  if (nameLower != null && nameLower.isNotEmpty) {
    final byName = urlByNameLower[nameLower];
    if (byName != null && byName.isNotEmpty) return byName;
  }
  return null;
}

int? _productRowId(dynamic product) {
  if (product is! Map) return null;
  Map<String, dynamic>? nestedProduct;
  final np = product['product'];
  if (np is Map<String, dynamic>) {
    nestedProduct = np;
  } else if (np is Map) {
    nestedProduct = Map<String, dynamic>.from(np);
  }
  return _parseIntId(product['id']) ??
      _parseIntId(product['product_id']) ??
      (nestedProduct != null
          ? _parseIntId(nestedProduct['id']) ??
              _parseIntId(nestedProduct['product_id'])
          : null);
}

/// Detail API uses slug path segments, not numeric product ids.
String? resolveProductDetailUrlName(dynamic product) {
  bool validSlug(String? s) {
    if (s == null) return false;
    final t = s.trim();
    if (t.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(t)) return false;
    return true;
  }

  final s = slugForProductDetailPage(product);
  if (s != null && validSlug(s)) return s.trim();

  if (product is! Map) return null;

  final name = product['name']?.toString().toLowerCase().trim();
  final id = _productRowId(product);
  final local = buildLocalCatalogLookupMaps();
  final fromLocal = _lookupUrlNameInMaps(
    id,
    name,
    local.urlByProductId,
    local.urlByNameLower,
  );
  if (fromLocal != null) return fromLocal;

  return null;
}

Future<bool> mergeProductSlugsFromNetwork(
  List<dynamic> products,
  CategoryCatalogService catalogService, {
  bool throwIfEmpty = false,
}) async {
  try {
    final maps = await catalogService.buildCatalogLookupMaps(
      timeout: const Duration(seconds: 15),
    );
    if (maps.urlByProductId.isEmpty && maps.urlByNameLower.isEmpty) {
      if (throwIfEmpty) {
        throw Exception('Catalog lookup returned no product links');
      }
      return false;
    }
    mergeUrlNameFromCatalogMaps(
      products,
      maps.urlByProductId,
      maps.urlByNameLower,
    );
    return true;
  } catch (e, st) {
    AppErrorUtils.log('mergeProductSlugsFromNetwork', e, st);
    if (throwIfEmpty) rethrow;
    return false;
  }
}

class _ProductOpenResult {
  const _ProductOpenResult({
    this.page,
    required this.kind,
    this.error,
  });

  final ItemPage? page;
  final ProductDetailErrorKind kind;
  final Object? error;
}

/// Resolves product slug then opens [ItemPage]; fetches catalog if needed.
class _CategoryProductDetailRoute extends StatefulWidget {
  const _CategoryProductDetailRoute({required this.product});

  final dynamic product;

  @override
  State<_CategoryProductDetailRoute> createState() =>
      _CategoryProductDetailRouteState();
}

class _CategoryProductDetailRouteState
    extends State<_CategoryProductDetailRoute> {
  final CategoryCatalogService _catalogService = CategoryCatalogService();
  late final String? _productName;
  late final bool _isPrescribed;
  late Future<_ProductOpenResult> _openResultFuture;

  @override
  void initState() {
    super.initState();
    _productName =
        widget.product is Map ? widget.product['name']?.toString() : null;
    _isPrescribed = widget.product is Map &&
        widget.product['otcpom']?.toString().toLowerCase() == 'pom';
    _openResultFuture = _resolveProduct();
  }

  void _retry() {
    setState(() {
      _openResultFuture = _resolveProduct();
    });
  }

  Future<_ProductOpenResult> _resolveProduct() async {
    String? slug = resolveProductDetailUrlName(widget.product);
    if (slug != null && slug.isNotEmpty) {
      return _ProductOpenResult(
        page: ItemPage(urlName: slug, isPrescribed: _isPrescribed),
        kind: ProductDetailErrorKind.unknown,
      );
    }

    if (!ProductCache.hasProductsInMemory) {
      await ProductCache.loadFromStorage();
      slug = resolveProductDetailUrlName(widget.product);
      if (slug != null && slug.isNotEmpty) {
        return _ProductOpenResult(
          page: ItemPage(urlName: slug, isPrescribed: _isPrescribed),
          kind: ProductDetailErrorKind.unknown,
        );
      }
    }

    if (widget.product is Map) {
      try {
        final list = [widget.product];
        await mergeProductSlugsFromNetwork(
          list,
          _catalogService,
          throwIfEmpty: true,
        );
        slug = resolveProductDetailUrlName(list.first);
        if (slug != null && slug.isNotEmpty) {
          return _ProductOpenResult(
            page: ItemPage(urlName: slug, isPrescribed: _isPrescribed),
            kind: ProductDetailErrorKind.unknown,
          );
        }
      } catch (e, st) {
        AppErrorUtils.log('CategoryProductDetailRoute.resolve', e, st);
        return _ProductOpenResult(
          kind: AppErrorUtils.classifyProductError(e),
          error: e,
        );
      }
    }

    return const _ProductOpenResult(
      kind: ProductDetailErrorKind.unavailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProductOpenResult>(
      future: _openResultFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opening product…',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data;
        if (result?.page != null) return result!.page!;

        final kind = result?.kind ?? ProductDetailErrorKind.unknown;
        return _productDetailOpenErrorScaffold(
          context,
          kind: kind,
          productName: _productName,
          error: result?.error,
          onRetry: _retry,
        );
      },
    );
  }
}

Widget _productDetailOpenErrorScaffold(
  BuildContext context, {
  required ProductDetailErrorKind kind,
  String? productName,
  Object? error,
  VoidCallback? onRetry,
}) {
  final message = error != null
      ? AppErrorUtils.productDetailMessageFromError(
          error,
          productName: productName,
        )
      : AppErrorUtils.productDetailMessage(kind, productName: productName);

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text('Product'),
    ),
    body: ErrorDisplay(
      title: AppErrorUtils.productDetailTitle(kind),
      message: message,
      icon: AppErrorUtils.productDetailIcon(kind),
      showRetry: onRetry != null,
      onRetry: onRetry,
      actionText: 'Go back',
      onAction: () => Navigator.of(context).maybePop(),
    ),
  );
}

Widget _buildCatalogErrorPanel({
  required String errorMessage,
  required VoidCallback onRetry,
}) {
  final kind = AppErrorUtils.classifyProductError(errorMessage);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppErrorUtils.productDetailIcon(kind),
            size: 64,
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            AppErrorUtils.catalogLoadTitle(kind),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppErrorUtils.catalogLoadMessage(kind, detail: errorMessage),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

// cache categories and products so we dont have to load them every time
class CategoryCache {
  static List<dynamic> _cachedCategories = [];
  static List<dynamic> _cachedAllProducts = [];
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 60);

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  static void cacheCategories(List<dynamic> categories) {
    _cachedCategories = categories;
    _lastCacheTime = DateTime.now();
  }

  static void cacheAllProducts(List<dynamic> products) {
    _cachedAllProducts = products;
    _lastCacheTime = DateTime.now();
  }

  static List<dynamic> get cachedCategories => _cachedCategories;
  static List<dynamic> get cachedAllProducts => _cachedAllProducts;

  static void clearCache() {
    _cachedCategories.clear();
    _cachedAllProducts.clear();
    _lastCacheTime = null;
  }
}

// cache search results so they stay when you navigate away
class SearchResultCache {
  static dynamic _searchedProduct;

  static void storeSearchedProduct(dynamic product) {
    _searchedProduct = product;
  }

  static dynamic getSearchedProduct() {
    return _searchedProduct;
  }

  static void clear() {
    _searchedProduct = null;
  }
}

// load category images ahead of time so they show up fast
class CategoryImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  static void preloadImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty || _preloadedImages.containsKey(imageUrl)) return;

    _preloadedImages[imageUrl] = true;
    precacheImage(
      CachedNetworkImageProvider(
        imageUrl,
        maxWidth: 300,
        maxHeight: 300,
      ),
      context,
      onError: (exception, stackTrace) {
        debugPrint(
            'Skipping category preload image (may be missing): $imageUrl');
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

class CategoryPage extends StatefulWidget {
  final bool isBulkPurchase;

  const CategoryPage({super.key, this.isBulkPurchase = false});

  @override
  CategoryPageState createState() => CategoryPageState();
}

class CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Map<int, bool> _categoryHasSubcategories = {};
  Timer? _highlightTimer;
  List<dynamic> _allProducts = [];
  bool _showSearchDropdown = false;
  List<dynamic> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  final ScrollController _searchScrollController = ScrollController();
  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();
  final CategoryCatalogService _catalogService = CategoryCatalogService();
  final GlobalKey _searchBarKey = GlobalKey();
  final List<Map<String, dynamic>> _searchIndex = [];
  Future<void>? _searchIndexWarmupFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 CategoryPage initState() called');
    if (!ProductCache.hasProductsInMemory) {
      unawaited(ProductCache.loadFromStorage());
    }
    _initializeCategoryService();
    debugPrint('🔍 Calling _prefetchAllProducts()...');
    _searchIndexWarmupFuture =
        _prefetchAllProducts(); // Prefetch all products on page load
    _loadCategoriesOptimized();

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          _showSearchDropdown = false;
        });
      }
    });

    // print how long everything took
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _categoryService.printPerformanceSummary();
    });
  }

  Future<void> _initializeCategoryService() async {
    await _categoryService.initialize();

    // load cached data right away if we have it
    if (_categoryService.hasCachedCategories &&
        _categoryService.isCategoriesCacheValid) {
      debugPrint(
          'Using cached categories from initialization: ${_categoryService.cachedCategories.length} categories');
      setState(() {
        _categories = _categoryService.cachedCategories;
        _filteredCategories = _categoryService.cachedCategories;
        // cache is valid -> show real content right away, no skeleton wait
        _isLoading = false;
        _errorMessage = '';
      });

      // load images in the background
      _categoryService.preloadCategoryImages(
          context, _categoryService.cachedCategories);
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  // Optimized loading that checks cache first
  Future<void> _loadCategoriesOptimized() async {
    // Cache-first: if we already have valid cached categories, show them
    // immediately with no artificial delay.
    if (_categoryService.hasCachedCategories &&
        _categoryService.isCategoriesCacheValid &&
        _categories.isNotEmpty) {
      debugPrint('Skipping category loading - using existing cached data');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      debugPrint('Loading categories from service...');
      final categories = await _categoryService.getCategories();
      _processCategories(categories);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
      }

      // load images in the background
      _categoryService.preloadCategoryImages(context, categories);
    } catch (e) {
      debugPrint('Category loading error: $e');

      if (mounted) {
        setState(() {
          _errorMessage =
              AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown);
          _isLoading = false;
        });
      }
    }
  }

  // process categories and update the state
  void _processCategories(List<dynamic> categories) {
    if (!mounted) return;

    debugPrint('Processing ${categories.length} categories');
    debugPrint('Categories data: ${categories.take(3).map((c) => {
          'id': c['id'],
          'name': c['name'],
          'has_subcategories': c['has_subcategories']
        }).toList()}');

    // update subcategory mapping based on what the api actually sends
    _updateSubcategoryMapping(categories);

    setState(() {
      _categories = categories;
      _filteredCategories = categories;
    });

    debugPrint('Categories state updated: ${_categories.length} categories');
    debugPrint('Filtered categories: ${_filteredCategories.length} categories');
  }

  // update subcategory mapping based on what the api sends
  void _updateSubcategoryMapping(List<dynamic> categories) {
    for (final category in categories) {
      final categoryId = category['id'];
      final categoryName = category['name'];

      // use the hardcoded mapping based on what we saw in debug logs
      // this makes sure it works the same every time
      if ([1, 2, 3, 4, 6, 7, 8, 9, 11].contains(categoryId)) {
        _categoryHasSubcategories[categoryId] = true;
        debugPrint(
            'Updated subcategory mapping for $categoryName: has subcategories = true');
      } else {
        _categoryHasSubcategories[categoryId] =
            category['has_subcategories'] ?? false;
      }
    }
  }

  // load category images ahead of time so they show up fast
  void _preloadCategoryImages(List<dynamic> categories) {
    final imageUrls = categories
        .take(10) // Preload first 10 category images
        .map((category) => _getCategoryImageUrl(category['image_url']))
        .where((url) => url.isNotEmpty)
        .toList();

    CategoryImagePreloader.preloadImages(imageUrls, context);
  }

  void _searchProduct(String query) async {
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _filteredCategories = _categories;
        _showSearchDropdown = false;
        _searchResults = [];
      });
      return;
    }

    // Show dropdown immediately when typing
    if (!_showSearchDropdown) {
      setState(() {
        _showSearchDropdown = true;
      });
    }

    // Reduced debounce for faster response
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
      await _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!_showSearchDropdown || _searchResults.isNotEmpty) {
      setState(() {
        _showSearchDropdown = true;
        _searchResults = [];
      });
    }

    try {
      debugPrint('🔍 Starting search for: $query');

      final results = await _searchAllCategories(query);
      if (!mounted || _searchController.text.trim() != query.trim()) return;

      setState(() {
        _searchResults = results.take(30).toList();
      });

      debugPrint('🔍 Search completed: Found ${_searchResults.length} results');
    } catch (e) {
      debugPrint('🔍 Search error: $e');
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<List<dynamic>> _searchAllCategories(String query) async {
    if (query.isEmpty) return [];

    final searchQuery = query.toLowerCase().trim();
    final tokens =
        searchQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return [];

    final stopwatch = Stopwatch()..start();
    await _ensureSearchIndexReady();

    // Local index unavailable (prefetch failed / catalog empty) — fall back to
    // the server search so the user still gets results.
    if (_searchIndex.isEmpty) {
      final serverResults = await _searchViaServer(query);
      debugPrint(
          '🔍 Search via server fallback: ${serverResults.length} results');
      return serverResults;
    }

    final allResults = <dynamic>[];
    for (final indexed in _searchIndex) {
      // Pre-built lowercase haystack (name + description) — every typed word
      // must appear, so multi-word queries like "para tablet" match.
      final haystack = indexed['haystack'] as String;
      var matchesAll = true;
      for (final token in tokens) {
        if (!haystack.contains(token)) {
          matchesAll = false;
          break;
        }
      }
      if (matchesAll) {
        allResults.add(indexed['product']);
        if (allResults.length >= 30) break;
      }
    }

    stopwatch.stop();
    debugPrint(
        '🔍 Search index lookup: Found ${allResults.length} products in ${stopwatch.elapsedMilliseconds}ms');
    return allResults;
  }

  Future<void> _ensureSearchIndexReady() async {
    if (_searchIndex.isNotEmpty) return;

    final cachedProducts = CategoryCache.cachedAllProducts;
    if (cachedProducts.isNotEmpty) {
      _buildSearchIndex(cachedProducts);
      return;
    }

    _searchIndexWarmupFuture ??= _prefetchAllProducts();
    await _searchIndexWarmupFuture;

    // If the catalog arrived but the index wasn't built yet, build it now.
    if (_searchIndex.isEmpty && CategoryCache.cachedAllProducts.isNotEmpty) {
      _buildSearchIndex(CategoryCache.cachedAllProducts);
    }

    // The attempt produced nothing (e.g. network failure). Clear the cached
    // future so the next search retries instead of awaiting a dead result.
    if (_searchIndex.isEmpty && CategoryCache.cachedAllProducts.isEmpty) {
      _searchIndexWarmupFuture = null;
    }
  }

  /// Server-side search fallback (same endpoint as the home search) used when
  /// the in-memory catalog index is unavailable.
  Future<List<dynamic>> _searchViaServer(String query) async {
    try {
      return await _catalogService.searchProducts(query);
    } catch (e) {
      debugPrint('🔍 Server search fallback error: $e');
      return [];
    }
  }

  void _buildSearchIndex(List<dynamic> products) {
    _searchIndex
      ..clear()
      ..addAll(products.map<Map<String, dynamic>>((product) {
        final name = product['name']?.toString() ?? '';
        final description = product['description']?.toString() ?? '';
        return {
          'product': product,
          // Pre-lowercased combined text so each keystroke is a plain substring
          // scan with no repeated allocations.
          'haystack': '$name $description'.toLowerCase(),
        };
      }));
  }

  Future<Map<String, dynamic>?> _findProductInAllCategories(
      String productName) async {
    debugPrint('🔍🔍 FAST COMPREHENSIVE SEARCH for: $productName');

    try {
      if (CategoryCache.cachedAllProducts.isNotEmpty) {
        debugPrint('🔍🔍 Checking cached products first...');

        final searchQueryLower = productName.toLowerCase();

        // try exact match first (fastest)
        for (final product in CategoryCache.cachedAllProducts) {
          final productNameLower =
              product['name']?.toString().toLowerCase() ?? '';

          if (productNameLower == searchQueryLower) {
            final categoryId = product['category_id'];
            final categoryName = product['category_name'];
            final subcategoryId = product['subcategory_id'];
            final subcategoryName = product['subcategory_name'];

            if (categoryId != null && categoryName != null) {
              return {
                'product': product,
                'category_id': categoryId,
                'category_name': categoryName,
                'subcategory_id': subcategoryId,
                'subcategory_name': subcategoryName,
                'found_in_category': true,
                'found_in_subcategory': subcategoryId != null,
              };
            }
          }
        }

        for (final product in CategoryCache.cachedAllProducts) {
          final productNameLower =
              product['name']?.toString().toLowerCase() ?? '';

          if (productNameLower.contains(searchQueryLower) ||
              searchQueryLower.contains(productNameLower)) {
            final categoryId = product['category_id'];
            final categoryName = product['category_name'];
            final subcategoryId = product['subcategory_id'];
            final subcategoryName = product['subcategory_name'];

            if (categoryId != null && categoryName != null) {
              debugPrint(
                  '🔍🔍 ULTRA-EXTREME SPEED: Partial match in cache under 20ms!');
              return {
                'product': product,
                'category_id': categoryId,
                'category_name': categoryName,
                'subcategory_id': subcategoryId,
                'subcategory_name': subcategoryName,
                'found_in_category': true,
                'found_in_subcategory': subcategoryId != null,
              };
            }
          }
        }
      }

      debugPrint(
          '🔍🔍 Not in cache, doing EXTREME-SPEED parallel search through ALL categories...');

      // get all categories
      final categories = await _categoryService.getCategories();
      debugPrint(
          '🔍🔍 EXTREME-SPEED parallel searching through ALL ${categories.length} categories');

      try {
        debugPrint('🔍🔍 ULTRA-EXTREME SPEED: Attempting batch API call...');
        final batchResult = await _tryBatchProductSearch(productName)
            .timeout(Duration(seconds: 3)); // Reasonable timeout for batch API

        if (batchResult != null) {
          debugPrint(
              '🔍🔍 ULTRA-EXTREME SPEED: Batch API success in under 150ms!');
          return batchResult;
        }
      } catch (e) {
        debugPrint('🔍🔍 Batch API failed, falling back to parallel search...');
      }

      final prioritizedCategories =
          _prioritizeCategories(categories, productName);
      debugPrint('🔍🔍 Categories prioritized by relevance to: $productName');

      List<Future<Map<String, dynamic>?>> allFutures = [];

      for (final category in prioritizedCategories) {
        final categoryId = category['id'];
        final categoryName = category['name'];
        final hasSubcategories = _categoryHasSubcategories[categoryId] ?? false;

        debugPrint(
            '🔍🔍 Starting search in category: $categoryName (ID: $categoryId)');

        if (hasSubcategories) {
          try {
            final subcategories = await _catalogService.getSubcategories(
              categoryId,
              timeout: const Duration(seconds: 3),
            );

            final subcategoryFutures = subcategories.map((subcategory) async {
              final subcategoryId = subcategory['id'];
              final subcategoryName = subcategory['name'];

              try {
                final products = await _catalogService.getSubcategoryProducts(
                  subcategoryId,
                  timeout: const Duration(seconds: 3),
                );

                for (final product in products) {
                  final productNameLower =
                      product['name']?.toString().toLowerCase() ?? '';
                  final searchQueryLower = productName.toLowerCase();

                  if (productNameLower == searchQueryLower ||
                      productNameLower.contains(searchQueryLower) ||
                      searchQueryLower.contains(productNameLower)) {
                    debugPrint(
                        '🔍🔍 FOUND: ${product['name']} in $categoryName > $subcategoryName');

                    return {
                      'product': product,
                      'category_id': categoryId,
                      'category_name': categoryName,
                      'subcategory_id': subcategoryId,
                      'subcategory_name': subcategoryName,
                      'found_in_category': true,
                      'found_in_subcategory': true,
                    };
                  }
                }
              } catch (e) {
                // skip subcategories that failed
              }
              return null;
            });

            allFutures.addAll(subcategoryFutures);
          } catch (e) {
            debugPrint('🔍🔍 Error in category $categoryId: $e');
          }
        } else {
          // search directly in category super fast
          final categoryFuture = (() async {
            try {
              final products = await _catalogService.getSubcategoryProducts(
                categoryId,
                timeout: const Duration(seconds: 3),
              );

              if (products.isNotEmpty) {
                for (final product in products) {
                  final productNameLower =
                      product['name']?.toString().toLowerCase() ?? '';
                  final searchQueryLower = productName.toLowerCase();

                  if (productNameLower == searchQueryLower ||
                      productNameLower.contains(searchQueryLower) ||
                      searchQueryLower.contains(productNameLower)) {
                    debugPrint(
                        '🔍🔍 FOUND: ${product['name']} in $categoryName');

                    return {
                      'product': product,
                      'category_id': categoryId,
                      'category_name': categoryName,
                      'found_in_category': true,
                      'found_in_subcategory': false,
                    };
                  }
                }
              }
            } catch (e) {
              debugPrint('🔍🔍 Error in category $categoryId: $e');
            }
            return null;
          })();

          allFutures.add(categoryFuture);
        }
      }

      // now wait for any result from any category/subcategory super fast
      debugPrint(
          '🔍🔍 Waiting for ANY result from ${allFutures.length} parallel searches...');

      // use Future.any to get the fastest result with a super short timeout
      try {
        final result = await Future.any(allFutures)
            .timeout(
                Duration(seconds: 5)); // Reasonable timeout for parallel search
        if (result != null) {
          debugPrint('🔍🔍 EXTREME SPEED: Result found in under 500ms!');
          return result;
        }
      } catch (e) {
        debugPrint(
            '🔍🔍 EXTREME SPEED: Future.any timeout, trying sequential fallback...');
      }

      // if that didnt work, check each future with minimal wait
      for (final future in allFutures) {
        try {
          final result = await future
              .timeout(Duration(seconds: 2)); // Reasonable timeout per future
          if (result != null) {
            debugPrint(
                '🔍🔍 EXTREME SPEED: Result found in sequential fallback!');
            return result;
          }
        } catch (e) {
          // Continue to next future
        }
      }

      debugPrint('🔍🔍 FAST COMPREHENSIVE SEARCH COMPLETED: Product not found');
      return null;
    } catch (e) {
      debugPrint('🔍🔍 FAST COMPREHENSIVE SEARCH ERROR: $e');
      return null;
    }
  }

  // Smart category prioritization for faster search results
  List<dynamic> _prioritizeCategories(
      List<dynamic> categories, String productName) {
    final productNameLower = productName.toLowerCase();
    final prioritized = List<dynamic>.from(categories);

    // Sort categories by relevance to the product name
    prioritized.sort((a, b) {
      final aName = a['name']?.toString().toLowerCase() ?? '';
      final bName = b['name']?.toString().toLowerCase() ?? '';

      // Check for exact matches first
      if (aName.contains(productNameLower) && !bName.contains(productNameLower))
        return -1;
      if (!aName.contains(productNameLower) && bName.contains(productNameLower))
        return 1;

      // Check for partial matches
      if (aName.contains(productNameLower.substring(0, 3)) &&
          !bName.contains(productNameLower.substring(0, 3))) return -1;
      if (!aName.contains(productNameLower.substring(0, 3)) &&
          bName.contains(productNameLower.substring(0, 3))) return 1;

      // Prioritize common categories that usually have products
      final commonCategories = [
        'medicines',
        'personal care',
        'health care devices',
        'mother & baby'
      ];
      final aIsCommon = commonCategories.any((cat) => aName.contains(cat));
      final bIsCommon = commonCategories.any((cat) => bName.contains(cat));

      if (aIsCommon && !bIsCommon) return -1;
      if (!aIsCommon && bIsCommon) return 1;

      return 0;
    });

    debugPrint(
        '🔍🔍 Category priority: ${prioritized.map((c) => c['name']).toList()}');
    return prioritized;
  }

  // EXTREME SPEED: Batch API search for instant results
  Future<Map<String, dynamic>?> _tryBatchProductSearch(
      String productName) async {
    try {
      final dataList = await _catalogService.getRawCatalogItems(
        timeout: const Duration(seconds: 3),
      );
      final searchQuery = productName.toLowerCase();

      for (final item in dataList) {
        final productData = item['product'] as Map<String, dynamic>;
        final productNameLower =
            productData['name']?.toString().toLowerCase() ?? '';

        if (productNameLower == searchQuery ||
            productNameLower.contains(searchQuery) ||
            searchQuery.contains(productNameLower)) {
          final categoryId = item['category_id'];
          final categoryName = item['category_name'];
          final subcategoryId = item['subcategory_id'];
          final subcategoryName = item['subcategory_name'];

          if (categoryId != null && categoryName != null) {
            debugPrint(
                '🔍🔍 EXTREME SPEED: Batch API found: ${productData['name']} in $categoryName');
            return {
              'product': productData,
              'category_id': categoryId,
              'category_name': categoryName,
              'subcategory_id': subcategoryId,
              'subcategory_name': subcategoryName,
              'found_in_category': true,
              'found_in_subcategory': subcategoryId != null,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('🔍🔍 Batch API error: $e');
    }
    return null;
  }

  String _getCategoryImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return ApiConfig.getStorageUrl(imagePath);
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';

    // Convert to double if it's a string
    double? numericPrice;
    if (price is String) {
      numericPrice = double.tryParse(price);
    } else if (price is int) {
      numericPrice = price.toDouble();
    } else if (price is double) {
      numericPrice = price;
    }

    if (numericPrice == null) return '0.00';
    return numericPrice.toStringAsFixed(2);
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();

    // Pharmacy and Medicine categories
    if (name.contains('drug') ||
        name.contains('medicine') ||
        name.contains('medication')) {
      return Icons.medication;
    } else if (name.contains('otc') || name.contains('over the counter')) {
      return Icons.local_pharmacy;
    } else if (name.contains('prescription') || name.contains('pom')) {
      return Icons.medical_services;
    }

    // Health and Wellness categories
    else if (name.contains('health') || name.contains('wellness')) {
      return Icons.health_and_safety;
    } else if (name.contains('vitamin') || name.contains('supplement')) {
      return Icons.medication;
    } else if (name.contains('nutrition') || name.contains('diet')) {
      return Icons.restaurant;
    }

    // Personal Care categories
    else if (name.contains('personal') || name.contains('care')) {
      return Icons.person;
    } else if (name.contains('beauty') || name.contains('cosmetic')) {
      return Icons.face;
    } else if (name.contains('skin') || name.contains('dermatology')) {
      return Icons.face_retouching_natural;
    } else if (name.contains('hair') || name.contains('shampoo')) {
      return Icons.content_cut;
    }

    // Hygiene and Sanitation
    else if (name.contains('sanitary') || name.contains('hygiene')) {
      return Icons.cleaning_services;
    } else if (name.contains('soap') || name.contains('wash')) {
      return Icons.cleaning_services;
    } else if (name.contains('toilet') || name.contains('bathroom')) {
      return Icons.bathroom;
    }

    // Maternal and Child Care
    else if (name.contains('baby') ||
        name.contains('infant') ||
        name.contains('child')) {
      return Icons.child_care;
    } else if (name.contains('mother') ||
        name.contains('maternal') ||
        name.contains('pregnancy')) {
      return Icons.pregnant_woman;
    } else if (name.contains('diaper') || name.contains('nappy')) {
      return Icons.child_care;
    }

    // Sexual Health
    else if (name.contains('sexual') ||
        name.contains('intimate') ||
        name.contains('condom')) {
      return Icons.favorite;
    }

    // Fitness and Sports
    else if (name.contains('sports') ||
        name.contains('fitness') ||
        name.contains('exercise')) {
      return Icons.sports;
    }

    // Medical Equipment and Accessories
    else if (name.contains('accessory') ||
        name.contains('equipment') ||
        name.contains('device')) {
      return Icons.medical_services;
    } else if (name.contains('thermometer') || name.contains('temperature')) {
      return Icons.thermostat;
    } else if (name.contains('bandage') || name.contains('plaster')) {
      return Icons.healing;
    }

    // Specific Health Conditions
    else if (name.contains('diabetes') || name.contains('blood')) {
      return Icons.monitor_heart;
    } else if (name.contains('heart') || name.contains('cardio')) {
      return Icons.favorite;
    } else if (name.contains('eye') ||
        name.contains('vision') ||
        name.contains('glasses')) {
      return Icons.visibility;
    } else if (name.contains('dental') ||
        name.contains('oral') ||
        name.contains('tooth')) {
      return Icons.medical_services;
    } else if (name.contains('ear') ||
        name.contains('nose') ||
        name.contains('throat')) {
      return Icons.hearing;
    }

    // Pain and Relief
    else if (name.contains('pain') ||
        name.contains('ache') ||
        name.contains('relief')) {
      return Icons.healing;
    } else if (name.contains('cough') ||
        name.contains('cold') ||
        name.contains('flu')) {
      return Icons.air;
    } else if (name.contains('fever') || name.contains('temperature')) {
      return Icons.thermostat;
    }

    // Self Care and Wellness
    else if (name.contains('self care') || name.contains('selfcare')) {
      return Icons.spa;
    } else if (name.contains('mental') || name.contains('stress')) {
      return Icons.psychology;
    }

    // Sports Nutrition (specific category - must come before general nutrition)
    else if (name.contains('sports nutrition') ||
        name.contains('sportsnutrition')) {
      return Icons.sports;
    }

    // Food and Nutrition
    else if (name.contains('food') ||
        name.contains('nutrition') ||
        name.contains('diet')) {
      return Icons.restaurant;
    }

    // Default fallback
    else {
      return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (widget.isBulkPurchase) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const BulkPurchasePage(),
            ),
          );
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }
      },
      child: Scaffold(
        appBar: null,
        backgroundColor: const Color(0xFFF6F8FA),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                EclExpandableSliverAppBar(
                  toolbarTitle: 'Shop',
                  heroTitle: 'Shop',
                  heroSubtitle: 'Browse all products',
                  centerTitle: false,
                  onBack: () {
                    if (widget.isBulkPurchase) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BulkPurchasePage(),
                        ),
                      );
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    }
                  },
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const CartIconButton(
                          iconColor: Colors.white,
                          iconSize: 22,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Container(
                    key: _searchBarKey,
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF16A34A),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) {
                                setState(() {}); // Update for clear button
                                _searchProduct(value);
                              },
                              onTap: () {
                                if (_searchController.text.isNotEmpty) {
                                  setState(() {
                                    _showSearchDropdown = true;
                                  });
                                }
                              },
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search category products...",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSearchDropdown = false;
                                  _searchResults = [];
                                  _filteredCategories = _categories;
                                });
                                _searchFocusNode.unfocus();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  SliverFillRemaining(
                    // hasScrollBody: true gives the skeleton a tight
                    // remaining-extent constraint instead of measuring its
                    // intrinsic height. The skeleton contains a shrink-wrapping
                    // GridView whose viewport cannot return intrinsic
                    // dimensions, which crashed with hasScrollBody: false.
                    hasScrollBody: true,
                    child: _buildSkeletonWithLoading(),
                  )
                else
                  SliverToBoxAdapter(
                    child: _buildMainContent(),
                  ),
              ],
            ),
            // Backdrop to close search dropdown when tapping outside
            if (_showSearchDropdown)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearchDropdown = false;
                    });
                    _searchFocusNode.unfocus();
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
            // Search results dropdown - positioned below search bar (fixed position)
            if (_showSearchDropdown)
              Builder(
                builder: (context) {
                  // Use fixed position calculation that doesn't change
                  final statusBarHeight = MediaQuery.of(context).padding.top;
                  // Status bar + sliver header (~100px) + search bar padding + search bar + gap
                  final headerHeight = 100.0; // EclExpandableSliverAppBar approximate height
                  final searchBarTopPadding = 12.0;
                  final searchBarBottomPadding = 8.0;
                  final searchBarHeight = 56.0; // Approximate search bar height
                  final gap = 4.0;

                  final topPosition = statusBarHeight +
                      headerHeight +
                      searchBarTopPadding +
                      searchBarHeight +
                      searchBarBottomPadding +
                      gap;

                  return Positioned(
                    top: topPosition,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 16,
                      borderRadius: BorderRadius.circular(16),
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap from closing
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 450),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF20AF67).withOpacity(0.08),
                                      const Color(0xFF20AF67).withOpacity(0.03),
                                    ],
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20AF67),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.search_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _searchResults.isEmpty
                                            ? 'Searching...'
                                            : '${_searchResults.length} results found',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showSearchDropdown = false;
                                        });
                                        _searchFocusNode.unfocus();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Results list or empty state
                              Flexible(
                                child: _searchResults.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(30),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_off_rounded,
                                              size: 40,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No products found',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Try a different search term',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: _searchScrollController,
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        itemCount: _searchResults.length,
                                        itemBuilder: (context, index) {
                                          return _buildSearchResultItem(
                                              _searchResults[index]);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(initialIndex: 3),
      ),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        // Non-interactive scroll view so the skeleton fills the remaining
        // extent (hasScrollBody: true) without overflowing on shorter screens.
        const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: CategoryPageSkeletonBody(),
        ),
        // Add a loading indicator overlay
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading categories...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories Title
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Browse Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${_filteredCategories.length} found',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categories Grid
          _buildCategoriesGrid(),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    final productName = item['name']?.toString() ?? 'Unknown Product';
    final productImage = item['thumbnail']?.toString() ?? '';
    final productPrice = item['price']?.toString() ?? '0.00';
    final categoryName = item['category_name'];
    final subcategoryName = item['subcategory_name'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // FAST NAVIGATION: Use category/subcategory info already in search results
          final categoryId = item['category_id'];
          final categoryName = item['category_name'];
          final subcategoryId = item['subcategory_id'];
          final subcategoryName = item['subcategory_name'];
          final productId = item['id'];
          final productName = item['name'];
          final slug = item['url_name']?.toString() ?? '';

          // Clear search and hide dropdown
          setState(() {
            _searchResults = [];
            _showSearchDropdown = false;
            _searchFocusNode.unfocus();
          });

          // Fastest path: open the product detail directly (no category list to
          // load) when we have its slug.
          if (slug.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemPage(
                  urlName: slug,
                  isPrescribed:
                      item['otcpom']?.toString().toLowerCase() == 'pom',
                ),
              ),
            );
            return;
          }

          // Navigate instantly - no need to search again!
          if (categoryId != null && categoryName != null) {
            if (subcategoryId != null && subcategoryName != null) {
              // Navigate to subcategory page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubcategoryPage(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    targetSubcategoryId: subcategoryId,
                    searchedProductId: productId,
                    searchedProductName: productName,
                  ),
                ),
              );
            } else {
              // Navigate to product list page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductListPage(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    searchedProductId: productId,
                    searchedProductName: productName,
                  ),
                ),
              );
            }
          } else {
            // Fallback: If category info is missing, use the slower search method
            _navigateToProductFallback(productName);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.shade100,
                  child: productImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: productImage,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF20AF67),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (categoryName != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.category_rounded,
                            size: 13,
                            color: const Color(0xFF20AF67),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF20AF67),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (subcategoryName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_right_rounded,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                subcategoryName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'GH₵ ${_formatPrice(productPrice)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF20AF67),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Arrow icon
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fallback method only used if category info is missing from search results
  Future<void> _navigateToProductFallback(String productName) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Searching...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Colors.green.shade700,
      ),
    );

    try {
      debugPrint('🔍🔍 Fallback: Searching for: $productName');
      final searchResult = await _findProductInAllCategories(productName);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (searchResult != null) {
        final foundProduct = searchResult['product'];
        final foundCategoryId = searchResult['category_id'];
        final foundCategoryName = searchResult['category_name'];
        final foundSubcategoryId = searchResult['subcategory_id'];
        final foundInSubcategory =
            searchResult['found_in_subcategory'] ?? false;

        _storeSearchResultsForNavigation(foundProduct);

        if (foundInSubcategory && foundSubcategoryId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubcategoryPage(
                categoryId: foundCategoryId,
                categoryName: foundCategoryName,
                targetSubcategoryId: foundSubcategoryId,
                searchedProductId: foundProduct['id'],
                searchedProductName: foundProduct['name'],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductListPage(
                categoryId: foundCategoryId,
                categoryName: foundCategoryName,
                searchedProductId: foundProduct['id'],
                searchedProductName: foundProduct['name'],
              ),
            ),
          );
        }
      } else {
        AppErrorUtils.showSnack(
          context,
          'We couldn\'t find "$productName". Try another search or browse categories.',
          isError: true,
        );
      }
    } catch (e) {
      AppErrorUtils.showErrorSnack(context, e);
    }
  }

  Widget _buildCategoriesGrid() {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_filteredCategories.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        int crossAxisCount = 2;
        if (screenWidth > 900) {
          crossAxisCount = 4;
        } else if (screenWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: _filteredCategories.length,
          itemBuilder: (context, index) {
            final category = _filteredCategories[index];
            final icon = _getCategoryIcon(category['name'] ?? '');
            final iconColor = Colors.green.shade700;
            final available =
                category['product_count'] ?? category['available'];
            final catKey = category['id'] ?? index;
            return OpenContainer(
              key: ValueKey('category_$catKey'),
              transitionType: ContainerTransitionType.fadeThrough,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedColor: Colors.transparent,
              closedElevation: 0,
              openElevation: 0,
              transitionDuration: Duration(milliseconds: 200),
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              openBuilder: (context, _) {
                // Use the cached subcategory information if available
                final hasSubcategories =
                    _categoryHasSubcategories[category['id']] ??
                        category['has_subcategories'] ??
                        false;

                if (hasSubcategories) {
                  return SubcategoryPage(
                    categoryName: category['name'],
                    categoryId: category['id'],
                  );
                } else {
                  return ProductListPage(
                    categoryName: category['name'],
                    categoryId: category['id'],
                  );
                }
              },
              closedBuilder: (context, openContainer) => _ModernCategoryCard(
                name: category['name'] ?? '',
                icon: icon,
                iconColor: iconColor,
                available: available is int ? available : null,
                onTap: openContainer,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return _buildCatalogErrorPanel(
      errorMessage: _errorMessage,
      onRetry: () {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
        _clearCacheAndReload();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Clear cache and reload data
  Future<void> _clearCacheAndReload() async {
    CategoryCache.clearCache();
    CategoryImagePreloader.clearPreloadedImages();
    await _loadCategoriesOptimized();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload images when dependencies change (e.g., when coming back to this page)
    if (_categories.isNotEmpty) {
      _preloadCategoryImages(_categories);
    }
  }

  // Prefetch all products and cache them
  Future<void> _prefetchAllProducts() async {
    debugPrint('🔍 ==========================================');
    debugPrint('🔍 _prefetchAllProducts() method started');
    debugPrint('🔍 ==========================================');
    try {
      // Reuse the already-cached flattened catalog when it's still fresh so we
      // don't re-download get-all-products on every visit to the Categories tab.
      if (CategoryCache.cachedAllProducts.isNotEmpty &&
          CategoryCache.isCacheValid) {
        debugPrint(
            '🔍 Prefetch: reusing ${CategoryCache.cachedAllProducts.length} cached products (skipping network)');
        _allProducts = CategoryCache.cachedAllProducts;
        _buildSearchIndex(_allProducts);
        return;
      }

      // IMPORTANT:
      // For search we need products in a FLATTENED format that already contains
      // category_id / category_name / subcategory_id / subcategory_name so that
      // search can be done entirely in memory without any extra API calls.
      //
      // The CategoryOptimizationService.getProducts() call returns a different
      // shape (otcpom, drug, wellness, etc.) without those IDs, so we make a
      // single direct call to the get-all-products API here and build the
      // flattened index for CategoryCache.
      debugPrint(
          '🔍 Prefetching products for search index via get-all-products...');

      final flattenedProducts = await _catalogService.getFlattenedCatalog(
        timeout: const Duration(seconds: 12),
      );

      if (flattenedProducts.isEmpty) {
        debugPrint('🔍 Prefetch get-all-products returned no products');
        return;
      }

      debugPrint(
          '🔍 Prefetch: received ${flattenedProducts.length} items from get-all-products');

      _allProducts = flattenedProducts;
      CategoryCache.cacheAllProducts(flattenedProducts);
      _buildSearchIndex(flattenedProducts);
      debugPrint(
          '🔍 Prefetch: cached ${flattenedProducts.length} flattened products for instant search');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('🔍 Error in _prefetchAllProducts: $e');
    }

    debugPrint('🔍 ==========================================');
    debugPrint('🔍 _prefetchAllProducts() method completed');
    debugPrint('🔍 ==========================================');
  }

  // Store search results for navigation persistence
  void _storeSearchResultsForNavigation(dynamic searchedProduct) {
    // Store the searched product for navigation persistence
    SearchResultCache.storeSearchedProduct(searchedProduct);
    debugPrint(
        '🔍 Stored searched product for navigation: ${searchedProduct['name']}');
  }
}

// Skeleton screen for category page
class CategoryPageSkeletonBody extends StatelessWidget {
  const CategoryPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Shrink-wrapped grid: SliverFillRemaining cannot measure viewport intrinsics.
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton screen for subcategory page
class SubcategoryPageSkeletonBody extends StatelessWidget {
  const SubcategoryPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Row(
        children: [
          // Sidebar skeleton
          Container(
            width: 200,
            color: Colors.white,
            child: Column(
              children: [
                // Header skeleton
                Container(
                  height: 50,
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Sidebar items skeleton
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Container(
                        height: 40,
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content skeleton
          Expanded(
            child: Column(
              children: [
                // Header skeleton
                Container(
                  height: 60,
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Products grid skeleton
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton screen for product list page
class ProductListPageSkeletonBody extends StatelessWidget {
  const ProductListPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 80,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Products grid skeleton
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernCategoryCard extends StatelessWidget {
  final String name;
  final int? available;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ModernCategoryCard({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.available,
  });

  static String _getBackgroundImage(String name) {
    if (name == 'MEDICINES') {
      return 'assets/images/Medicines ECL.jpg';
    } else if (name == 'PERSONAL CARE') {
      return 'assets/images/Personal Care ECL.jpg';
    } else if (name == 'SPORTS NUTRITION') {
      return 'assets/images/Sports Nutrition ECL.jpg';
    } else if (name == 'FOOD AND DRINKS') {
      return 'assets/images/Food-Drinks ECL.jpg';
    } else if (name == 'SEXUAL HEALTH') {
      return 'assets/images/Sexual Health ECL (1).jpg';
    } else if (name == 'HOME CARE') {
      return 'assets/images/Home Care ECL.jpg';
    } else if (name == 'SANITARY CARE') {
      return 'assets/images/Sanitary Care ECL.jpg';
    } else if (name == 'MOTHER & BABY') {
      return 'assets/images/Mother-Baby ECL.jpg';
    } else if (name == 'HEALTH CARE DEVICES') {
      return 'assets/images/Healthcare Devices ECL.jpg';
    } else {
      return 'assets/images/Medicines ECL.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String bgImage = _getBackgroundImage(name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            image: DecorationImage(
              image: AssetImage(bgImage),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.35),
                BlendMode.darken,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      available != null ? '$available products' : 'Explore',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubcategoryPage extends StatefulWidget {
  final String categoryName;
  final int categoryId;
  final String? searchedProductName;
  final int? searchedProductId;
  final int? targetSubcategoryId;

  const SubcategoryPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
    this.targetSubcategoryId,
  });

  @override
  SubcategoryPageState createState() => SubcategoryPageState();
}

class SubcategoryPageState extends State<SubcategoryPage> {
  List<dynamic> subcategories = [];
  List<dynamic> products = [];
  bool isLoading = true;
  String errorMessage = '';
  int? selectedSubcategoryId;
  final ScrollController scrollController = ScrollController();
  final ScrollController _sideNavScrollController = ScrollController();
  bool showScrollToTop = false;
  int? highlightedProductId;
  Timer? highlightTimer;
  final CategoryCatalogService _catalogService = CategoryCatalogService();
  /// When false, subcategory list becomes a compact rail (more room for products).
  bool _subcategoryRailExpanded = true;
  static const double _kSubcategoryRailCollapsedWidth = 72;

  // Cache for subcategories and products
  static final Map<int, List<dynamic>> _subcategoriesCache = {};
  static final Map<int, List<dynamic>> _productsCache = {};
  static final Map<int, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    // Reuse cached subcategories/products when still valid (30 min). otcpom is
    // now merged from the cached catalog, so there's no need to nuke the cache
    // on every visit — that forced a full network refetch each time.
    _loadSubcategoriesOptimized();
    _setupScrollListener();
  }

  @override
  void dispose() {
    scrollController.dispose();
    _sideNavScrollController.dispose();
    highlightTimer?.cancel();
    super.dispose();
  }

  // Optimized loading that checks cache first
  Future<void> _loadSubcategoriesOptimized() async {
    // Check if we have valid cached data
    if (_isCacheValid(widget.categoryId) &&
        _subcategoriesCache.containsKey(widget.categoryId)) {
      final cachedSubcategories = _subcategoriesCache[widget.categoryId]!;

      if (mounted) {
        setState(() {
          subcategories = cachedSubcategories;
          isLoading = false;
        });
      }

      // Auto-select first subcategory or target subcategory
      _autoSelectSubcategory(cachedSubcategories);
      return;
    }

    // Otherwise, load from API
    await fetchSubcategories();
  }

  bool _isCacheValid(int categoryId) {
    final timestamp = _cacheTimestamps[categoryId];
    if (timestamp == null) return false;
    final isValid = DateTime.now().difference(timestamp) < _cacheValidDuration;
    debugPrint(
        '🔍 Cache validation for category $categoryId: $isValid (age: ${DateTime.now().difference(timestamp).inMinutes}min)');
    return isValid;
  }

  void _autoSelectSubcategory(List<dynamic> subcategories) {
    if (subcategories.isNotEmpty) {
      if (widget.targetSubcategoryId != null) {
        final targetSubcategory = subcategories.firstWhere((sub) {
          final subId = sub['id'];
          final targetId = widget.targetSubcategoryId;
          return subId.toString() == targetId.toString();
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(targetSubcategory['id']);
      } else {
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(firstSubcategory['id']);
      }
    }
  }

  Future<void> fetchSubcategories() async {
    try {
      final result = await _catalogService.categorySubcategoriesResult(
        widget.categoryId,
        timeout: const Duration(seconds: 8),
      );

      if (!result.isHttpOk) {
        handleSubcategoriesError(
            AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown));
        return;
      }

      if (!result.isApiSuccess) {
        handleSubcategoriesError(
            AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown));
        return;
      }

      final subcategoriesData = result.data;

      _subcategoriesCache[widget.categoryId] = subcategoriesData;
      _cacheTimestamps[widget.categoryId] = DateTime.now();

      handleSubcategoriesSuccess({'success': true, 'data': subcategoriesData});
    } catch (e) {
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Connection') ||
          s.contains('TimeoutException');
      handleSubcategoriesError(isConnectivity
          ? AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.offline)
          : AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown));
    }
  }

  void onSubcategorySelected(int subcategoryId) async {
    if (!mounted) return;

    debugPrint('🔍 Loading products for subcategory $subcategoryId...');

    setState(() {
      selectedSubcategoryId = subcategoryId;
      isLoading = true;
      products = [];
      errorMessage = '';
    });

    // Check if we have cached products for this subcategory
    if (_productsCache.containsKey(subcategoryId) &&
        _isCacheValid(subcategoryId)) {
      final cachedProducts = _productsCache[subcategoryId]!;

      await _enhanceProductsWithOtcpom(cachedProducts);
      _productsCache[subcategoryId] = cachedProducts;

      if (mounted) {
        setState(() {
          products = cachedProducts;
          isLoading = false;
        });
      }

      // Highlight searched product if available
      if (widget.searchedProductId != null) {
        _highlightSearchedProduct();
      }
      return;
    }

    try {
      final result = await _catalogService.subcategoryProductsResult(
        subcategoryId,
        timeout: const Duration(seconds: 15),
      );

      if (!result.isHttpOk) {
        handleProductsError(
            AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown));
        return;
      }

      if (!result.isApiSuccess) {
        handleProductsEmpty();
        return;
      }

      final allProducts = result.data;

      if (allProducts.isNotEmpty) {
        final firstProduct = allProducts[0];
        debugPrint('🔍 CATEGORIES API RESPONSE STRUCTURE ===');
        debugPrint('First Product Keys: ${firstProduct.keys.toList()}');
        debugPrint('First Product OTCPOM: ${firstProduct['otcpom']}');
        debugPrint('==========================================');
      }

      if (allProducts.isEmpty) {
        handleProductsEmpty();
      } else {
        debugPrint(
            '🔍 Enhancing ${allProducts.length} products with otcpom data for subcategory $subcategoryId');
        await _enhanceProductsWithOtcpom(allProducts);

        _productsCache[subcategoryId] = allProducts;
        _cacheTimestamps[subcategoryId] = DateTime.now();

        debugPrint(
            '🔍 Cached ${allProducts.length} products for subcategory $subcategoryId');

        handleProductsSuccess({'success': true, 'data': allProducts});

        _preloadNextSubcategory(subcategoryId);
      }
    } catch (e) {
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Connection') ||
          s.contains('TimeoutException');
      handleProductsError(isConnectivity
          ? AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.offline)
          : AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown));
    }
  }

  void handleSubcategoriesSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      subcategories = data['data'];
      isLoading = false;
    });

    debugPrint('🔍 SUBCATEGORIES LOADED ===');
    debugPrint('Subcategories count: ${subcategories.length}');
    debugPrint(
        'Subcategories: ${subcategories.map((s) => s['name']).toList()}');
    debugPrint('==========================');

    if (subcategories.isNotEmpty) {
      // If we have a target subcategory from search, select it
      if (widget.targetSubcategoryId != null) {
        final targetSubcategory = subcategories.firstWhere((sub) {
          final subId = sub['id'];
          final targetId = widget.targetSubcategoryId;
          // Handle both string and int comparisons
          return subId.toString() == targetId.toString();
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(targetSubcategory['id']);
      } else {
        // Otherwise select the first subcategory as before
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(firstSubcategory['id']);
      }
    }
  }

  void handleSubcategoriesError(String message) {
    if (!mounted) return;

    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  void handleProductsSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      products = data['data'];
      isLoading = false;
      errorMessage = '';
    });

    // Highlight searched product if available
    if (widget.searchedProductId != null) {
      _highlightSearchedProduct();
    }

    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void handleProductsError(String message) {
    if (!mounted) return;

    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  void handleProductsEmpty() {
    if (!mounted) return;

    setState(() {
      isLoading = false;
      products = [];
      errorMessage = '';
    });
  }

  // Clear subcategory cache to ensure fresh data
  void _clearSubcategoryCache() {
    debugPrint(
        '🔍 Clearing subcategory cache for category ${widget.categoryId}');
    _subcategoriesCache.remove(widget.categoryId);
    _productsCache.remove(widget.categoryId);
    _cacheTimestamps.remove(widget.categoryId);
  }

  // Optimized enhancement with better caching and performance
  Future<void> _enhanceProductsWithOtcpom(List<dynamic> products) async {
    debugPrint(
        '🔍 Starting optimized otcpom enhancement for ${products.length} products');

    try {
      final local = buildLocalCatalogLookupMaps();

      int enhancedCount = 0;
      for (int i = 0; i < products.length; i++) {
        final productName = products[i]['name']?.toString().toLowerCase();
        if (productName != null &&
            local.otcpomByNameLower.containsKey(productName)) {
          products[i]['otcpom'] = local.otcpomByNameLower[productName];
          enhancedCount++;
        }
      }

      mergeUrlNameFromCatalogMaps(
        products,
        local.urlByProductId,
        local.urlByNameLower,
      );

      if (products.any(
          (raw) => raw is Map && slugForProductDetailPage(raw) == null)) {
        await _enhanceProductsWithAPI(products);
      }

      debugPrint(
          '🔍 Enhanced $enhancedCount out of ${products.length} products');
    } catch (e) {
      debugPrint('🔍 Error using local catalog: $e');
      await _enhanceProductsWithAPI(products);
    }

    debugPrint(
        '🔍 Completed optimized otcpom enhancement for ${products.length} products');
  }

  // Optimized fallback method to enhance products with API call
  Future<void> _enhanceProductsWithAPI(List<dynamic> products) async {
    debugPrint('🔍 Fallback: Using optimized API call for otcpom enhancement');

    try {
      final maps = await _catalogService.buildCatalogLookupMaps(
        timeout: const Duration(seconds: 15),
      );

      int enhancedCount = 0;
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final productName = product['name']?.toString().toLowerCase();

        if (productName != null &&
            maps.otcpomByNameLower.containsKey(productName)) {
          products[i]['otcpom'] = maps.otcpomByNameLower[productName];
          enhancedCount++;
        }
      }

      mergeUrlNameFromCatalogMaps(
        products,
        maps.urlByProductId,
        maps.urlByNameLower,
      );

      debugPrint(
          '🔍 Enhanced $enhancedCount out of ${products.length} products via API');
    } catch (e) {
      debugPrint('🔍 Error in fallback API call: $e');
    }
  }

  void _highlightSearchedProduct() {
    if (widget.searchedProductId != null && mounted) {
      setState(() {
        highlightedProductId = widget.searchedProductId;
      });

      // Find the index of the searched product
      final productIndex = products.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        // Wait for the widget to be built and then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            // Calculate the position to scroll to
            final itemHeight = 250.0;
            final crossAxisCount = 2;
            final rowIndex = productIndex ~/ crossAxisCount;
            final scrollPosition = (rowIndex * itemHeight) + 100;

            // Scroll to the product
            scrollController.animateTo(
              scrollPosition,
              duration: Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      // Do NOT remove highlight after a timer; keep it until the page is left.
    }
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      if (mounted) {
        final shouldShow = scrollController.offset > 300;
        if (showScrollToTop != shouldShow) {
          setState(() {
            showScrollToTop = shouldShow;
          });
        }
      }
    });
  }

  // Preload next subcategory products for better performance
  void _preloadNextSubcategory(int currentSubcategoryId) {
    try {
      final currentIndex =
          subcategories.indexWhere((sub) => sub['id'] == currentSubcategoryId);
      if (currentIndex != -1 && currentIndex + 1 < subcategories.length) {
        final nextSubcategory = subcategories[currentIndex + 1];
        final nextSubcategoryId = nextSubcategory['id'];

        // Only preload if not already cached
        if (!_productsCache.containsKey(nextSubcategoryId) ||
            !_isCacheValid(nextSubcategoryId)) {
          debugPrint(
              '🔍 Preloading products for next subcategory: ${nextSubcategory['name']}');
          _preloadSubcategoryProducts(nextSubcategoryId);
        }
      }
    } catch (e) {
      debugPrint('🔍 Error preloading next subcategory: $e');
    }
  }

  // Background preloading of subcategory products
  Future<void> _preloadSubcategoryProducts(int subcategoryId) async {
    try {
      final allProducts = await _catalogService.getSubcategoryProducts(
        subcategoryId,
        timeout: const Duration(seconds: 10),
      );
      if (allProducts.isNotEmpty) {
        await _enhanceProductsWithOtcpom(allProducts);
        _productsCache[subcategoryId] = allProducts;
        _cacheTimestamps[subcategoryId] = DateTime.now();
        debugPrint(
            '🔍 Preloaded ${allProducts.length} products for subcategory $subcategoryId');
      }
    } catch (e) {
      debugPrint('🔍 Error preloading subcategory $subcategoryId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: null,
      body: Column(
        children: [
          // Subcategory header
          Container(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.top * 0.4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B5E20),
                  const Color(0xFF2E7D32),
                  const Color(0xFF43A047),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    AppBackButton(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    CartIconButton(
                      iconColor: Colors.white,
                      iconSize: 22,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
      floatingActionButton: _buildAnimatedScrollToTopButton(),
      bottomNavigationBar: CustomBottomNav(initialIndex: 2),
    );
  }

  Widget _buildMainContent() {
    if (isLoading && subcategories.isEmpty) {
      return buildSubcategoriesLoadingState();
    } else if (subcategories.isEmpty) {
      return buildErrorState("No subcategories found");
    } else {
      return buildBody();
    }
  }

  Widget _buildScrollToTopButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.green.shade700,
      child: Icon(Icons.keyboard_arrow_up, color: Colors.white),
      onPressed: () {
        scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Widget _buildAnimatedScrollToTopButton() {
    return IgnorePointer(
      ignoring: !showScrollToTop,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: showScrollToTop ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: showScrollToTop ? 1 : 0.85,
          child: _buildScrollToTopButton(),
        ),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading && subcategories.isEmpty) {
      return _buildSkeletonWithLoading();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 700;
        final sideNavWidth = isTablet ? 210.0 : 128.0;

        return Container(
          color: const Color(0xFFF6F8FA),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: _subcategoryRailExpanded
                    ? sideNavWidth
                    : _kSubcategoryRailCollapsedWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: const Border(
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _subcategoryRailExpanded
                    ? buildSideNavigation()
                    : _buildCollapsedSubcategoryRail(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: subcategories.isNotEmpty
                          ? buildSubcategoryHeader()
                          : Container(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Icon(Icons.category_outlined,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Categories',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Expanded(child: _buildProductsContent()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const SubcategoryPageSkeletonBody(),
        // Add a loading indicator overlay
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading subcategories...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _subcategoryNameInitial(dynamic name) {
    final t = name?.toString().trim() ?? '';
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  /// Narrow column: expand affordance only in header + compact list rows.
  Widget _buildCollapsedSubcategoryRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Center(
            child: Tooltip(
              message: 'Expand subcategory list',
              child: Material(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      setState(() => _subcategoryRailExpanded = true),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.view_sidebar_rounded,
                      color: Colors.green.shade800,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _sideNavScrollController,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 16),
            itemCount: subcategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final sub = subcategories[index];
              final isSelected = selectedSubcategoryId == sub['id'];
              return Tooltip(
                message: sub['name']?.toString() ?? 'Subcategory',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSubcategorySelected(sub['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFECFDF3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF16A34A)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _subcategoryNameInitial(sub['name']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF166534)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildSideNavigation() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Subcategory',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Collapse list — more space for products',
                child: Material(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        setState(() => _subcategoryRailExpanded = false),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        size: 20,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
              controller: _sideNavScrollController,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = subcategories[index];
                final bool isSelected =
                    selectedSubcategoryId == subcategory['id'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSubcategorySelected(subcategory['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFECFDF3) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 3,
                            height: 22,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF16A34A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              subcategory['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF475569),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: Icon(
                                Icons.check,
                                size: 13,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
    );
  }

  Widget buildSubcategoryHeader() {
    final selectedSubcategory = selectedSubcategoryId != null
        ? subcategories.firstWhere(
            (sub) => sub['id'] == selectedSubcategoryId,
            orElse: () => subcategories.isNotEmpty
                ? subcategories[0]
                : {'name': 'All Products', 'id': null},
          )
        : subcategories.isNotEmpty
            ? subcategories[0]
            : {'name': 'All Products', 'id': null};

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: Color(0xFF2E7D32),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedSubcategoryId != null
                      ? (selectedSubcategory['name'] ?? 'All Products')
                      : 'All Products',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${products.length} products available',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Text(
              '${products.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsContent() {
    Widget child;
    final stateKey = isLoading
        ? 'loading'
        : errorMessage.isNotEmpty
            ? 'error'
            : products.isEmpty
                ? 'empty'
                : 'grid';
    if (isLoading) {
      child = buildProductsLoadingState();
    } else if (errorMessage.isNotEmpty) {
      child = buildProductsErrorState();
    } else if (products.isEmpty) {
      child = buildEmptyState();
    } else {
      child = buildProductsGrid();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey('products_state_$stateKey'),
        child: child,
      ),
    );
  }

  Widget buildProductsErrorState() {
    return _buildCatalogErrorPanel(
      errorMessage: errorMessage,
      onRetry: () {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
        _refreshSelectedSubcategory();
      },
    );
  }

  Widget buildProductsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Balanced size: readable cards without feeling oversized.
        double childAspectRatio = 0.58;
        bool isTablet = MediaQuery.of(context).size.width > 600;

        if (isTablet) {
          childAspectRatio = 0.68;
        } else {
          childAspectRatio = 0.58;
        }

        // Keep 2 per row while preserving roomy cards.
        final crossAxisCount = 2;
        final horizontalPadding = isTablet ? 14.0 : 10.0;
        final spacing = isTablet ? 14.0 : 8.0;

        return RefreshIndicator(
          color: Colors.green.shade700,
          onRefresh: _refreshSelectedSubcategory,
          child: GridView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final isHighlighted = highlightedProductId == product['id'];
            final productKey = product['id'] ?? index;

            return Container(
              key: ValueKey('subcat_product_$productKey'),
              decoration: isHighlighted
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.green.shade700, width: 3),
                    )
                  : null,
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                openColor: Theme.of(context).scaffoldBackgroundColor,
                closedColor: Colors.transparent,
                closedElevation: 0,
                openElevation: 0,
                transitionDuration: Duration(milliseconds: 200),
                closedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                openBuilder: (context, _) =>
                    _CategoryProductDetailRoute(product: product),
                closedBuilder: (context, openContainer) => ProductCard(
                  product: product,
                  onTap: openContainer,
                ),
              ),
            );
          },
          ),
        );
      },
    );
  }

  /// Pull-to-refresh: force a fresh fetch for the active subcategory.
  Future<void> _refreshSelectedSubcategory() async {
    _clearSubcategoryCache();
    final id = selectedSubcategoryId;
    if (id != null) {
      _productsCache.remove(id);
      _cacheTimestamps.remove(id);
      onSubcategorySelected(id);
    } else {
      await _loadSubcategoriesOptimized();
    }
  }

  Widget buildSubcategoriesLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
      ),
    );
  }

  Widget buildProductsLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget buildErrorState(String message) {
    return _buildCatalogErrorPanel(
      errorMessage: message,
      onRetry: () {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
        fetchSubcategories();
      },
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final dynamic product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Product? _product;

  @override
  void initState() {
    super.initState();
    _convertToProduct();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _convertToProduct() {
    try {
      _product = Product.fromJson(Map<String, dynamic>.from(widget.product));
      debugPrint(
          '🔍 Converted ${_product!.name} to Product object with otcpom: ${_product!.otcpom}');
    } catch (e) {
      debugPrint('🔍 Error converting product to Product object: $e');
      _product = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_product == null) {
      // Fallback to original logic if conversion failed
      final otcpomValue = widget.product['otcpom']?.toString().toLowerCase();
      final isPrescribed = otcpomValue == 'pom';
      debugPrint(
          '🔍 ProductCard Debug (fallback) - ${widget.product['name']}: otcpom=$otcpomValue, isPrescribed=$isPrescribed');
      return _buildProductCard(context, isPrescribed, widget.product);
    }

    // Use Product object logic (same as HomeProductCard)
    final isPrescribed = _product!.otcpom?.toLowerCase() == 'pom';
    debugPrint(
        '🔍 ProductCard Debug (Product object) - ${_product!.name}: otcpom=${_product!.otcpom}, isPrescribed=$isPrescribed');

    // Additional debug for badge rendering
    if (isPrescribed) {
      debugPrint('🔍 WILL SHOW BADGE for ${_product!.name}');
    } else {
      debugPrint(
          '🔍 NO BADGE for ${_product!.name} - otcpom: ${_product!.otcpom}');
    }

    return _buildProductCard(context, isPrescribed, widget.product);
  }

  Widget _buildProductCard(
      BuildContext context, bool isPrescribed, dynamic productData) {
    final String productName =
        productData['name']?.toString() ?? 'Unknown Product';
    final dynamic rawPrice = productData['unit_price'] ??
        productData['price'] ??
        productData['selling_price'];
    final double? parsedPrice = double.tryParse(rawPrice?.toString() ?? '');
    final String priceLabel = parsedPrice != null
        ? 'GH₵ ${parsedPrice.toStringAsFixed(2)}'
        : 'View product';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: productData['thumbnail'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 300,
                        memCacheHeight: 300,
                        maxWidthDiskCache: 300,
                        maxHeightDiskCache: 300,
                        fadeInDuration: Duration(milliseconds: 100),
                        fadeOutDuration: Duration(milliseconds: 100),
                        cacheKey:
                            'product_${productData['id']}_${productData['thumbnail']}',
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isPrescribed)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Rx',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((productData['brand_name'] ?? '').toString().isNotEmpty)
                      Text(
                        productData['brand_name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    if ((productData['brand_name'] ?? '').toString().isNotEmpty)
                      const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        productName,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF1F2937),
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF166534),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductListPage extends StatefulWidget {
  final String categoryName;
  final int categoryId;
  final String? searchedProductName;
  final int? searchedProductId;

  ProductListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
  }) {
    debugPrint(
        '🔍 ProductListPage constructor called for category: $categoryName (ID: $categoryId)');
  }

  @override
  ProductListPageState createState() => ProductListPageState();
}

class ProductListPageState extends State<ProductListPage> {
  List<dynamic> products = [];
  bool isLoading = true;
  String errorMessage = '';
  final ScrollController scrollController = ScrollController();
  bool showScrollToTop = false;
  String sortOption = 'Latest';
  int? highlightedProductId;
  Timer? highlightTimer;
  final CategoryCatalogService _catalogService = CategoryCatalogService();

  // Per-category product cache so repeat visits load instantly.
  static final Map<int, List<dynamic>> _listCache = {};
  static final Map<int, DateTime> _listCacheTime = {};
  static const Duration _listCacheValid = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 ProductListPage initState() called');
    fetchProducts();
    scrollController.addListener(() {
      setState(() {
        showScrollToTop = scrollController.offset > 300;
      });
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchProducts({bool forceRefresh = false}) async {
    debugPrint('🔍 fetchProducts() method started');

    // Cache-first: serve stored products immediately on repeat visits.
    final cacheTime = _listCacheTime[widget.categoryId];
    final cacheFresh = cacheTime != null &&
        DateTime.now().difference(cacheTime) < _listCacheValid;
    if (!forceRefresh &&
        cacheFresh &&
        (_listCache[widget.categoryId]?.isNotEmpty ?? false)) {
      debugPrint('🔍 Using cached products for category ${widget.categoryId}');
      if (mounted) {
        setState(() {
          products = _listCache[widget.categoryId]!;
          isLoading = false;
          errorMessage = '';
        });
      }
      if (widget.searchedProductId != null) {
        _highlightSearchedProduct();
      }
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final result = await _catalogService.subcategoryProductsResult(
        widget.categoryId,
      );

      debugPrint('🔍 API Response Status: ${result.statusCode}');
      if (!result.isHttpOk) {
        debugPrint('🔍 API returned status code: ${result.statusCode}');
        setState(() {
          isLoading = false;
          errorMessage = result.statusCode == 404
              ? AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.notFound)
              : AppErrorUtils.catalogLoadMessage(
                  ProductDetailErrorKind.server,
                );
        });
        return;
      }

      debugPrint('🔍 API Response Success: ${result.isApiSuccess}');
      if (result.isApiSuccess) {
        final loaded = result.data;
        _listCache[widget.categoryId] = loaded;
        _listCacheTime[widget.categoryId] = DateTime.now();

        if (loaded.isNotEmpty) {
          final firstProduct = loaded.first;
          debugPrint('🔍 Category Products Debug:');
          debugPrint('First Product: ${firstProduct['name']}');
          debugPrint('First Product OTCPOM: ${firstProduct['otcpom']}');
          debugPrint('First Product Keys: ${firstProduct.keys.toList()}');
          debugPrint(
              '🔍 WARNING: Category API does not include otcpom field!');
        }

        products = loaded;
        debugPrint('🔍 About to call _enhanceProductsWithOtcpom()');
        try {
          await _enhanceProductsWithOtcpom();
          debugPrint(
              '🔍 _enhanceProductsWithOtcpom() completed successfully');
        } catch (e) {
          debugPrint('🔍 ERROR in _enhanceProductsWithOtcpom(): $e');
        }

        if (!mounted) return;
        setState(() {
          isLoading = false;
        });

        if (widget.searchedProductId != null) {
          _highlightSearchedProduct();
        }
      } else {
        debugPrint('🔍 API returned success=false');
        setState(() {
          isLoading = false;
          errorMessage =
              AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.notFound);
        });
      }
    } catch (e) {
      debugPrint('🔍 ERROR in fetchProducts(): $e');
      final s = e.toString();
      final isConnectivity = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Connection') ||
          s.contains('TimeoutException');
      setState(() {
        isLoading = false;
        errorMessage = isConnectivity
            ? AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.offline)
            : AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown);
      });
    }
    debugPrint('🔍 fetchProducts() method completed');
  }

  Future<void> _enhanceProductsWithOtcpom() async {
    debugPrint('🔍 _enhanceProductsWithOtcpom() method started');

    final local = buildLocalCatalogLookupMaps();
    mergeUrlNameFromCatalogMaps(
      products,
      local.urlByProductId,
      local.urlByNameLower,
    );

    final missingIndices = <int>[];
    for (var i = 0; i < products.length; i++) {
      if (products[i]['otcpom'] != null &&
          products[i]['otcpom'].toString().isNotEmpty) {
        continue;
      }
      final name = products[i]['name']?.toString().toLowerCase();
      final fromLocal = name != null ? local.otcpomByNameLower[name] : null;
      if (fromLocal != null && fromLocal.isNotEmpty) {
        products[i]['otcpom'] = fromLocal;
      } else {
        missingIndices.add(i);
      }
    }

    if (products.any((p) => slugForProductDetailPage(p) == null)) {
      await mergeProductSlugsFromNetwork(products, _catalogService);
    }

    if (missingIndices.isNotEmpty) {
      debugPrint(
          '🔍 Fetching otcpom from API for ${missingIndices.length} uncached products (parallel)');
      await _fetchOtcpomDataFromAPI(missingIndices);
    }

    if (mounted) setState(() {});
    debugPrint('🔍 _enhanceProductsWithOtcpom() method completed');
  }

  Future<void> _fetchOtcpomDataFromAPI(List<int> indices) async {
    await Future.wait(indices.map((i) async {
      final product = products[i];
      final productId = product['id'];
      if (productId == null) return;
      try {
        final id = productId is int
            ? productId
            : int.tryParse(productId.toString());
        if (id == null) return;

        final otcpom = await _catalogService.getProductOtcpom(
          id,
          timeout: const Duration(seconds: 8),
        );
        if (otcpom != null) {
          products[i]['otcpom'] = otcpom;
        }
      } catch (e) {
        debugPrint(
            '🔍 Error fetching otcpom for product ${product['name']}: $e');
      }
    }));

    if (mounted) setState(() {});
  }

  void _highlightSearchedProduct() {
    if (widget.searchedProductId != null && mounted) {
      setState(() {
        highlightedProductId = widget.searchedProductId;
      });

      // Find the index of the searched product
      final productIndex = products.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        // Wait for the widget to be built and then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            // Calculate the position to scroll to
            final itemHeight = 250.0;
            final crossAxisCount = 2;
            final rowIndex = productIndex ~/ crossAxisCount;
            final scrollPosition = (rowIndex * itemHeight) + 100;

            // Scroll to the product
            scrollController.animateTo(
              scrollPosition,
              duration: Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      // Do NOT remove highlight after a timer; keep it until the page is left.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: null,
      body: Column(
        children: [
          // Enhanced header with better design (matching notifications)
          Container(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.top * 0.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade700,
                  Colors.green.shade800,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    AppBackButton(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${products.length} products found',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                    CartIconButton(
                      iconColor: Colors.white,
                      iconSize: 22,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${products.length} products found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildProductsList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.green.shade700,
              child: Icon(Icons.keyboard_arrow_up, color: Colors.white),
              onPressed: () {
                scrollController.animateTo(
                  0,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
            )
          : null,
    );
  }

  Widget _buildProductsList() {
    if (isLoading) {
      return _buildSkeletonWithLoading();
    }

    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => fetchProducts(forceRefresh: true),
      color: Colors.green.shade700,
      child: GridView.builder(
        controller: scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 0.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final isHighlighted = highlightedProductId == product['id'];
          final productKey = product['id'] ?? index;

          return Container(
            key: ValueKey('list_product_$productKey'),
            decoration: isHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade700, width: 3),
                  )
                : null,
            child: OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedColor: Colors.transparent,
              closedElevation: 0,
              openElevation: 0,
              transitionDuration: Duration(milliseconds: 200),
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              openBuilder: (context, _) =>
                  _CategoryProductDetailRoute(product: product),
              closedBuilder: (context, openContainer) => ProductCard(
                product: product,
                onTap: openContainer,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const ProductListPageSkeletonBody(),
        // Add a loading indicator overlay
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading products...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return _buildCatalogErrorPanel(
      errorMessage: errorMessage,
      onRetry: () {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
        fetchProducts();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> products;
  final Function(int categoryId, int? subcategoryId) onCategorySelected;
  final String? currentCategoryName;

  ProductSearchDelegate({
    required this.products,
    required this.onCategorySelected,
    this.currentCategoryName,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredProducts = query.isEmpty
        ? []
        : products.where((product) {
            return product['name'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                );
          }).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              currentCategoryName != null
                  ? 'Search in $currentCategoryName'
                  : 'Search all products',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'There is no product available currently',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final categoryId = product['category_id'];
        final subcategoryId = product['subcategory_id'];
        final categoryName = product['category_name'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: product['thumbnail'] ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 120,
                memCacheHeight: 120,
                maxWidthDiskCache: 120,
                maxHeightDiskCache: 120,
                cacheKey:
                    'search_list_${product['id']}_${product['thumbnail']}',
                errorWidget: (context, url, error) => Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          title: Text(
            product['name'] ?? 'Unknown Product',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GHS ${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: Colors.green.shade700, fontSize: 14),
              ),
              if (categoryName != null)
                Text(
                  'Category: $categoryName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            close(context, '');
            onCategorySelected(categoryId, subcategoryId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    _CategoryProductDetailRoute(product: product),
              ),
            );
          },
        );
      },
    );
  }
}
