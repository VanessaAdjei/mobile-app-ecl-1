// services/category_optimization_service.dart
// services/category_optimization_service.dart
// services/category_optimization_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_optimization_service.dart';

class CategoryOptimizationService {
  static final CategoryOptimizationService _instance =
      CategoryOptimizationService._internal();
  factory CategoryOptimizationService() => _instance;
  CategoryOptimizationService._internal();

  // Cache storage keys
  static const String _categoriesCacheKey = 'categories_cache';
  static const String _categoriesCacheTimeKey = 'categories_cache_time';
  static const String _productsCacheKey = 'products_cache';
  static const String _productsCacheTimeKey = 'products_cache_time';

  static const Duration _categoriesCacheDuration =
      Duration(hours: 4); // Extended from 1 hour to 4 hours
  static const Duration _productsCacheDuration =
      Duration(hours: 2); // Extended from 30 minutes to 2 hours
  static const int _maxCachedProducts = 1000;

  // In-memory cache
  List<dynamic> _cachedCategories = [];
  List<dynamic> _cachedProducts = [];
  DateTime? _categoriesCacheTime;
  DateTime? _productsCacheTime;
  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;

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
  bool get hasCachedCategories => _cachedCategories.isNotEmpty;
  bool get hasCachedProducts => _cachedProducts.isNotEmpty;

  // Initialize service
  Future<void> initialize() async {
    print('Initializing CategoryOptimizationService...');
    final stopwatch = Stopwatch()..start();

    // Load from storage immediately without blocking
    await _loadFromStorage();

    stopwatch.stop();
    print(
        'CategoryOptimizationService initialized in ${stopwatch.elapsedMilliseconds}ms with ${_cachedCategories.length} categories and ${_cachedProducts.length} products');
    print('Categories cache valid: $isCategoriesCacheValid');
    print('Products cache valid: $isProductsCacheValid');
  }

  // Get categories with optimized caching
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetCategories');

    // Return cached categories if valid and not forcing refresh
    if (isCategoriesCacheValid && hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      print(
          'Category cache hit: ${_cachedCategories.length} categories returned from cache');
      return cachedCategories;
    }

    // If we have stale cache, return it immediately and refresh in background
    if (hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      print(
          'Category cache expired but returning cached data while refreshing in background');

      // Refresh in background without blocking
      _refreshCategoriesInBackground();

      return cachedCategories;
    }

