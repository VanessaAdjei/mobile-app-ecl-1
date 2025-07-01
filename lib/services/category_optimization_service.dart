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

  // Cache configuration
  static const Duration _categoriesCacheDuration =
      Duration(minutes: 60); // 1 hour
  static const Duration _productsCacheDuration =
      Duration(minutes: 30); // 30 minutes
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
    // Load from storage in background without blocking
    _loadFromStorage();
    _optimizationService.startTimer('CategoryService_Initialize');
  }

  // Get categories with caching
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetCategories');

    // Return cached categories if valid and not forcing refresh
    if (isCategoriesCacheValid && hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      return cachedCategories;
    }

    // If already loading, wait for current request
    if (_isLoadingCategories) {
      while (_isLoadingCategories) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('CategoryService_GetCategories');
      return cachedCategories;
    }

    // If we have stale cache, return it immediately and refresh in background
    if (hasCachedCategories && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      // Refresh in background
      _fetchCategoriesFromAPI();
      return cachedCategories;
    }

    // Fetch fresh categories
    return await _fetchCategoriesFromAPI();
  }

  // Get products with caching
  Future<List<dynamic>> getProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CategoryService_GetProducts');

    // Return cached products if valid and not forcing refresh
    if (isProductsCacheValid && hasCachedProducts && !forceRefresh) {
      _optimizationService.endTimer('CategoryService_GetProducts');
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

  // Fetch categories from API
  Future<List<dynamic>> _fetchCategoriesFromAPI() async {
    _isLoadingCategories = true;

    try {
      // Direct API call without additional caching overhead
      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/top-categories'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final categories = data['data'] as List;

          // Cache the categories
          await _cacheCategories(categories);

          _optimizationService.endTimer('CategoryService_GetCategories');
          return categories;
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetCategories');
      rethrow;
    } finally {
      _isLoadingCategories = false;
    }
  }

  // Fetch products from API with concurrent loading
  Future<List<dynamic>> _fetchProductsFromAPI() async {
    _isLoadingProducts = true;

    try {
      // First get categories if not available
      final categories = await getCategories();

      // Fetch products for all categories concurrently
      final allProducts = <dynamic>[];
      final futures = <Future<List<dynamic>>>[];

      for (final category in categories) {
        futures.add(_fetchProductsForCategory(category));
      }

      // Wait for all requests with timeout
      final results = await Future.wait(futures).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          // Return what we have so far
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

      _optimizationService.endTimer('CategoryService_GetProducts');
      return allProducts;
    } catch (e) {
      _optimizationService.endTimer('CategoryService_GetProducts');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // Fetch products for a specific category
  Future<List<dynamic>> _fetchProductsForCategory(dynamic category) async {
    try {
      // Get subcategories first
      final subcategoriesResponse = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/categories/${category['id']}'),
          )
          .timeout(const Duration(seconds: 10));

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
      // Continue with other categories
    }
    return <dynamic>[];
  }

  // Fetch products for a specific subcategory
  Future<List<dynamic>> _fetchProductsForSubcategory(
      dynamic category, dynamic subcategory) async {
    try {
      final subcategoryId = subcategory['id'];
      final subcategoryName = subcategory['name'];

      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId'))
          .timeout(const Duration(seconds: 10));

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
  }

  // Cache products
  Future<void> _cacheProducts(List<dynamic> products) async {
    _cachedProducts = products;
    _productsCacheTime = DateTime.now();
    // Save to storage in background without blocking
    _saveProductsToStorage();
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
      }

      // Load products
      final productsJson = prefs.getString(_productsCacheKey);
      final productsTimeString = prefs.getString(_productsCacheTimeKey);

      if (productsJson != null && productsTimeString != null) {
        _cachedProducts = json.decode(productsJson) as List;
        _productsCacheTime = DateTime.parse(productsTimeString);
      }
    } catch (e) {
      print('Failed to load category cache: $e');
      _cachedCategories = [];
      _cachedProducts = [];
      _categoriesCacheTime = null;
      _productsCacheTime = null;
    }
  }

  // Preload category images
  Future<void> preloadCategoryImages(
      BuildContext context, List<dynamic> categories) async {
    final imageUrls = categories
        .take(10) // Preload first 10 category images
        .map((category) => _getCategoryImageUrl(category['image_url']))
        .where((url) => url.isNotEmpty)
        .toList();

    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    }
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
    } catch (e) {
      print('Failed to clear category cache: $e');
    }
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
      'categories_cache_duration_minutes': _categoriesCacheDuration.inMinutes,
      'products_cache_duration_minutes': _productsCacheDuration.inMinutes,
    };
  }

  // Refresh all data
  Future<void> refreshAllData() async {
    await getCategories(forceRefresh: true);
    await getProducts(forceRefresh: true);
  }
}
