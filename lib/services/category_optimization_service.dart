// services/category_optimization_service.dart
// services/category_optimization_service.dart
// services/category_optimization_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../services/category_catalog_service.dart';
import '../services/product_image_preload_service.dart';
import '../utils/category_utils.dart';
import 'app_optimization_service.dart';

class CategoryOptimizationService {
  static final CategoryOptimizationService _instance =
      CategoryOptimizationService._internal();
  factory CategoryOptimizationService() => _instance;
  CategoryOptimizationService._internal();

  final CategoryCatalogService _catalogService = CategoryCatalogService();

  // Cache storage keys
  static const String _categoriesCacheKey = 'categories_cache';
  static const String _categoriesCacheTimeKey = 'categories_cache_time';
  static const String _productsCacheKey = 'products_cache';
  static const String _productsCacheTimeKey = 'products_cache_time';

  static const Duration _categoriesCacheDuration =
      Duration(hours: 4); // Extended from 1 hour to 4 hours
  static const Duration _productsCacheDuration =
      Duration(hours: 2); // Extended from 30 minutes to 2 hours
  static const Duration _subcategoriesCacheDuration = Duration(minutes: 30);
  static const int _subcategoryPrefetchConcurrency = 4;
  static const int _maxCachedProducts = 1000;

  // In-memory cache
  List<dynamic> _cachedCategories = [];
  List<dynamic> _cachedProducts = [];
  final Map<int, List<dynamic>> _cachedSubcategoriesByCategoryId = {};
  final Map<int, DateTime> _subcategoriesCacheTimeByCategoryId = {};
  final Map<int, bool> _subcategoryCache = {}; // Cache for subcategory info
  DateTime? _categoriesCacheTime;
  DateTime? _productsCacheTime;
  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;
  bool _isPrefetchingSubcategories = false;

  // Image preloading
  final Map<String, bool> _preloadedImages = {};

  // Performance monitoring
  final AppOptimizationService _optimizationService = AppOptimizationService();

  // Getters
  List<dynamic> get cachedCategories => List.unmodifiable(_cachedCategories);
  List<dynamic> get cachedProducts => List.unmodifiable(_cachedProducts);

  bool get isCategoriesCacheValid {
    if (_categoriesCacheTime == null) return false;
    return DateTime.now().difference(_categoriesCacheTime!) <
        _categoriesCacheDuration;
  }

  bool get isProductsCacheValid {
    if (_productsCacheTime == null) return false;
    return DateTime.now().difference(_productsCacheTime!) <
        _productsCacheDuration;
  }

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPrefetchingSubcategories => _isPrefetchingSubcategories;
  bool get hasCachedCategories => _cachedCategories.isNotEmpty;
  bool get hasCachedProducts => _cachedProducts.isNotEmpty;

  Map<int, List<dynamic>> get cachedSubcategoriesByCategoryId =>
      Map.unmodifiable(_cachedSubcategoriesByCategoryId);

  bool isSubcategoriesCacheValid(int categoryId) {
    final timestamp = _subcategoriesCacheTimeByCategoryId[categoryId];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _subcategoriesCacheDuration;
  }

  List<dynamic>? getCachedSubcategories(int categoryId) {
    if (!isSubcategoriesCacheValid(categoryId)) return null;
    final cached = _cachedSubcategoriesByCategoryId[categoryId];
    if (cached == null) return null;
    return List<dynamic>.from(cached);
  }

  void cacheSubcategories(int categoryId, List<dynamic> subcategories) {
    _cachedSubcategoriesByCategoryId[categoryId] =
        List<dynamic>.from(subcategories);
    _subcategoriesCacheTimeByCategoryId[categoryId] = DateTime.now();
    _subcategoryCache[categoryId] = subcategories.isNotEmpty;
  }

  void invalidateSubcategoriesCache(int categoryId) {
    _cachedSubcategoriesByCategoryId.remove(categoryId);
    _subcategoriesCacheTimeByCategoryId.remove(categoryId);
    _subcategoryCache.remove(categoryId);
  }

  /// True when every top-level category with subcategories has a fresh cache row.
  bool get hasPrefetchedAllSubcategories {
    if (!hasCachedCategories) return false;
    for (final category in _cachedCategories) {
      if (!categoryHasSubcategoriesFromApi(category)) continue;
      final categoryId = categoryIdFromApi(category['id']);
      if (categoryId <= 0) continue;
      if (!isSubcategoriesCacheValid(categoryId)) return false;
    }
    return true;
  }