    // If already loading, wait for current request
    if (_isLoadingCategories) {
      print('Category request already in progress, waiting...');
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
      print('Background category refresh failed: $e');
      // Keep using old cache data
    }
  }

  // Get products with optimized caching
  Future<List<dynamic>> getProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetProducts');

    // Return cached products if valid and not forcing refresh
    if (isProductsCacheValid && hasCachedProducts && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      print(
          'Product cache hit: ${_cachedProducts.length} products returned from cache');
      return cachedProducts;
    }

    // If we have stale cache, return it immediately and refresh in background
    if (hasCachedProducts && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      print(
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
      print('Background product refresh failed: $e');
      // Keep using old cache data
    }
  }

  // Fetch categories from API with optimized timeout
  Future<List<dynamic>> _fetchCategoriesFromAPI() async {
    _isLoadingCategories = true;

    try {
      print('Fetching categories from API...');
      final stopwatch = Stopwatch()..start();

      // Reduced timeout for faster failure detection
      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/top-categories'),
          )
          .timeout(const Duration(seconds: 8)); // Reduced from 10 to 8 seconds

      stopwatch.stop();
      print(
          'Category API call completed in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final categories = data['data'] as List;

          // Cache the categories
          await _cacheCategories(categories);

          _optimizationService.endTimer('CategoryService_GetCategories');
          print(
              'Successfully fetched ${categories.length} categories from API');
          return categories;
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      print('Category API error: $e');
      rethrow;
    } finally {
      _isLoadingCategories = false;
    }
  }

  // Fetch products from API with optimized concurrent loading
  Future<List<dynamic>> _fetchProductsFromAPI() async {
    _isLoadingProducts = true;

    try {
      print('Fetching products from API...');
      final stopwatch = Stopwatch()..start();

      // First get categories if not available
      final categories = await getCategories();

      // Fetch products for all categories concurrently with optimized timeouts
      final allProducts = <dynamic>[];
      final futures = <Future<List<dynamic>>>[];

      for (final category in categories) {
        futures.add(_fetchProductsForCategory(category));
      }

      // Wait for all requests with shorter timeout
      final results = await Future.wait(futures).timeout(
        const Duration(seconds: 30), // Reduced from 45 to 30 seconds
        onTimeout: () {
          print('Product fetch timeout, returning partial results');
          return <List<dynamic>>[];
        },
      );

      // Combine all products
      for (final productList in results) {
        allProducts.addAll(productList);
      }

      // Limit cache size
      if (allProducts.length > _maxCachedProducts) {
        allProducts.removeRange(_maxCachedProducts, allProducts.length);
      }

      // Cache the products
      await _cacheProducts(allProducts);

      stopwatch.stop();
      print(
          'Product API calls completed in ${stopwatch.elapsedMilliseconds}ms');

      _optimizationService.endTimer('CategoryService_GetProducts');
      print('Successfully fetched ${allProducts.length} products from API');
      return allProducts;
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      print('Product API error: $e');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // Fetch products for a specific category with optimized timeouts
  Future<List<dynamic>> _fetchProductsForCategory(dynamic category) async {
    try {
      // Get subcategories first with shorter timeout
      final subcategoriesResponse = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/categories/${category['id']}'),
          )
          .timeout(const Duration(seconds: 6)); // Reduced from 10 to 6 seconds

      if (subcategoriesResponse.statusCode == 200) {
        final subcategoriesData = json.decode(subcategoriesResponse.body);
        if (subcategoriesData['success'] == true) {
          final subcategories = subcategoriesData['data'] as List;

          // Fetch products for all subcategories concurrently
          final futures = <Future<List<dynamic>>>[];

          for (final subcategory in subcategories) {
            futures.add(_fetchProductsForSubcategory(category, subcategory));
          }

          final productLists = await Future.wait(futures);
          final categoryProducts = <dynamic>[];

          for (final productList in productLists) {
            categoryProducts.addAll(productList);
          }

          return categoryProducts;
        }
      }
    } catch (e) {
      print('Failed to fetch products for category ${category['name']}: $e');
      // Continue with other categories
    }
    return <dynamic>[];
  }

  // Fetch products for a specific subcategory with optimized timeout
  Future<List<dynamic>> _fetchProductsForSubcategory(
      dynamic category, dynamic subcategory) async {
    try {
      final subcategoryId = subcategory['id'];
      final subcategoryName = subcategory['name'];

      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId'))
          .timeout(const Duration(seconds: 6)); // Reduced from 10 to 6 seconds

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final products = data['data'] as List;

          return products
              .map((product) => {
                    ...product,
                    'category_id': category['id'],
                    'category_name': category['name'],
                    'subcategory_id': subcategoryId,
                    'subcategory_name': subcategoryName,
                  })
              .toList();
        }
      }
    } catch (e) {
      print(
          'Failed to fetch products for subcategory ${subcategory['name']}: $e');
      // Continue with other subcategories
    }
    return <dynamic>[];
  }

  // Cache categories
  Future<void> _cacheCategories(List<dynamic> categories) async {
    _cachedCategories = categories;
    _categoriesCacheTime = DateTime.now();
    // Save to storage in background without blocking
    _saveCategoriesToStorage();
    print('Categories cached successfully: ${categories.length} categories');
  }

  // Cache products
  Future<void> _cacheProducts(List<dynamic> products) async {
    _cachedProducts = products;
    _productsCacheTime = DateTime.now();
    // Save to storage in background without blocking
    _saveProductsToStorage();
    print('Products cached successfully: ${products.length} products');
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
      print('Failed to save categories cache: $e');
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
      print('Failed to save products cache: $e');
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
        print(
            'Loaded ${_cachedCategories.length} categories from storage cache');
      }

      // Load products
      final productsJson = prefs.getString(_productsCacheKey);
      final productsTimeString = prefs.getString(_productsCacheTimeKey);

      if (productsJson != null && productsTimeString != null) {
        _cachedProducts = json.decode(productsJson) as List;
        _productsCacheTime = DateTime.parse(productsTimeString);
        print('Loaded ${_cachedProducts.length} products from storage cache');
      }
    } catch (e) {
      print('Failed to load category cache: $e');
      _cachedCategories = [];
      _cachedProducts = [];
      _categoriesCacheTime = null;
      _productsCacheTime = null;
    }
  }

  // Preload category images with optimization
  Future<void> preloadCategoryImages(
      BuildContext context, List<dynamic> categories) async {
    final imageUrls = categories
        .take(10) // Preload first 10 category images
        .map((category) => _getCategoryImageUrl(category['image_url']))
        .where((url) => url.isNotEmpty)
        .toList();

    print('Preloading ${imageUrls.length} category images...');

    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        try {
          precacheImage(CachedNetworkImageProvider(imageUrl), context);
        } catch (e) {
          print('Failed to preload category image: $imageUrl - $e');
        }
      }
    }

    print('Category image preloading completed');
  }

  // Get category image URL
  String _getCategoryImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return 'https://eclcommerce.ernestchemists.com.gh/storage/categories/${Uri.encodeComponent(imagePath)}';
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
    print('Clearing all category caches...');
    _cachedCategories.clear();
    _cachedProducts.clear();
    _categoriesCacheTime = null;
    _productsCacheTime = null;
    _preloadedImages.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoriesCacheKey);
      await prefs.remove(_categoriesCacheTimeKey);
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_productsCacheTimeKey);
      print('Category cache cleared successfully');
    } catch (e) {
      print('Failed to clear category cache: $e');
    }
  }

  // Force refresh cache for testing
  Future<void> forceRefreshCache() async {
    print('Forcing category cache refresh...');
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
    print('=== Category Service Performance Summary ===');
    print('Cached Categories: ${stats['categories_count']}');
    print('Cached Products: ${stats['products_count']}');
    print('Categories Cache Valid: ${stats['categories_cache_valid']}');
    print('Products Cache Valid: ${stats['products_cache_valid']}');
    print(
        'Categories Cache Duration: ${stats['categories_cache_duration_hours']} hours');
    print(
        'Products Cache Duration: ${stats['products_cache_duration_hours']} hours');
    print('Preloaded Images: ${stats['preloaded_images_count']}');
    print('============================================');
  }

  // Refresh all data
  Future<void> refreshAllData() async {
    await getCategories(forceRefresh: true);
    await getProducts(forceRefresh: true);
  }
}
