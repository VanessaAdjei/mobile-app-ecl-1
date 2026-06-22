// pages/categories.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eclapp/pages/itemdetail.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/config/api_config.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../utils/app_error_utils.dart';
import '../utils/category_navigation.dart';
import '../utils/category_utils.dart';
import '../utils/product_detail_parser.dart';
import '../utils/product_detail_navigation.dart';
import '../services/product_detail_service.dart';
import '../widgets/error_display.dart';
import 'package:eclapp/pages/bulk_purchase_page.dart';
import 'package:eclapp/pages/bottomnav.dart';
import 'package:eclapp/pages/main_tab_shell.dart';
import '../services/category_optimization_service.dart';
import '../services/category_catalog_service.dart';
import '../services/home_preload_service.dart';
import '../services/product_image_preload_service.dart';
import '../services/product_catalog_service.dart';
import '../services/stock_utility_service.dart';
import '../models/product_model.dart';
import 'search_results_page.dart';
import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';
import '../cache/product_catalog_memory.dart';
import '../cache/product_cache.dart';
import 'package:flutter/foundation.dart';
import '../widgets/category/category_browse_shell.dart';
import '../widgets/category/category_page_search_bar.dart';
import '../widgets/category/subcategory_design.dart';
import 'package:animations/animations.dart';

/// Safe price label for category/search rows (`price` may be String or num).
String formatCategoryProductPrice(dynamic price) {
  final parsed = double.tryParse(price?.toString() ?? '');
  return parsed?.toStringAsFixed(2) ?? '0.00';
}

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

/// Page-based product grid (subcategory APIs return the full list).
class _CategoryProductPagination {
  static const int pageSize = 20;

  static int totalPages(int count) {
    if (count <= 0) return 1;
    return (count + pageSize - 1) ~/ pageSize;
  }