  // Check if a category has subcategories (from cache)
  bool hasSubcategoryInfo(int categoryId) {
    return _subcategoryCache[categoryId] ?? false;
  }

  // Initialize service
  Future<void> initialize() async {
    debugPrint('Initializing CategoryOptimizationService...');
    final stopwatch = Stopwatch()..start();

    // Load from storage immediately without blocking
    await _loadFromStorage();

    stopwatch.stop();
    debugPrint(
        'CategoryOptimizationService initialized in ${stopwatch.elapsedMilliseconds}ms with ${_cachedCategories.length} categories and ${_cachedProducts.length} products');
    debugPrint('Categories cache valid: $isCategoriesCacheValid');
    debugPrint('Products cache valid: $isProductsCacheValid');
  }

  // Get categories with optimized caching
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetCategories');

    // Return cached categories if valid and not forcing refresh
    if (isCategoriesCacheValid && hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      debugPrint(
          'Category cache hit: ${_cachedCategories.length} categories returned from cache');
      return cachedCategories;
    }

    // If we have stale cache, return it immediately and refresh in background
    if (hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      debugPrint(
          'Category cache expired but returning cached data while refreshing in background');

      // Refresh in background without blocking
      _refreshCategoriesInBackground();

      return cachedCategories;
    }

    // If already loading, wait for current request
    if (_isLoadingCategories) {
      debugPrint('Category request already in progress, waiting...');
      while (_isLoadingCategories) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('CategoryService_GetCategories');
      return cachedCategories;
    }

