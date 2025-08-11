// services/homepage_optimization_service.dart
// services/homepage_optimization_service.dart
// services/homepage_optimization_service.dart
// services/homepage_optimization_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_optimization_service.dart';
import '../pages/product_model.dart';
import '../models/health_tip.dart';
import 'health_tips_service.dart';
import 'banner_cache_service.dart';

class HomepageOptimizationService {
  static final HomepageOptimizationService _instance =
      HomepageOptimizationService._internal();
  factory HomepageOptimizationService() => _instance;
  HomepageOptimizationService._internal();

  // Core services
  final AppOptimizationService _optimizationService = AppOptimizationService();
  final BannerCacheService _bannerService = BannerCacheService();

  // Cache storage keys
  static const String _productsCacheKey = 'homepage_products_cache';
  static const String _productsCacheTimeKey = 'homepage_products_cache_time';
  static const String _popularProductsCacheKey =
      'homepage_popular_products_cache';
  static const String _popularProductsCacheTimeKey =
      'homepage_popular_products_cache_time';
  static const String _categorizedProductsCacheKey =
      'homepage_categorized_products_cache';
  static const String _categorizedProductsCacheTimeKey =
      'homepage_categorized_products_cache_time';

  // Cache configuration
  static const Duration _productsCacheDuration = Duration(minutes: 15);
  // Popular products cache for 24 hours to ensure consistent user experience
  // and prevent product cards from changing on every app reload
  static const Duration _popularProductsCacheDuration = Duration(hours: 24);
  static const Duration _categorizedProductsCacheDuration =
      Duration(minutes: 20);

  // In-memory cache
  List<Product> _cachedProducts = [];
  List<Product> _cachedPopularProducts = [];
  Map<String, List<Product>> _cachedCategorizedProducts = {};

  DateTime? _productsCacheTime;
  DateTime? _popularProductsCacheTime;
  DateTime? _categorizedProductsCacheTime;

  // Loading states
  bool _isLoadingProducts = false;
  bool _isLoadingPopularProducts = false;
  bool _isLoadingCategorizedProducts = false;

  // Image preloading
  final Map<String, bool> _preloadedImages = {};

  // Initialize service
  Future<void> initialize() async {
    await _loadFromStorage();
    _optimizationService.startTimer('HomepageService_Initialize');
  }

  // ==================== PRODUCTS OPTIMIZATION ====================

  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('HomepageService_GetProducts');

    if (_isProductsCacheValid && _cachedProducts.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetProducts');
      return _cachedProducts;
    }