  static List<dynamic> itemsForPage(List<dynamic> all, int page) {
    if (all.isEmpty) return const [];
    final safePage = page.clamp(0, totalPages(all.length) - 1);
    final start = safePage * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  static int pageForIndex(int index) {
    if (index < 0) return 0;
    return index ~/ pageSize;
  }

  static String rangeLabel(int total, int page) {
    if (total <= 0) return '0 items';
    final start = page * pageSize + 1;
    final end = ((page + 1) * pageSize).clamp(0, total);
    return '$start–$end of $total';
  }
}

/// Shared product grid sizing for subcategory + leaf category browse pages.
({
  int crossAxisCount,
  double horizontalPadding,
  double spacing,
  double childAspectRatio,
  bool compact,
}) categoryProductGridMetrics(double gridWidth) {
  final isTablet = gridWidth >= 520;
  final crossAxisCount = isTablet ? 3 : 2;
  final horizontalPadding = isTablet ? 14.0 : 8.0;
  final spacing = isTablet ? 10.0 : 6.0;
  final cellWidth =
      (gridWidth - horizontalPadding * 2 - spacing * (crossAxisCount - 1)) /
          crossAxisCount;
  final compact = cellWidth < 160;
  final footerHeight = compact ? 56.0 : 62.0;
  final imageHeight = cellWidth * (compact ? 0.88 : 0.92);
  final childAspectRatio =
      (cellWidth / (imageHeight + footerHeight)).clamp(0.54, 0.9);
  return (
    crossAxisCount: crossAxisCount,
    horizontalPadding: horizontalPadding,
    spacing: spacing,
    childAspectRatio: childAspectRatio,
    compact: compact,
  );
}

Widget _buildCategoryProductPaginationBar({
  required BuildContext context,
  required int currentPage,
  required int totalPages,
  required int totalItems,
  required VoidCallback? onPrevious,
  required VoidCallback? onNext,
}) {
  return CategoryBrowsePaginationBar(
    currentPage: currentPage,
    totalPages: totalPages,
    totalItems: totalItems,
    itemsPerPage: _CategoryProductPagination.pageSize,
    onPrevious: onPrevious,
    onNext: onNext,
  );
}

/// Lookup maps from disk/memory catalog caches (no network).
void applyLocalProductRowEnhancement(List<dynamic> products) {
  if (products.isEmpty) return;
  final local = buildLocalCatalogLookupMaps();
  for (var i = 0; i < products.length; i++) {
    final raw = products[i];
    if (raw is! Map) continue;
    final name = raw['name']?.toString().toLowerCase();
    if (name != null && local.otcpomByNameLower.containsKey(name)) {
      products[i]['otcpom'] = local.otcpomByNameLower[name];
    }
  }
  mergeUrlNameFromCatalogMaps(
    products,
    local.urlByProductId,
    local.urlByNameLower,
  );
}

bool productsNeedNetworkEnhancement(List<dynamic> products) {
  for (final raw in products) {
    if (raw is Map && slugForProductDetailPage(raw) == null) {
      return true;
    }
  }
  return false;
}

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
    final earlySlug = resolveProductDetailUrlName(widget.product);
    if (earlySlug != null && earlySlug.isNotEmpty) {
      ProductDetailService.warmProductDetails(earlySlug);
    }
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
        page: ProductDetailNavigation.itemPage(
          urlName: slug,
          raw: widget.product,
          isPrescribed: _isPrescribed,
        ),
        kind: ProductDetailErrorKind.unknown,
      );
    }

    if (!ProductCache.hasProductsInMemory) {
      await ProductCache.loadFromStorage();
      slug = resolveProductDetailUrlName(widget.product);
      if (slug != null && slug.isNotEmpty) {
        return _ProductOpenResult(
          page: ProductDetailNavigation.itemPage(
            urlName: slug,
            raw: widget.product,
            isPrescribed: _isPrescribed,
          ),
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
            page: ProductDetailNavigation.itemPage(
              urlName: slug,
              raw: widget.product,
              isPrescribed: _isPrescribed,
            ),
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

Widget _buildCatalogErrorPanel(
  BuildContext context, {
  required String errorMessage,
  required VoidCallback onRetry,
}) {
  final theme = context.appColors;
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
              color: theme.ink,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppErrorUtils.catalogLoadMessage(kind, detail: errorMessage),
            style: TextStyle(fontSize: 14, color: theme.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
    unawaited(
      ProductImagePreloadService.warmCategoryImageUrls(
        urls: [imageUrl],
        maxWait: const Duration(seconds: 20),
        maxConcurrent: 1,
      ),
    );
    precacheImage(
      CachedNetworkImageProvider(
        imageUrl,
        maxWidth: ProductImagePreloadService.categoryThumbDiskSize,
        maxHeight: ProductImagePreloadService.categoryThumbDiskSize,
        cacheManager: ProductImagePreloadService.cacheManager,
      ),
      context,
      onError: (exception, stackTrace) {
        debugPrint(
            'Skipping category preload image (may be missing): $imageUrl');
      },
    );
  }

  static void preloadImages(List<String> imageUrls, BuildContext context) {
    final pending = imageUrls
        .where((url) => url.isNotEmpty && !_preloadedImages.containsKey(url))
        .toList();
    if (pending.isEmpty) return;

    for (final imageUrl in pending) {
      _preloadedImages[imageUrl] = true;
    }
    unawaited(
      ProductImagePreloadService.warmCategoryImageUrls(
        urls: pending,
        maxWait: const Duration(seconds: 45),
      ),
    );
    for (final imageUrl in pending) {
      precacheImage(
        CachedNetworkImageProvider(
          imageUrl,
          maxWidth: ProductImagePreloadService.categoryThumbDiskSize,
          maxHeight: ProductImagePreloadService.categoryThumbDiskSize,
          cacheManager: ProductImagePreloadService.cacheManager,
        ),
        context,
        onError: (exception, stackTrace) {
          debugPrint(
              'Skipping category preload image (may be missing): $imageUrl');
        },
      );
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
  final bool showBottomNav;

  const CategoryPage({
    super.key,
    this.isBulkPurchase = false,
    this.showBottomNav = true,
  });

  @override
  CategoryPageState createState() => CategoryPageState();
}

class CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _highlightTimer;
  bool _showSearchDropdown = false;
  List<Product> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  final ScrollController _searchScrollController = ScrollController();
  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();
  final CategoryCatalogService _catalogService = CategoryCatalogService();
  final ProductCatalogService _productCatalogService = ProductCatalogService();
  final GlobalKey _searchBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 CategoryPage initState() called');
    if (!ProductCache.hasProductsInMemory) {
      unawaited(ProductCache.loadFromStorage());
    }
    _hydrateCategoriesFromOnboardingPreload();
    _initializeCategoryService();
    debugPrint('🔍 Calling _prefetchAllProducts()...');
    unawaited(_prefetchAllProducts());
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

  void _hydrateCategoriesFromOnboardingPreload() {
    final cached = HomePreloadService.cachedCategories;
    if (cached.isEmpty) return;
    _categories = List<dynamic>.from(cached);
    _filteredCategories = List<dynamic>.from(cached);
    _isLoading = false;
    _errorMessage = '';
  }

  Future<void> _initializeCategoryService() async {
    await _categoryService.initialize();
    if (!context.mounted) return;

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

      if (!context.mounted) return;
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

      if (!context.mounted) return;
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

    setState(() {
      _categories = categories;
      _filteredCategories = categories;
    });

    debugPrint('Categories state updated: ${_categories.length} categories');
    debugPrint('Filtered categories: ${_filteredCategories.length} categories');
  }

  // load category images ahead of time so they show up fast
  void _preloadCategoryImages(List<dynamic> categories) {
    final imageUrls =
        ProductImagePreloadService.collectCategoryImageUrls(categories);
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

    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      await _performSearch(query);
    });
  }

  List<Product> _catalogProductsForSearch() {
    if (ProductCache.hasProductsInMemory) {
      return ProductCache.cachedProducts;
    }
    return const [];
  }

  Product _matchingCatalogProduct(Product suggestion) {
    return _catalogProductsForSearch().firstWhere(
      (p) => p.id == suggestion.id || p.name == suggestion.name,
      orElse: () => suggestion,
    );
  }

  static Product _typeaheadViewMoreRow() {
    return Product(
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
      route: '',
    );
  }

  /// Same API path as home search: GET /api/search/{query} via [ProductCatalogService].
  Future<List<Product>> _fetchTypeaheadSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final products = await _productCatalogService.searchForTypeahead(
        query,
        timeout: const Duration(seconds: 10),
      );
      if (products.length > 1) {
        return [_typeaheadViewMoreRow(), ...products.take(6)];
      }
      return products;
    } on TimeoutException {
      return [];
    } catch (e) {
      debugPrint('🔍 Category typeahead search error: $e');
      return [];
    }
  }

  void _openSearchResults(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(
          query: trimmed,
          products: _catalogProductsForSearch(),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _searchController.clear();
      setState(() {
        _showSearchDropdown = false;
        _searchResults = [];
        _filteredCategories = _categories;
      });
      _searchFocusNode.unfocus();
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
      debugPrint('🔍 Starting typeahead search for: $query');

      final results = await _fetchTypeaheadSuggestions(query);
      if (!mounted || _searchController.text.trim() != query.trim()) return;

      setState(() {
        _searchResults = results;
      });

      debugPrint('🔍 Search completed: Found ${_searchResults.length} results');
    } catch (e) {
      debugPrint('🔍 Search error: $e');
      setState(() {
        _searchResults = [];
      });
    }
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
    final theme = context.appColors;
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
          MainTabShell.goToTab(context, 0);
        }
      },
      child: Scaffold(
        appBar: null,
        backgroundColor: theme.pageBg,
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
                  centerTitle: true,
                  expandedTitleAlignment: Alignment.bottomCenter,
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
                      MainTabShell.goToTab(context, 0);
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
                  child: KeyedSubtree(
                    key: _searchBarKey,
                    child: CategoryPageSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSubmitted: _openSearchResults,
                      onChanged: (value) {
                        setState(() {});
                        _searchProduct(value);
                      },
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          setState(() => _showSearchDropdown = true);
                        }
                      },
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _showSearchDropdown = false;
                          _searchResults = [];
                          _filteredCategories = _categories;
                        });
                        _searchFocusNode.unfocus();
                      },
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
                    color: Colors.black.withValues(
                      alpha: theme.isDark ? 0.45 : 0.1,
                    ),
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
                  final headerHeight =
                      100.0; // EclExpandableSliverAppBar approximate height
                  final searchBarTopPadding = 12.0;
                  final searchBarBottomPadding = 8.0;
                  final searchBarHeight = 52.0;
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
                      elevation: theme.isDark ? 20 : 16,
                      borderRadius: BorderRadius.circular(14),
                      shadowColor: theme.isDark
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.25),
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap from closing
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 450),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? const Color(0xFF111827)
                                : theme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.isDark
                                  ? SubcategoryDesign.categorySearchBorder(
                                      context,
                                    )
                                  : theme.border,
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
                                    colors: SubcategoryDesign
                                        .categorySearchDropdownHeaderGradient(
                                      context,
                                    ),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.isDark
                                          ? SubcategoryDesign.railBorder(
                                              context,
                                            )
                                          : theme.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            SubcategoryDesign.accent(context),
                                            SubcategoryDesign.accentDark(
                                              context,
                                            ),
                                          ],
                                        ),
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
                                          color: theme.ink,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: theme.muted,
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
                                              color: theme.muted,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No products found',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: theme.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Try a different search term',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme.muted,
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
        bottomNavigationBar: widget.showBottomNav
            ? const CustomBottomNav(selectedIndex: 3)
            : null,
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
    final theme = context.appColors;
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
                    color: theme.ink,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.searchBorder),
                  ),
                  child: Text(
                    '${_filteredCategories.length} found',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.muted,
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

  Widget _buildSearchResultItem(Product suggestion) {
    final theme = context.appColors;
    if (suggestion.name == '__VIEW_MORE__') {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openSearchResults(_searchController.text),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SubcategoryDesign.selectedTint(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SubcategoryDesign.selectedBorder(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: SubcategoryDesign.accentDark(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'View All Results',
                    style: TextStyle(
                      color: SubcategoryDesign.accentDark(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final matching = _matchingCatalogProduct(suggestion);
    final imageUrl = getProductImageUrl(
      matching.thumbnail.isNotEmpty ? matching.thumbnail : suggestion.thumbnail,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _searchResults = [];
            _showSearchDropdown = false;
          });
          _searchFocusNode.unfocus();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailNavigation.itemPage(
                urlName: matching.urlName.isNotEmpty
                    ? matching.urlName
                    : suggestion.urlName,
                product: matching,
              ),
            ),
          ).then((_) {
            if (!mounted) return;
            _searchController.clear();
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.isDark
                ? SubcategoryDesign.unselectedItemBg(context)
                : theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.isDark
                  ? SubcategoryDesign.railBorder(context)
                  : theme.border,
            ),
            boxShadow: theme.isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                SubcategoryDesign.accent(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 24,
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
              Expanded(
                child: Text(
                  suggestion.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
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
            final categoryId =
                categoryIdFromApi(category['id'], fallback: index);
            final imageUrl = categoryImageUrlFromApi(category);
            final available =
                category['product_count'] ?? category['available'];
            final catKey = categoryId;
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
                final hasSubcategories =
                    categoryHasSubcategoriesFromApi(category);

                if (hasSubcategories) {
                  return SubcategoryPage(
                    categoryName: category['name']?.toString() ?? '',
                    categoryId: categoryId,
                    showBottomNav: widget.showBottomNav,
                  );
                } else {
                  return ProductListPage(
                    categoryName: category['name']?.toString() ?? '',
                    categoryId: categoryId,
                  );
                }
              },
              closedBuilder: (context, openContainer) => _ModernCategoryCard(
                name: category['name']?.toString() ?? '',
                imageUrl: imageUrl,
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
      context,
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
        return;
      }

      // Build flattened search rows from the same in-flight ProductCache load
      // as home (MainTabShell mounts this tab immediately — no parallel HTTP).
      if (ProductCache.isCatalogLoadInFlight) {
        debugPrint(
          '🔍 Prefetch: waiting on ProductCache get-all-products (no duplicate)',
        );
      }
      debugPrint('🔍 Prefetch: building search index from shared catalog...');

      final flattenedProducts = await _catalogService.getFlattenedCatalog(
        timeout: const Duration(minutes: 2),
      );

      if (flattenedProducts.isEmpty) {
        debugPrint('🔍 Prefetch get-all-products returned no products');
        return;
      }

      debugPrint(
          '🔍 Prefetch: received ${flattenedProducts.length} items from get-all-products');

      CategoryCache.cacheAllProducts(flattenedProducts);
      debugPrint(
          '🔍 Prefetch: cached ${flattenedProducts.length} flattened products');

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
}

// Skeleton screen for category page
class CategoryPageSkeletonBody extends StatelessWidget {
  const CategoryPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Shimmer.fromColors(
      baseColor: theme.isDark ? Colors.grey.shade800 : Colors.grey.shade400,
      highlightColor:
          theme.isDark ? Colors.grey.shade700 : Colors.grey.shade200,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            height: 50,
            decoration: BoxDecoration(
              color: theme.surface,
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
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.surface,
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
                    color: theme.surface,
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
    final shimmer = SubcategoryDesign.shimmerColors(context);
    return Shimmer.fromColors(
      baseColor: shimmer.$1,
      highlightColor: shimmer.$2,
      child: Row(
        children: [
          Container(
            width: 108,
            color: SubcategoryDesign.railBg(context),
            child: Column(
              children: [
                Container(
                  height: 36,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SubcategoryDesign.railHeaderBg(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(6),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Container(
                        height: 30,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: SubcategoryDesign.unselectedItemBg(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SubcategoryDesign.contentBg(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final metrics = categoryProductGridMetrics(
                        MediaQuery.sizeOf(context).width - 108,
                      );
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: metrics.crossAxisCount,
                          childAspectRatio: metrics.childAspectRatio,
                          crossAxisSpacing: metrics.spacing,
                          mainAxisSpacing: metrics.spacing,
                        ),
                        itemCount: 8,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: context.appColors.surface,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                            ),
                          );
                        },
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
    final shimmer = SubcategoryDesign.shimmerColors(context);
    return Shimmer.fromColors(
      baseColor: shimmer.$1,
      highlightColor: shimmer.$2,
      child: Column(
        children: [
          Container(
            height: 80,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final metrics = categoryProductGridMetrics(
                    MediaQuery.sizeOf(context).width);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    metrics.horizontalPadding,
                    10,
                    metrics.horizontalPadding,
                    16,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: metrics.crossAxisCount,
                    childAspectRatio: metrics.childAspectRatio,
                    crossAxisSpacing: metrics.spacing,
                    mainAxisSpacing: metrics.spacing,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
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
  final String imageUrl;
  final int? available;
  final VoidCallback onTap;

  const _ModernCategoryCard({
    required this.name,
    required this.imageUrl,
    required this.onTap,
    this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    cacheManager: ProductImagePreloadService.cacheManager,
                    memCacheWidth:
                        ProductImagePreloadService.categoryThumbDiskSize,
                    memCacheHeight:
                        ProductImagePreloadService.categoryThumbDiskSize,
                    maxWidthDiskCache:
                        ProductImagePreloadService.categoryThumbDiskSize,
                    maxHeightDiskCache:
                        ProductImagePreloadService.categoryThumbDiskSize,
                    fadeInDuration: const Duration(milliseconds: 120),
                    placeholder: (_, __) => Container(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      child: Icon(
                        Icons.category_outlined,
                        color: AppColors.primary.withValues(alpha: 0.5),
                        size: 36,
                      ),
                    ),
                  )
                else
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.category_outlined,
                      color: AppColors.primary.withValues(alpha: 0.45),
                      size: 36,
                    ),
                  ),
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
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
                              available != null
                                  ? '$available products'
                                  : 'Explore',
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
              ],
            ),
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
  final bool showBottomNav;

  const SubcategoryPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
    this.targetSubcategoryId,
    this.showBottomNav = true,
  });

  @override
  SubcategoryPageState createState() => SubcategoryPageState();
}

class SubcategoryPageState extends State<SubcategoryPage> {
  List<dynamic> subcategories = [];
  List<dynamic> products = [];
  List<dynamic> _allProducts = [];
  int _currentProductPage = 0;
  bool isLoading = true;
  String errorMessage = '';
  int? selectedSubcategoryId;
  final ScrollController scrollController = ScrollController();
  final ScrollController _sideNavScrollController = ScrollController();
  bool showScrollToTop = false;
  int? highlightedProductId;
  Timer? highlightTimer;
  final CategoryCatalogService _catalogService = CategoryCatalogService();
  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();

  /// When false, subcategory list becomes a compact rail (more room for products).
  bool _subcategoryRailExpanded = true;

  /// Leaf category: `/categories/{id}` returned products, not subcategory rows.
  bool _productsOnlyMode = false;
  static const double _kSubcategoryRailCollapsedWidth = 48;

  bool get _singleSubcategoryMode =>
      !_productsOnlyMode && subcategories.length == 1;

  /// Full-width product grid — no side rail (leaf category or lone subcategory).
  bool get _useFullWidthProductLayout =>
      _productsOnlyMode || _singleSubcategoryMode;

  // Cache for products (subcategories come from [CategoryOptimizationService])
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

  List<dynamic>? _cachedSubcategoryRows() {
    return _categoryService.getCachedSubcategories(widget.categoryId);
  }

  // Optimized loading that checks cache first
  Future<void> _loadSubcategoriesOptimized() async {
    // Check if we have valid cached data
    final cachedFromService = _cachedSubcategoryRows();
    if (cachedFromService != null) {
      final cachedRows = cachedFromService;
      _cacheTimestamps[widget.categoryId] = DateTime.now();
      final typedRows = cachedRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      if (categoryListRowsAreProducts(typedRows)) {
        await _showDirectCategoryProducts(typedRows);
        return;
      }

      if (typedRows.isEmpty) {
        await _fetchDirectCategoryProducts();
        return;
      }

      if (mounted) {
        setState(() {
          subcategories = typedRows;
          isLoading = false;
          _productsOnlyMode = false;
        });
      }

      _autoSelectSubcategory(typedRows);
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

  Map<String, dynamic>? _subcategoryRowById(int id) {
    for (final sub in subcategories) {
      if (sub is Map && categoryIdFromApi(sub['id']) == id) {
        return Map<String, dynamic>.from(sub);
      }
    }
    return null;
  }

  Map<String, dynamic> _subcategoryHeaderRow() {
    const fallback = <String, dynamic>{'name': 'All Products', 'id': null};
    if (subcategories.isEmpty) return Map<String, dynamic>.from(fallback);

    if (selectedSubcategoryId != null) {
      final match = _subcategoryRowById(selectedSubcategoryId!);
      if (match != null) return match;
    }

    final first = subcategories.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return Map<String, dynamic>.from(fallback);
  }

  bool _subcategoryUsesProductCategoriesEndpoint(int subcategoryId) {
    final sub = _subcategoryRowById(subcategoryId);
    if (sub == null) return true;
    return subcategoryHasProductCategoriesFromApi(sub);
  }

  void _autoSelectSubcategory(List<dynamic> subcategories) {
    if (subcategories.isNotEmpty) {
      if (widget.targetSubcategoryId != null) {
        final targetSubcategory = subcategories.firstWhere((sub) {
          return categoryIdFromApi(sub['id']) == widget.targetSubcategoryId;
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(categoryIdFromApi(targetSubcategory['id']));
      } else {
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(categoryIdFromApi(firstSubcategory['id']));
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

      final rows = _catalogService.parseCategoryListResult(result);

      if (categoryListRowsAreProducts(rows)) {
        await _showDirectCategoryProducts(rows);
        return;
      }

      if (rows.isEmpty) {
        await _fetchDirectCategoryProducts();
        return;
      }

      _categoryService.cacheSubcategories(widget.categoryId, rows);
      _cacheTimestamps[widget.categoryId] = DateTime.now();

      handleSubcategoriesSuccess({'success': true, 'data': rows});
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

  void onSubcategorySelected(dynamic subcategoryId) async {
    if (!mounted) return;

    final id = categoryIdFromApi(subcategoryId);
    if (id <= 0) return;

    final hasProductCategories = _subcategoryUsesProductCategoriesEndpoint(id);
    debugPrint(
      '🔍 Loading products for subcategory $id '
      '(has_product_categories: $hasProductCategories)...',
    );

    setState(() {
      selectedSubcategoryId = id;
      isLoading = true;
      products = [];
      _allProducts = [];
      _currentProductPage = 0;
      errorMessage = '';
    });

    // Check if we have cached products for this subcategory
    if (_productsCache.containsKey(id) && _isCacheValid(id)) {
      final cachedProducts = _productsCache[id]!;
      applyLocalProductRowEnhancement(cachedProducts);
      handleProductsSuccess({'success': true, 'data': cachedProducts});
      unawaited(_enhanceProductsInBackground(cachedProducts));
      return;
    }

    try {
      final result = await _catalogService.subcategoryListProductsResult(
        id,
        hasProductCategories: hasProductCategories,
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

      final allProducts = _catalogService.parseCategoryListResult(result);

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
        applyLocalProductRowEnhancement(allProducts);
        _productsCache[id] = allProducts;
        _cacheTimestamps[id] = DateTime.now();
        handleProductsSuccess({'success': true, 'data': allProducts});
        unawaited(_enhanceProductsInBackground(allProducts));
        _preloadNextSubcategory(id);
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

  Future<void> _showDirectCategoryProducts(
    List<Map<String, dynamic>> productRows,
  ) async {
    if (!mounted) return;

    setState(() {
      _productsOnlyMode = true;
      subcategories = [];
      selectedSubcategoryId = null;
      isLoading = true;
      errorMessage = '';
    });

    applyLocalProductRowEnhancement(productRows);
    _productsCache[widget.categoryId] = productRows;
    _cacheTimestamps[widget.categoryId] = DateTime.now();

    if (!mounted) return;
    handleProductsSuccess({'success': true, 'data': productRows});
    unawaited(_enhanceProductsInBackground(productRows));
  }

  Future<void> _fetchDirectCategoryProducts() async {
    if (!mounted) return;

    setState(() {
      _productsOnlyMode = true;
      subcategories = [];
      selectedSubcategoryId = null;
      isLoading = true;
      errorMessage = '';
    });

    try {
      final products = await _catalogService.fetchResolvedCategoryProducts(
        widget.categoryId,
        timeout: const Duration(seconds: 15),
      );

      if (products.isEmpty) {
        handleProductsEmpty();
        return;
      }

      await _showDirectCategoryProducts(products);
    } catch (e) {
      handleProductsError(
        AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.unknown),
      );
    }
  }

  void handleSubcategoriesSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      subcategories = data['data'];
      isLoading = false;
      _productsOnlyMode = false;
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
          return categoryIdFromApi(sub['id']) == widget.targetSubcategoryId;
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(categoryIdFromApi(targetSubcategory['id']));
      } else {
        // Otherwise select the first subcategory as before
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(categoryIdFromApi(firstSubcategory['id']));
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

  void _applyPagedProducts(List<dynamic> all, {int page = 0}) {
    _allProducts = all;
    final total = _CategoryProductPagination.totalPages(all.length);
    _currentProductPage = page.clamp(0, total - 1);
    products =
        _CategoryProductPagination.itemsForPage(all, _currentProductPage);
  }

  void _goToProductPage(int page) {
    if (_allProducts.isEmpty || !mounted) return;
    final total = _CategoryProductPagination.totalPages(_allProducts.length);
    final safe = page.clamp(0, total - 1);
    if (safe == _currentProductPage) return;
    setState(() {
      _currentProductPage = safe;
      products = _CategoryProductPagination.itemsForPage(
        _allProducts,
        _currentProductPage,
      );
    });
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  void _ensurePagedThroughProductIndex(int index) {
    _goToProductPage(_CategoryProductPagination.pageForIndex(index));
  }

  void handleProductsSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      _applyPagedProducts(List<dynamic>.from(data['data'] as List));
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
      _allProducts = [];
      _currentProductPage = 0;
      errorMessage = '';
    });
  }

  // Clear subcategory cache to ensure fresh data
  void _clearSubcategoryCache() {
    debugPrint(
        '🔍 Clearing subcategory cache for category ${widget.categoryId}');
    _categoryService.invalidateSubcategoriesCache(widget.categoryId);
    _productsCache.remove(widget.categoryId);
    _cacheTimestamps.remove(widget.categoryId);
  }

  /// Background slug/otcpom enrichment — must not block first paint.
  Future<void> _enhanceProductsInBackground(List<dynamic> products) async {
    if (!productsNeedNetworkEnhancement(products)) return;

    try {
      await _enhanceProductsWithAPI(products);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('🔍 Background product enhancement failed: $e');
    }
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
      final productIndex = _allProducts.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        _ensurePagedThroughProductIndex(productIndex);
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
      if (!mounted || !scrollController.hasClients) return;

      final shouldShow = scrollController.offset > 300;
      if (showScrollToTop != shouldShow) {
        setState(() {
          showScrollToTop = shouldShow;
        });
      }
    });
  }

  // Preload next subcategory products for better performance
  void _preloadNextSubcategory(int currentSubcategoryId) {
    try {
      final currentIndex = subcategories.indexWhere(
        (sub) => categoryIdFromApi(sub['id']) == currentSubcategoryId,
      );
      if (currentIndex != -1 && currentIndex + 1 < subcategories.length) {
        final nextSubcategory = subcategories[currentIndex + 1];
        final nextSubcategoryId = categoryIdFromApi(nextSubcategory['id']);

        // Only preload if not already cached
        if (!_productsCache.containsKey(nextSubcategoryId) ||
            !_isCacheValid(nextSubcategoryId)) {
          debugPrint(
              '🔍 Preloading products for next subcategory: ${nextSubcategory['name']}');
          _preloadSubcategoryProducts(
            nextSubcategoryId,
            hasProductCategories: subcategoryHasProductCategoriesFromApi(
              nextSubcategory,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔍 Error preloading next subcategory: $e');
    }
  }

  // Background preloading of subcategory products
  Future<void> _preloadSubcategoryProducts(
    int subcategoryId, {
    required bool hasProductCategories,
  }) async {
    try {
      final allProducts = await _catalogService.getSubcategoryListProducts(
        subcategoryId,
        hasProductCategories: hasProductCategories,
        timeout: const Duration(seconds: 10),
      );
      if (allProducts.isNotEmpty) {
        applyLocalProductRowEnhancement(allProducts);
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
    final theme = context.appColors;
    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: null,
      body: Column(
        children: [
          CategoryBrowseAppBar(
            title: widget.categoryName,
            subtitle: _singleSubcategoryMode || _productsOnlyMode
                ? '${_allProducts.length} products'
                : '${subcategories.length} subcategories',
            eyebrow: 'Collection',
          ),
          Expanded(child: _buildMainContent()),
        ],
      ),
      floatingActionButton: CategoryBrowseScrollFab(
        visible: showScrollToTop,
        onPressed: () {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        },
      ),
      bottomNavigationBar:
          widget.showBottomNav ? const CustomBottomNav(selectedIndex: 3) : null,
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

  Widget buildBody() {
    if (isLoading && subcategories.isEmpty && !_productsOnlyMode) {
      return _buildSkeletonWithLoading();
    }

    if (_useFullWidthProductLayout) {
      return Container(
        color: SubcategoryDesign.canvasBg(context),
        child: Column(
          children: [
            _buildFullWidthProductsHeader(),
            Expanded(child: _buildProductsContent()),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 700;
        final sideNavWidth = isTablet ? 168.0 : 108.0;

        return Container(
          color: SubcategoryDesign.canvasBg(context),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: _subcategoryRailExpanded
                    ? sideNavWidth
                    : _kSubcategoryRailCollapsedWidth,
                decoration: BoxDecoration(
                  color: SubcategoryDesign.railBg(context),
                  border: Border(
                    right: BorderSide(
                        color: SubcategoryDesign.railBorder(context)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.appColors.isDark ? 0.28 : 0.05,
                      ),
                      blurRadius: 10,
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
                        color: SubcategoryDesign.contentBg(context),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: context.appColors.isDark ? 0.18 : 0.04,
                            ),
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
                                  Icon(
                                    Icons.category_outlined,
                                    size: 18,
                                    color: SubcategoryDesign.muted(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Categories',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: SubcategoryDesign.muted(context),
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
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: SubcategoryDesign.loadingOverlayPill(
              context,
              'Loading subcategories...',
            ),
          ),
        ),
      ],
    );
  }

  /// Narrow column: expand affordance only in header + compact list rows.
  Widget _buildCollapsedSubcategoryRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: SubcategoryDesign.railHeaderBg(context),
            border: Border(
              bottom: BorderSide(
                color: SubcategoryDesign.railBorder(context),
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: Tooltip(
              message: 'Expand subcategory list',
              child: Material(
                color: SubcategoryDesign.railActionBg(context),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _subcategoryRailExpanded = true),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.view_sidebar_rounded,
                      color: SubcategoryDesign.selectedInk(context),
                      size: 16,
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
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            itemCount: subcategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final sub = subcategories[index];
              final isSelected =
                  selectedSubcategoryId == categoryIdFromApi(sub['id']);
              return CategorySubcategoryRailTile(
                label: sub['name']?.toString() ?? 'Section',
                selected: isSelected,
                compact: true,
                onTap: () => onSubcategorySelected(sub['id']),
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
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: SubcategoryDesign.railHeaderBg(context),
            border: Border(
              bottom: BorderSide(
                color: SubcategoryDesign.railBorder(context),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Browse',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: SubcategoryDesign.muted(context),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Tooltip(
                message: 'Collapse list — more space for products',
                child: Material(
                  color: SubcategoryDesign.railActionBg(context),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _subcategoryRailExpanded = false),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        size: 16,
                        color: SubcategoryDesign.selectedInk(context),
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
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            itemCount: subcategories.length,
            itemBuilder: (context, index) {
              final subcategory = subcategories[index];
              final isSelected =
                  selectedSubcategoryId == categoryIdFromApi(subcategory['id']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: CategorySubcategoryRailTile(
                  label: subcategory['name']?.toString() ?? 'Section',
                  selected: isSelected,
                  onTap: () => onSubcategorySelected(subcategory['id']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthProductsHeader() {
    var title = widget.categoryName;
    var subtitle = '${_allProducts.length} products in this collection';

    if (_singleSubcategoryMode) {
      final subName = _subcategoryHeaderRow()['name']?.toString().trim();
      if (subName != null && subName.isNotEmpty) {
        title = subName;
        subtitle = '${widget.categoryName} · ${_allProducts.length} items';
      }
    }

    return CategorySectionHeader(
      title: title,
      subtitle: subtitle,
      itemCount: _allProducts.isEmpty ? null : _allProducts.length,
    );
  }

  Widget buildSubcategoryHeader() {
    final selectedSubcategory = _subcategoryHeaderRow();
    final title = selectedSubcategoryId != null
        ? (selectedSubcategory['name']?.toString() ?? 'All products')
        : 'All products';

    return CategorySectionHeader(
      title: title,
      subtitle: '${_allProducts.length} products in this section',
      itemCount: _allProducts.isEmpty ? null : _allProducts.length,
    );
  }

  Widget _buildProductsContent() {
    Widget child;
    final stateKey = isLoading
        ? 'loading'
        : errorMessage.isNotEmpty
            ? 'error'
            : _allProducts.isEmpty
                ? 'empty'
                : 'grid';
    if (isLoading) {
      child = buildProductsLoadingState();
    } else if (errorMessage.isNotEmpty) {
      child = buildProductsErrorState();
    } else if (_allProducts.isEmpty) {
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
      context,
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
        // Use product-pane width (not full screen) — side rail eats space on phones.
        final metrics = categoryProductGridMetrics(constraints.maxWidth);
        final crossAxisCount = metrics.crossAxisCount;
        final horizontalPadding = metrics.horizontalPadding;
        final spacing = metrics.spacing;
        final childAspectRatio = metrics.childAspectRatio;
        final isCompact = metrics.compact;

        final totalPages =
            _CategoryProductPagination.totalPages(_allProducts.length);

        return Column(
          children: [
            _buildCategoryProductPaginationBar(
              context: context,
              currentPage: _currentProductPage,
              totalPages: totalPages,
              totalItems: _allProducts.length,
              onPrevious: () => _goToProductPage(_currentProductPage - 1),
              onNext: () => _goToProductPage(_currentProductPage + 1),
            ),
            Expanded(
              child: RefreshIndicator(
                color: SubcategoryDesign.accent(context),
                backgroundColor: SubcategoryDesign.contentBg(context),
                onRefresh: _refreshSelectedSubcategory,
                child: GridView.builder(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    4,
                    horizontalPadding,
                    12,
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
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        openBuilder: (context, _) =>
                            _CategoryProductDetailRoute(product: product),
                        closedBuilder: (context, openContainer) => ProductCard(
                          product: product,
                          onTap: openContainer,
                          compact: isCompact,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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
        valueColor: AlwaysStoppedAnimation<Color>(
          SubcategoryDesign.accent(context),
        ),
      ),
    );
  }

  Widget buildProductsLoadingState() {
    final shimmer = SubcategoryDesign.shimmerColors(context);
    return Shimmer.fromColors(
      baseColor: shimmer.$1,
      highlightColor: shimmer.$2,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio:
              MediaQuery.sizeOf(context).width >= 520 ? 0.74 : 0.54,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SubcategoryDesign.imageWellTop(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 48,
                        decoration: BoxDecoration(
                          color: SubcategoryDesign.railBorder(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: SubcategoryDesign.railBorder(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 72,
                        decoration: BoxDecoration(
                          color: SubcategoryDesign.railBorder(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildErrorState(String message) {
    return _buildCatalogErrorPanel(
      context,
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
            color: SubcategoryDesign.muted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: SubcategoryDesign.ink(context),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: SubcategoryDesign.muted(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.compact = false,
  });

  bool _isPrescribed(Map<String, dynamic> data) {
    final otcpom = data['otcpom']?.toString().toLowerCase();
    return otcpom == 'pom';
  }

  String? _stockQuantity(Map<String, dynamic> data) {
    final qty = data['qty_in_stock'] ?? data['quantity'];
    if (qty == null) return null;
    return qty.toString();
  }

  String _priceLabel(Map<String, dynamic> data) {
    final raw = data['unit_price'] ?? data['price'] ?? data['selling_price'];
    final parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'View details';
    return 'GH₵ ${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    if (product is! Map) {
      return const SizedBox.shrink();
    }
    final data = Map<String, dynamic>.from(product);
    final productName = data['name']?.toString() ?? 'Product';
    final brandName = data['brand_name']?.toString().trim() ?? '';
    final isPrescribed = _isPrescribed(data);
    final stockQty = _stockQuantity(data);
    final inStock = stockQty == null
        ? true
        : StockUtilityService.isProductInStock(stockQty);
    final isLowStock =
        stockQty != null && StockUtilityService.isLowStock(stockQty);
    final imageUrl = getProductImageUrl(data['thumbnail']?.toString());
    final cardRadius = compact ? 12.0 : 14.0;
    final imagePadding = compact ? 5.0 : 6.0;
    final contentPadding = compact
        ? const EdgeInsets.fromLTRB(7, 5, 7, 7)
        : const EdgeInsets.fromLTRB(8, 6, 8, 8);
    final titleSize = compact ? 10.5 : 11.5;
    final priceSize = compact ? 11.0 : 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: theme.border),
            boxShadow: SubcategoryDesign.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    imagePadding,
                    imagePadding,
                    imagePadding,
                    0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(compact ? 7 : 8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                SubcategoryDesign.imageWellTop(context),
                                SubcategoryDesign.imageWellBottom(context),
                              ],
                            ),
                          ),
                        ),
                        if (imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            memCacheWidth: 220,
                            memCacheHeight: 220,
                            maxWidthDiskCache: 260,
                            maxHeightDiskCache: 260,
                            cacheKey:
                                'subcat_${data['id']}_${data['thumbnail']}',
                            fadeInDuration: const Duration(milliseconds: 120),
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(
                                Icons.medical_services_outlined,
                                color:
                                    SubcategoryDesign.placeholderIcon(context),
                                size: compact ? 24 : 28,
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Icon(
                              Icons.medical_services_outlined,
                              color: SubcategoryDesign.placeholderIcon(context),
                              size: compact ? 24 : 28,
                            ),
                          ),
                        if (!inStock)
                          Container(
                            color: SubcategoryDesign.outOfStockScrim(context),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Out of stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (isPrescribed || (isLowStock && inStock))
                          Positioned(
                            top: compact ? 4 : 6,
                            left: compact ? 4 : 6,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPrescribed)
                                  _SubcategoryProductBadge(
                                    label: 'Rx',
                                    background: const Color(0xFFDC2626),
                                    compact: compact,
                                  ),
                                if (isLowStock && inStock) ...[
                                  if (isPrescribed) const SizedBox(width: 3),
                                  _SubcategoryProductBadge(
                                    label: compact ? 'Low' : 'Low stock',
                                    background: const Color(0xFFEA580C),
                                    compact: compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (brandName.isNotEmpty && !compact)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: SubcategoryDesign.brandChipBg(context),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: SubcategoryDesign.brandChipBorder(context),
                          ),
                        ),
                        child: Text(
                          brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: SubcategoryDesign.selectedInk(context),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    Text(
                      productName,
                      maxLines: compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: theme.ink,
                        height: compact ? 1.2 : 1.25,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 6 : 7,
                              vertical: compact ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? SubcategoryDesign.selectedTint(context)
                                  : theme.fieldBg,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: inStock
                                    ? SubcategoryDesign.selectedBorder(context)
                                    : theme.border,
                              ),
                            ),
                            child: Text(
                              _priceLabel(data),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: priceSize,
                                fontWeight: FontWeight.w800,
                                color: inStock
                                    ? SubcategoryDesign.selectedInk(context)
                                    : theme.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: compact ? 10 : 11,
                          color: inStock
                              ? SubcategoryDesign.accent(context)
                              : SubcategoryDesign.muted(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryProductBadge extends StatelessWidget {
  const _SubcategoryProductBadge({
    required this.label,
    required this.background,
    this.compact = false,
  });

  final String label;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 5 : 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w700,
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
  List<dynamic> _allProducts = [];
  int _currentProductPage = 0;
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
    scrollController.addListener(_onProductListScroll);
  }

  void _onProductListScroll() {
    if (!mounted || !scrollController.hasClients) return;

    final shouldShow = scrollController.offset > 300;
    if (showScrollToTop != shouldShow) {
      setState(() {
        showScrollToTop = shouldShow;
      });
    }
  }

  void _applyPagedProducts(List<dynamic> all, {int page = 0}) {
    _allProducts = all;
    final total = _CategoryProductPagination.totalPages(all.length);
    _currentProductPage = page.clamp(0, total - 1);
    products =
        _CategoryProductPagination.itemsForPage(all, _currentProductPage);
  }

  void _goToProductPage(int page) {
    if (_allProducts.isEmpty || !mounted) return;
    final total = _CategoryProductPagination.totalPages(_allProducts.length);
    final safe = page.clamp(0, total - 1);
    if (safe == _currentProductPage) return;
    setState(() {
      _currentProductPage = safe;
      products = _CategoryProductPagination.itemsForPage(
        _allProducts,
        _currentProductPage,
      );
    });
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  void _ensurePagedThroughProductIndex(int index) {
    _goToProductPage(_CategoryProductPagination.pageForIndex(index));
  }

  @override
  void dispose() {
    scrollController.removeListener(_onProductListScroll);
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
      final cached = _listCache[widget.categoryId]!
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (categoryListRowsAreProducts(cached)) {
        debugPrint(
            '🔍 Using cached products for category ${widget.categoryId}');
        applyLocalProductRowEnhancement(cached);
        if (mounted) {
          setState(() {
            _applyPagedProducts(List<dynamic>.from(cached));
            isLoading = false;
            errorMessage = '';
          });
        }
        if (widget.searchedProductId != null) {
          _highlightSearchedProduct();
        }
        unawaited(_enhanceProductsInBackground(cached));
        return;
      }
      _listCache.remove(widget.categoryId);
      _listCacheTime.remove(widget.categoryId);
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
        products = [];
        _allProducts = [];
        _currentProductPage = 0;
      });

      final loaded = await _catalogService.fetchResolvedCategoryProducts(
        widget.categoryId,
        timeout: const Duration(seconds: 12),
      );

      if (loaded.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage =
              AppErrorUtils.catalogLoadMessage(ProductDetailErrorKind.notFound);
        });
        return;
      }

      applyLocalProductRowEnhancement(loaded);
      _listCache[widget.categoryId] = loaded;
      _listCacheTime[widget.categoryId] = DateTime.now();
      _allProducts = loaded;

      if (!mounted) return;
      setState(() {
        _applyPagedProducts(_allProducts);
        isLoading = false;
      });

      if (widget.searchedProductId != null) {
        _highlightSearchedProduct();
      }
      unawaited(_enhanceProductsInBackground(loaded));
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

  Future<void> _enhanceProductsInBackground(List<dynamic> products) async {
    if (!productsNeedNetworkEnhancement(products)) return;

    try {
      await mergeProductSlugsFromNetwork(products, _catalogService);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('🔍 Background product enhancement failed: $e');
    }
  }

  void _highlightSearchedProduct() {
    if (widget.searchedProductId != null && mounted) {
      setState(() {
        highlightedProductId = widget.searchedProductId;
      });

      // Find the index of the searched product
      final productIndex = _allProducts.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        _ensurePagedThroughProductIndex(productIndex);
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
      backgroundColor: SubcategoryDesign.pageBg(context),
      body: Column(
        children: [
          CategoryBrowseAppBar(
            title: widget.categoryName,
            subtitle: isLoading
                ? 'Loading collection…'
                : '${_allProducts.length} products',
            eyebrow: 'Category',
          ),
          Expanded(
            child: Container(
              color: SubcategoryDesign.canvasBg(context),
              child: Column(
                children: [
                  CategorySectionHeader(
                    title: widget.categoryName,
                    subtitle: isLoading
                        ? 'Curating products for you'
                        : '${_allProducts.length} items in this department',
                    itemCount:
                        _allProducts.isEmpty ? null : _allProducts.length,
                  ),
                  Expanded(child: _buildProductsList()),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: CategoryBrowseScrollFab(
        visible: showScrollToTop,
        onPressed: () {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        },
      ),
    );
  }

  Widget _buildProductsList() {
    if (isLoading) {
      return _buildSkeletonWithLoading();
    }

    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_allProducts.isEmpty) {
      return _buildEmptyState();
    }

    final totalPages =
        _CategoryProductPagination.totalPages(_allProducts.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = categoryProductGridMetrics(constraints.maxWidth);

        return Column(
          children: [
            _buildCategoryProductPaginationBar(
              context: context,
              currentPage: _currentProductPage,
              totalPages: totalPages,
              totalItems: _allProducts.length,
              onPrevious: () => _goToProductPage(_currentProductPage - 1),
              onNext: () => _goToProductPage(_currentProductPage + 1),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => fetchProducts(forceRefresh: true),
                color: SubcategoryDesign.accent(context),
                backgroundColor: SubcategoryDesign.contentBg(context),
                child: GridView.builder(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    metrics.horizontalPadding,
                    4,
                    metrics.horizontalPadding,
                    12,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: metrics.crossAxisCount,
                    childAspectRatio: metrics.childAspectRatio,
                    crossAxisSpacing: metrics.spacing,
                    mainAxisSpacing: metrics.spacing,
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
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        openBuilder: (context, _) =>
                            _CategoryProductDetailRoute(product: product),
                        closedBuilder: (context, openContainer) => ProductCard(
                          product: product,
                          onTap: openContainer,
                          compact: metrics.compact,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const ProductListPageSkeletonBody(),
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: SubcategoryDesign.loadingOverlayPill(
              context,
              'Loading products...',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return _buildCatalogErrorPanel(
      context,
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
          subtitle: categoryName != null
              ? Text(
                  'Category: $categoryName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )
              : null,
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