    // Fetch fresh categories
    return await _fetchCategoriesFromAPI();
  }

  // Refresh categories in background without blocking UI
  Future<void> _refreshCategoriesInBackground() async {
    if (_isLoadingCategories) return; // Don't start multiple refreshes

    try {
      await _fetchCategoriesFromAPI();
    } catch (e) {
      debugPrint('Background category refresh failed: $e');
      // Keep using old cache data
    }
  }

  // Get products with optimized caching
  Future<List<dynamic>> getProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetProducts');

    // Return cached products if valid and not forcing refresh
    if (isProductsCacheValid && hasCachedProducts && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      debugPrint(
          'Product cache hit: ${_cachedProducts.length} products returned from cache');
      return cachedProducts;
    }

    // If we have stale cache, return it immediately and refresh in background
    if (hasCachedProducts && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      debugPrint(
          'Product cache expired but returning cached data while refreshing in background');

      // Refresh in background without blocking
      _refreshProductsInBackground();

      return cachedProducts;
    }

    // If already loading, wait for current request
    if (_isLoadingProducts) {
      while (_isLoadingProducts) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _optimizationService.endTimer('CategoryService_GetProducts');
      return cachedProducts;
    }

    // Fetch fresh products
    return await _fetchProductsFromAPI();
  }

  // Refresh products in background without blocking UI
  Future<void> _refreshProductsInBackground() async {
    if (_isLoadingProducts) return; // Don't start multiple refreshes

    try {
      await _fetchProductsFromAPI();
    } catch (e) {
      debugPrint('Background product refresh failed: $e');
      // Keep using old cache data
    }
  }

  /// Prefetch subcategory lists for all categories that expose a subcategory tree.
  Future<bool> prefetchAllSubcategories({
    Duration maxWait = const Duration(minutes: 2),
  }) async {
    if (hasPrefetchedAllSubcategories) return true;

    if (_isPrefetchingSubcategories) {
      final deadline = DateTime.now().add(maxWait);
      while (_isPrefetchingSubcategories && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return hasPrefetchedAllSubcategories;
    }

    _isPrefetchingSubcategories = true;
    final deadline = DateTime.now().add(maxWait);

    try {
      final categories = hasCachedCategories
          ? cachedCategories
          : await getCategories();

      final targets = categories
          .where(categoryHasSubcategoriesFromApi)
          .map((category) => categoryIdFromApi(category['id']))
          .where((id) => id > 0)
          .where((id) => !isSubcategoriesCacheValid(id))
          .toList();

      if (targets.isEmpty) return hasPrefetchedAllSubcategories;

      debugPrint(
        'CategoryOptimizationService: prefetching subcategories for '
        '${targets.length} categories',
      );

      for (var i = 0; i < targets.length; i += _subcategoryPrefetchConcurrency) {
        if (DateTime.now().isAfter(deadline)) break;

        final batch = targets.skip(i).take(_subcategoryPrefetchConcurrency);
        await Future.wait(
          batch.map((categoryId) async {
            try {
              final subcategories = await _catalogService.getSubcategories(
                categoryId,
                timeout: const Duration(seconds: 8),
              );
              cacheSubcategories(categoryId, subcategories);
            } catch (e) {
              debugPrint(
                'CategoryOptimizationService: subcategories for '
                '$categoryId failed: $e',
              );
            }
          }),
        );
      }

      return hasPrefetchedAllSubcategories;
    } finally {
      _isPrefetchingSubcategories = false;
    }
  }

  // Fetch categories from API with optimized timeout
  Future<List<dynamic>> _fetchCategoriesFromAPI() async {
    _isLoadingCategories = true;

    try {
      debugPrint('Fetching categories from API...');
      final stopwatch = Stopwatch()..start();

      final categories = await _catalogService.getTopCategories(
        timeout: const Duration(seconds: 8),
      );

      stopwatch.stop();
      debugPrint(
          'Category API call completed in ${stopwatch.elapsedMilliseconds}ms');

      await _cacheCategories(categories);

      _optimizationService.endTimer('CategoryService_GetCategories');
      debugPrint(
          'Successfully fetched ${categories.length} categories from API');
      return categories;
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      debugPrint('Category API error: $e');
      rethrow;
    } finally {
      _isLoadingCategories = false;
    }
  }

  // Fetch products from API with optimized concurrent loading
  Future<List<dynamic>> _fetchProductsFromAPI() async {
    _isLoadingProducts = true;

    try {
      debugPrint('Fetching products from API...');
      final stopwatch = Stopwatch()..start();

      debugPrint('🔍 Using get-all-products API endpoint for otcpom data...');
      final allProducts = await _catalogService.getProductsForCategoryCache(
        timeout: const Duration(seconds: 15),
      );

      debugPrint('🔍 Total products in response: ${allProducts.length}');
      if (allProducts.isNotEmpty) {
        debugPrint('🔍 First product otcpom: ${allProducts.first['otcpom']}');
      }

      for (int i = 0; i < allProducts.length && i < 3; i++) {
        debugPrint(
            '🔍 Converted product ${allProducts[i]['name']}: otcpom=${allProducts[i]['otcpom']}');
      }

      if (allProducts.length > _maxCachedProducts) {
        allProducts.removeRange(_maxCachedProducts, allProducts.length);
      }

      await _cacheProducts(allProducts);

      stopwatch.stop();
      debugPrint(
          'Product API calls completed in ${stopwatch.elapsedMilliseconds}ms');

      _optimizationService.endTimer('CategoryService_GetProducts');
      debugPrint(
          'Successfully fetched ${allProducts.length} products from API with otcpom data');
      return allProducts;
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      debugPrint('Product API error: $e');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // Cache categories
  Future<void> _cacheCategories(List<dynamic> categories) async {
    _cachedCategories = categories;
    _categoriesCacheTime = DateTime.now();
    // Save to storage in background without blocking
    _saveCategoriesToStorage();
    debugPrint(
        'Categories cached successfully: ${categories.length} categories');
  }

  // Cache products
  Future<void> _cacheProducts(List<dynamic> products) async {
    _cachedProducts = products;
    _productsCacheTime = DateTime.now();
    // Save to storage in background without blocking
    _saveProductsToStorage();
    debugPrint('Products cached successfully: ${products.length} products');
  }

  // Save categories to persistent storage
  Future<void> _saveCategoriesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _categoriesCacheKey, json.encode(_cachedCategories));
      await prefs.setString(
          _categoriesCacheTimeKey, _categoriesCacheTime!.toIso8601String());
    } catch (e) {
      debugPrint('Failed to save categories cache: $e');
    }
  }

  // Save products to persistent storage
  Future<void> _saveProductsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_productsCacheKey, json.encode(_cachedProducts));
      await prefs.setString(
          _productsCacheTimeKey, _productsCacheTime!.toIso8601String());
    } catch (e) {
      debugPrint('Failed to save products cache: $e');
    }
  }

  // Load from persistent storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load categories
      final categoriesJson = prefs.getString(_categoriesCacheKey);
      final categoriesTimeString = prefs.getString(_categoriesCacheTimeKey);

      if (categoriesJson != null && categoriesTimeString != null) {
        _cachedCategories = json.decode(categoriesJson) as List;
        _categoriesCacheTime = DateTime.parse(categoriesTimeString);
        debugPrint(
            'Loaded ${_cachedCategories.length} categories from storage cache');
      }

      // Load products
      final productsJson = prefs.getString(_productsCacheKey);
      final productsTimeString = prefs.getString(_productsCacheTimeKey);

      if (productsJson != null && productsTimeString != null) {
        _cachedProducts = json.decode(productsJson) as List;
        _productsCacheTime = DateTime.parse(productsTimeString);
        debugPrint(
            'Loaded ${_cachedProducts.length} products from storage cache');
      }
    } catch (e) {
      debugPrint('Failed to load category cache: $e');
      _cachedCategories = [];
      _cachedProducts = [];
      _categoriesCacheTime = null;
      _productsCacheTime = null;
    }
  }

  // Preload category images to disk (and memory when [context] is available).
  Future<void> preloadCategoryImages(
      BuildContext context, List<dynamic> categories) async {
    final imageUrls =
        ProductImagePreloadService.collectCategoryImageUrls(categories);
    if (imageUrls.isEmpty) return;

    debugPrint('Preloading ${imageUrls.length} category images...');
    unawaited(
      ProductImagePreloadService.warmCategoryImageUrls(
        urls: imageUrls,
        maxWait: const Duration(seconds: 45),
      ),
    );

    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        try {
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
                  'Skipping preload category image (may be missing): $imageUrl');
            },
          );
        } catch (e) {
          debugPrint('Failed to preload category image: $imageUrl - $e');
        }
      }
    }

    debugPrint('Category image preloading completed');
  }

  // Search products with caching
  Future<List<dynamic>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final products = await getProducts();

    return products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final description =
          product['description']?.toString().toLowerCase() ?? '';
      final categoryName =
          product['category_name']?.toString().toLowerCase() ?? '';
      final subcategoryName =
          product['subcategory_name']?.toString().toLowerCase() ?? '';

      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) ||
          description.contains(searchQuery) ||
          categoryName.contains(searchQuery) ||
          subcategoryName.contains(searchQuery);
    }).toList();
  }

  // Clear all caches
  Future<void> clearAllCaches() async {
    debugPrint('Clearing all category caches...');
    _cachedCategories.clear();
    _cachedProducts.clear();
    _cachedSubcategoriesByCategoryId.clear();
    _subcategoriesCacheTimeByCategoryId.clear();
    _subcategoryCache.clear();
    _categoriesCacheTime = null;
    _productsCacheTime = null;
    _preloadedImages.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoriesCacheKey);
      await prefs.remove(_categoriesCacheTimeKey);
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_productsCacheTimeKey);
      debugPrint('Category cache cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear category cache: $e');
    }
  }

  // Force refresh cache for testing
  Future<void> forceRefreshCache() async {
    debugPrint('Forcing category cache refresh...');
    await clearAllCaches();
    await getCategories(forceRefresh: true);
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'categories_count': _cachedCategories.length,
      'products_count': _cachedProducts.length,
      'categories_cache_valid': isCategoriesCacheValid,
      'products_cache_valid': isProductsCacheValid,
      'categories_cache_time': _categoriesCacheTime?.toIso8601String(),
      'products_cache_time': _productsCacheTime?.toIso8601String(),
      'is_loading_categories': _isLoadingCategories,
      'is_loading_products': _isLoadingProducts,
      'preloaded_images_count': _preloadedImages.length,
      'categories_cache_duration_hours': _categoriesCacheDuration.inHours,
      'products_cache_duration_hours': _productsCacheDuration.inHours,
    };
  }

  // Print performance summary
  void printPerformanceSummary() {
    final stats = getCacheStats();
    debugPrint('=== Category Service Performance Summary ===');
    debugPrint('Cached Categories: ${stats['categories_count']}');
    debugPrint('Cached Products: ${stats['products_count']}');
    debugPrint('Categories Cache Valid: ${stats['categories_cache_valid']}');
    debugPrint('Products Cache Valid: ${stats['products_cache_valid']}');
    debugPrint(
        'Categories Cache Duration: ${stats['categories_cache_duration_hours']} hours');
    debugPrint(
        'Products Cache Duration: ${stats['products_cache_duration_hours']} hours');
    debugPrint('Preloaded Images: ${stats['preloaded_images_count']}');
    debugPrint('============================================');
  }

  // Refresh all data
  Future<void> refreshAllData() async {
    await getCategories(forceRefresh: true);
    await getProducts(forceRefresh: true);
  }
}