    if (_isLoadingProducts) {
      while (_isLoadingProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('HomepageService_GetProducts');
      return _cachedProducts;
    }

    if (_cachedProducts.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetProducts');
      _fetchProducts();
      return _cachedProducts;
    }

    return await _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    _isLoadingProducts = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        final products = dataList.map<Product>((item) {
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
            quantity: productData['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        _cacheProducts(products);
        _optimizationService.endTimer('HomepageService_GetProducts');
        return products;
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      _optimizationService.endTimer('HomepageService_GetProducts');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // ==================== POPULAR PRODUCTS OPTIMIZATION ====================

  Future<List<Product>> getPopularProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('HomepageService_GetPopularProducts');

    if (_isPopularProductsCacheValid &&
        _cachedPopularProducts.isNotEmpty &&
        !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetPopularProducts');
      return _cachedPopularProducts;
    }

    if (_isLoadingPopularProducts) {
      while (_isLoadingPopularProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('HomepageService_GetPopularProducts');
      return _cachedPopularProducts;
    }

    return await _fetchPopularProducts();
  }

  Future<List<Product>> _fetchPopularProducts() async {
    _isLoadingPopularProducts = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/popular-products'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        final products = dataList.map<Product>((item) {
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
            quantity: productData['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        _cachePopularProducts(products);
        _optimizationService.endTimer('HomepageService_GetPopularProducts');
        return products;
      } else {
        throw Exception('Failed to load popular products');
      }
    } catch (e) {
      _optimizationService.endTimer('HomepageService_GetPopularProducts');
      rethrow;
    } finally {
      _isLoadingPopularProducts = false;
    }
  }

  // ==================== CATEGORIZED PRODUCTS OPTIMIZATION ====================

  Future<Map<String, List<Product>>> getCategorizedProducts(
      {bool forceRefresh = false}) async {
    _optimizationService.startTimer('HomepageService_GetCategorizedProducts');

    if (_isCategorizedProductsCacheValid &&
        _cachedCategorizedProducts.isNotEmpty &&
        !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetCategorizedProducts');
      return _cachedCategorizedProducts;
    }

    if (_isLoadingCategorizedProducts) {
      while (_isLoadingCategorizedProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('HomepageService_GetCategorizedProducts');
      return _cachedCategorizedProducts;
    }

    return await _fetchCategorizedProducts();
  }

  Future<Map<String, List<Product>>> _fetchCategorizedProducts() async {
    _isLoadingCategorizedProducts = true;

    try {
      final products = await getProducts();

      final categorizedProducts = <String, List<Product>>{
        'otcpom': [],
        'drug': [],
        'wellness': [],
        'selfcare': [],
        'accessories': [],
      };

      for (final product in products) {
        if (product.otcpom == true) categorizedProducts['otcpom']!.add(product);
        if (product.drug == true) categorizedProducts['drug']!.add(product);
        if (product.wellness == true) {
          categorizedProducts['wellness']!.add(product);
        }
        if (product.selfcare == true) {
          categorizedProducts['selfcare']!.add(product);
        }
        if (product.accessories == true) {
          categorizedProducts['accessories']!.add(product);
        }
      }

      _cacheCategorizedProducts(categorizedProducts);
      _optimizationService.endTimer('HomepageService_GetCategorizedProducts');
      return categorizedProducts;
    } catch (e) {
      _optimizationService.endTimer('HomepageService_GetCategorizedProducts');
      rethrow;
    } finally {
      _isLoadingCategorizedProducts = false;
    }
  }

  // ==================== BANNERS OPTIMIZATION ====================

  Future<List<dynamic>> getBanners({bool forceRefresh = false}) async {
    return await _bannerService.getBanners(forceRefresh: forceRefresh);
  }

  // ==================== HEALTH TIPS OPTIMIZATION ====================

  Future<List<HealthTip>> getHealthTips({bool forceRefresh = false}) async {
    return await HealthTipsService.fetchHealthTips();
  }

  // ==================== CACHE VALIDATION ====================

  bool get _isProductsCacheValid {
    if (_productsCacheTime == null) return false;
    return DateTime.now().difference(_productsCacheTime!) <
        _productsCacheDuration;
  }

  bool get _isPopularProductsCacheValid {
    if (_popularProductsCacheTime == null) return false;
    return DateTime.now().difference(_popularProductsCacheTime!) <
        _popularProductsCacheDuration;
  }

  bool get _isCategorizedProductsCacheValid {
    if (_categorizedProductsCacheTime == null) return false;
    return DateTime.now().difference(_categorizedProductsCacheTime!) <
        _categorizedProductsCacheDuration;
  }

  // ==================== CACHE OPERATIONS ====================

  void _cacheProducts(List<Product> products) {
    _cachedProducts = products;
    _productsCacheTime = DateTime.now();
    _saveProductsToStorage();
    // Optionally preload images if context is available (must be called from widget)
  }

  void _cachePopularProducts(List<Product> products) {
    _cachedPopularProducts = products;
    _popularProductsCacheTime = DateTime.now();
    _savePopularProductsToStorage();
    // Optionally preload images if context is available (must be called from widget)
  }

  void _cacheCategorizedProducts(Map<String, List<Product>> products) {
    _cachedCategorizedProducts = products;
    _categorizedProductsCacheTime = DateTime.now();
    _saveCategorizedProductsToStorage();
    // Optionally preload images if context is available (must be called from widget)
  }

  // ==================== STORAGE OPERATIONS ====================

  void _saveProductsToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      final productsJson = _cachedProducts.map((p) => p.toJson()).toList();
      prefs.setString(_productsCacheKey, json.encode(productsJson));
      prefs.setString(
          _productsCacheTimeKey, _productsCacheTime!.toIso8601String());
    });
  }

  void _savePopularProductsToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      final productsJson =
          _cachedPopularProducts.map((p) => p.toJson()).toList();
      prefs.setString(_popularProductsCacheKey, json.encode(productsJson));
      prefs.setString(_popularProductsCacheTimeKey,
          _popularProductsCacheTime!.toIso8601String());
    });
  }

  void _saveCategorizedProductsToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      final categorizedJson = _cachedCategorizedProducts.map(
        (key, value) => MapEntry(key, value.map((p) => p.toJson()).toList()),
      );
      prefs.setString(
          _categorizedProductsCacheKey, json.encode(categorizedJson));
      prefs.setString(_categorizedProductsCacheTimeKey,
          _categorizedProductsCacheTime!.toIso8601String());
    });
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load products cache
      final productsJson = prefs.getString(_productsCacheKey);
      final productsTimeString = prefs.getString(_productsCacheTimeKey);
      if (productsJson != null && productsTimeString != null) {
        final productsList = json.decode(productsJson) as List;
        _cachedProducts =
            productsList.map((json) => Product.fromJson(json)).toList();
        _productsCacheTime = DateTime.parse(productsTimeString);
      }

      // Load popular products cache
      final popularJson = prefs.getString(_popularProductsCacheKey);
      final popularTimeString = prefs.getString(_popularProductsCacheTimeKey);
      if (popularJson != null && popularTimeString != null) {
        final popularList = json.decode(popularJson) as List;
        _cachedPopularProducts =
            popularList.map((json) => Product.fromJson(json)).toList();
        _popularProductsCacheTime = DateTime.parse(popularTimeString);
      }

      // Load categorized products cache
      final categorizedJson = prefs.getString(_categorizedProductsCacheKey);
      final categorizedTimeString =
          prefs.getString(_categorizedProductsCacheTimeKey);
      if (categorizedJson != null && categorizedTimeString != null) {
        final categorizedMap =
            json.decode(categorizedJson) as Map<String, dynamic>;
        _cachedCategorizedProducts = categorizedMap.map(
          (key, value) => MapEntry(key,
              (value as List).map((json) => Product.fromJson(json)).toList()),
        );
        _categorizedProductsCacheTime = DateTime.parse(categorizedTimeString);
      }
    } catch (e) {
      debugPrint('Failed to load homepage cache: $e');
      _cachedProducts = [];
      _cachedPopularProducts = [];
      _cachedCategorizedProducts = {};
      _productsCacheTime = null;
      _popularProductsCacheTime = null;
      _categorizedProductsCacheTime = null;
    }
  }

  // ==================== IMAGE PRELOADING ====================

  Future<void> preloadProductImages(
      BuildContext context, List<Product> products) async {
    final imageUrls = products
        .take(20) // Preload first 20 product images
        .map((product) => product.thumbnail)
        .where((url) => url.isNotEmpty)
        .toList();

    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    }
  }

  /// Helper to get a valid absolute product image URL
  String getProductImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    // Otherwise, treat as filename
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  /// Print product cache performance summary (like banners)
  void printProductCachePerformanceSummary() {
    final stats = getCacheStats();
    debugPrint('=== Product Cache Performance Summary ===');
    debugPrint('Products Cache Valid: ${stats['products_cache_valid']}');
    debugPrint(
        'Popular Products Cache Valid: ${stats['popular_products_cache_valid']}');
    debugPrint(
        'Categorized Products Cache Valid: ${stats['categorized_products_cache_valid']}');
    debugPrint('Products Count: ${stats['products_count']}');
    debugPrint('Popular Products Count: ${stats['popular_products_count']}');
    debugPrint(
        'Categorized Products Count: ${stats['categorized_products_count']}');
    debugPrint('Preloaded Images Count: ${stats['preloaded_images_count']}');
    debugPrint(
        'Products Cache Duration: ${stats['products_cache_duration_minutes']} min');
    debugPrint(
        'Popular Products Cache Duration: ${stats['popular_products_cache_duration_minutes']} min');
    debugPrint(
        'Categorized Products Cache Duration: ${stats['categorized_products_cache_duration_minutes']} min');
    debugPrint('========================================');
  }

  /// Preload all product images in cache (not just 20)
  Future<void> preloadAllProductImages(BuildContext context) async {
    final allProducts = <Product>[];
    allProducts.addAll(_cachedProducts);
    allProducts.addAll(_cachedPopularProducts);
    _cachedCategorizedProducts.values.forEach(allProducts.addAll);
    final imageUrls = allProducts
        .map((product) => getProductImageUrl(product.thumbnail))
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    }
    debugPrint('Preloaded ${imageUrls.length} product images');
  }

  // ==================== SEARCH OPTIMIZATION ====================

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final products = await getProducts();

    return products.where((product) {
      final name = product.name.toLowerCase();
      final description = product.description.toLowerCase();
      final category = product.category.toLowerCase();
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) ||
          description.contains(searchQuery) ||
          category.contains(searchQuery);
    }).toList();
  }

  // ==================== UTILITY METHODS ====================

  Future<void> clearAllCaches() async {
    _cachedProducts.clear();
    _cachedPopularProducts.clear();
    _cachedCategorizedProducts.clear();
    _preloadedImages.clear();

    _productsCacheTime = null;
    _popularProductsCacheTime = null;
    _categorizedProductsCacheTime = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_productsCacheTimeKey);
      await prefs.remove(_popularProductsCacheKey);
      await prefs.remove(_popularProductsCacheTimeKey);
      await prefs.remove(_categorizedProductsCacheKey);
      await prefs.remove(_categorizedProductsCacheTimeKey);
    } catch (e) {
      debugPrint('Failed to clear homepage cache: $e');
    }
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'products_cache_valid': _isProductsCacheValid,
      'popular_products_cache_valid': _isPopularProductsCacheValid,
      'categorized_products_cache_valid': _isCategorizedProductsCacheValid,
      'products_count': _cachedProducts.length,
      'popular_products_count': _cachedPopularProducts.length,
      'categorized_products_count': _cachedCategorizedProducts.length,
      'preloaded_images_count': _preloadedImages.length,
      'products_cache_duration_minutes': _productsCacheDuration.inMinutes,
      'popular_products_cache_duration_minutes':
          _popularProductsCacheDuration.inMinutes,
      'categorized_products_cache_duration_minutes':
          _categorizedProductsCacheDuration.inMinutes,
    };
  }

  Future<void> refreshAllData() async {
    await getProducts(forceRefresh: true);
    await getPopularProducts(forceRefresh: true);
    await getCategorizedProducts(forceRefresh: true);
    await getBanners(forceRefresh: true);
    await getHealthTips(forceRefresh: true);
  }

  // ==================== LOADING STATE GETTERS ====================

  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingPopularProducts => _isLoadingPopularProducts;
  bool get isLoadingCategorizedProducts => _isLoadingCategorizedProducts;
  bool get hasCachedProducts => _cachedProducts.isNotEmpty;
  bool get hasCachedPopularProducts => _cachedPopularProducts.isNotEmpty;
  bool get hasCachedCategorizedProducts =>
      _cachedCategorizedProducts.isNotEmpty;

  // Cache getters
  List<Product> get cachedProducts => List.unmodifiable(_cachedProducts);
  List<Product> get cachedPopularProducts =>
      List.unmodifiable(_cachedPopularProducts);
  Map<String, List<Product>> get cachedCategorizedProducts =>
      Map.unmodifiable(_cachedCategorizedProducts);
}
