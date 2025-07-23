// services/optimized_homepage_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../pages/product_model.dart';
import 'advanced_performance_service.dart';

class OptimizedHomepageService {
  static final OptimizedHomepageService _instance =
      OptimizedHomepageService._internal();
  factory OptimizedHomepageService() => _instance;
  OptimizedHomepageService._internal();

  // Performance service
  final AdvancedPerformanceService _performanceService =
      AdvancedPerformanceService();

  // Cache keys
  static const String _productsCacheKey = 'homepage_products';
  static const String _popularProductsCacheKey = 'homepage_popular_products';
  static const String _categorizedProductsCacheKey =
      'homepage_categorized_products';
  static const String _bannersCacheKey = 'homepage_banners';

  // Cache durations
  static const Duration _productsCacheDuration = Duration(minutes: 30);
  static const Duration _popularProductsCacheDuration = Duration(minutes: 15);
  static const Duration _categorizedProductsCacheDuration =
      Duration(minutes: 20);
  static const Duration _bannersCacheDuration = Duration(minutes: 30);

  // API endpoints
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const String _productsEndpoint = '/get-all-products';
  static const String _bannersEndpoint = '/banner';

  // Loading states
  bool _isLoadingProducts = false;
  bool _isLoadingPopularProducts = false;
  bool _isLoadingBanners = false;

  // Initialize the service
  Future<void> initialize() async {
    await _performanceService.initialize();
    developer.log('Optimized Homepage Service initialized',
        name: 'HomepageService');
  }

  // ==================== PRODUCTS OPTIMIZATION ====================

  /// Get all products with intelligent caching
  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    _performanceService.startTimer('homepage_get_products');

    try {
      final products = await _performanceService.getCachedData<List<Product>>(
        _productsCacheKey,
        () => _fetchProductsFromAPI(),
        cacheDuration: _productsCacheDuration,
        forceRefresh: forceRefresh,
      );

      _performanceService.stopTimer('homepage_get_products');
      return products ?? [];
    } catch (e) {
      _performanceService.stopTimer('homepage_get_products');
      developer.log('Failed to get products: $e', name: 'HomepageService');
      return [];
    }
  }

  /// Get popular products with optimization
  Future<List<Product>> getPopularProducts({bool forceRefresh = false}) async {
    _performanceService.startTimer('homepage_get_popular_products');

    try {
      final products = await _performanceService.getCachedData<List<Product>>(
        _popularProductsCacheKey,
        () => _fetchPopularProductsFromAPI(),
        cacheDuration: _popularProductsCacheDuration,
        forceRefresh: forceRefresh,
      );

      _performanceService.stopTimer('homepage_get_popular_products');
      return products ?? [];
    } catch (e) {
      _performanceService.stopTimer('homepage_get_popular_products');
      developer.log('Failed to get popular products: $e',
          name: 'HomepageService');
      return [];
    }
  }

  /// Get categorized products with optimization
  Future<Map<String, List<Product>>> getCategorizedProducts(
      {bool forceRefresh = false}) async {
    _performanceService.startTimer('homepage_get_categorized_products');

    try {
      final categorizedProducts =
          await _performanceService.getCachedData<Map<String, List<Product>>>(
        _categorizedProductsCacheKey,
        () => _fetchCategorizedProductsFromAPI(),
        cacheDuration: _categorizedProductsCacheDuration,
        forceRefresh: forceRefresh,
      );

      _performanceService.stopTimer('homepage_get_categorized_products');
      return categorizedProducts ?? {};
    } catch (e) {
      _performanceService.stopTimer('homepage_get_categorized_products');
      developer.log('Failed to get categorized products: $e',
          name: 'HomepageService');
      return {};
    }
  }

  /// Get banners with optimization
  Future<List<Map<String, dynamic>>> getBanners(
      {bool forceRefresh = false}) async {
    _performanceService.startTimer('homepage_get_banners');

    try {
      final banners =
          await _performanceService.getCachedData<List<Map<String, dynamic>>>(
        _bannersCacheKey,
        () => _fetchBannersFromAPI(),
        cacheDuration: _bannersCacheDuration,
        forceRefresh: forceRefresh,
      );

      _performanceService.stopTimer('homepage_get_banners');
      return banners ?? [];
    } catch (e) {
      _performanceService.stopTimer('homepage_get_banners');
      developer.log('Failed to get banners: $e', name: 'HomepageService');
      return [];
    }
  }

  // ==================== API FETCHING ====================

  /// Fetch products from API with batching
  Future<List<Product>> _fetchProductsFromAPI() async {
    if (_isLoadingProducts) {
      // Wait for existing request to complete
      while (_isLoadingProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return [];
    }

    _isLoadingProducts = true;

    try {
      final response = await _performanceService.batchRequest(
        _productsEndpoint,
        () => http.get(
          Uri.parse('$_baseUrl$_productsEndpoint'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'] ?? [];

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

        return products;
      } else {
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching products: $e', name: 'HomepageService');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  /// Fetch popular products from API
  Future<List<Product>> _fetchPopularProductsFromAPI() async {
    if (_isLoadingPopularProducts) {
      while (_isLoadingPopularProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return [];
    }

    _isLoadingPopularProducts = true;

    try {
      // For now, we'll get popular products from the main products list
      // In a real implementation, you'd have a separate API endpoint
      final allProducts = await _fetchProductsFromAPI();

      // Filter popular products (you can customize this logic)
      final popularProducts = allProducts
          .where((product) =>
              product.category.toLowerCase().contains('popular') ||
              product.wellness?.toLowerCase().contains('popular') == true ||
              product.selfcare?.toLowerCase().contains('popular') == true)
          .take(20)
          .toList();

      // If no popular products found, return first 20 products
      if (popularProducts.isEmpty) {
        return allProducts.take(20).toList();
      }

      return popularProducts;
    } catch (e) {
      developer.log('Error fetching popular products: $e',
          name: 'HomepageService');
      rethrow;
    } finally {
      _isLoadingPopularProducts = false;
    }
  }

  /// Fetch categorized products from API
  Future<Map<String, List<Product>>> _fetchCategorizedProductsFromAPI() async {
    try {
      final allProducts = await _fetchProductsFromAPI();
      final categorizedProducts = <String, List<Product>>{};

      // Categorize products
      for (final product in allProducts) {
        final categories = <String>[];

        if (product.wellness?.toLowerCase() == 'wellness') {
          categories.add('wellness');
        }
        if (product.selfcare?.toLowerCase() == 'selfcare') {
          categories.add('selfcare');
        }
        if (product.accessories?.toLowerCase() == 'accessories') {
          categories.add('accessories');
        }
        if (product.drug?.toLowerCase() == 'drug') {
          categories.add('drugs');
        }
        if (product.otcpom?.toLowerCase() == 'otc') {
          categories.add('otc');
        }

        // Add to categorized products
        for (final category in categories) {
          if (!categorizedProducts.containsKey(category)) {
            categorizedProducts[category] = [];
          }
          categorizedProducts[category]!.add(product);
        }
      }

      return categorizedProducts;
    } catch (e) {
      developer.log('Error fetching categorized products: $e',
          name: 'HomepageService');
      rethrow;
    }
  }

  /// Fetch banners from API
  Future<List<Map<String, dynamic>>> _fetchBannersFromAPI() async {
    if (_isLoadingBanners) {
      while (_isLoadingBanners) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return [];
    }

    _isLoadingBanners = true;

    try {
      final response = await _performanceService.batchRequest(
        _bannersEndpoint,
        () => http.get(
          Uri.parse('$_baseUrl$_bannersEndpoint'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> bannersData = responseData['data'] ?? [];

        return bannersData.map<Map<String, dynamic>>((banner) {
          return {
            'id': banner['id'],
            'img': banner['img'],
            'urlName': banner['inventory']?['url_name'],
          };
        }).toList();
      } else {
        throw Exception('Failed to fetch banners: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching banners: $e', name: 'HomepageService');
      rethrow;
    } finally {
      _isLoadingBanners = false;
    }
  }

  // ==================== IMAGE OPTIMIZATION ====================

  /// Preload product images for better UX
  Future<void> preloadProductImages(
      BuildContext context, List<Product> products) async {
    final imageUrls = products
        .take(30) // Preload first 30 product images
        .map((product) => _getProductImageUrl(product.thumbnail))
        .where((url) => url.isNotEmpty)
        .toList();

    await _performanceService.preloadImages(imageUrls, context);
  }

  /// Preload banner images
  Future<void> preloadBannerImages(
      BuildContext context, List<Map<String, dynamic>> banners) async {
    final imageUrls = banners
        .map((banner) => _getBannerImageUrl(banner['img']))
        .where((url) => url.isNotEmpty)
        .toList();

    await _performanceService.preloadImages(imageUrls, context);
  }

  /// Get optimized image widget for products
  Widget getOptimizedProductImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return _performanceService.getOptimizedImage(
      imageUrl: _getProductImageUrl(imageUrl),
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  /// Get optimized image widget for banners
  Widget getOptimizedBannerImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return _performanceService.getOptimizedImage(
      imageUrl: _getBannerImageUrl(imageUrl),
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  // ==================== UTILITY METHODS ====================

  /// Get product image URL with optimization
  String _getProductImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    if (imagePath.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$imagePath';
    }

    if (imagePath.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$imagePath';
    }

    // Default product image path
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$imagePath';
  }

  /// Get banner image URL with optimization
  String _getBannerImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return 'https://eclcommerce.ernestchemists.com.gh/storage/banners/${Uri.encodeComponent(imagePath)}';
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return _performanceService.getPerformanceStats();
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _performanceService.clearAllCaches();
    developer.log('Homepage service caches cleared', name: 'HomepageService');
  }

  /// Refresh all data
  Future<Map<String, dynamic>> refreshAllData() async {
    _performanceService.startTimer('homepage_refresh_all');

    try {
      final futures = <Future>[
        getProducts(forceRefresh: true),
        getPopularProducts(forceRefresh: true),
        getCategorizedProducts(forceRefresh: true),
        getBanners(forceRefresh: true),
      ];

      final results = await Future.wait(futures);

      _performanceService.stopTimer('homepage_refresh_all');

      return {
        'products': results[0] as List<Product>,
        'popularProducts': results[1] as List<Product>,
        'categorizedProducts': results[2] as Map<String, List<Product>>,
        'banners': results[3] as List<Map<String, dynamic>>,
      };
    } catch (e) {
      _performanceService.stopTimer('homepage_refresh_all');
      developer.log('Error refreshing all data: $e', name: 'HomepageService');
      rethrow;
    }
  }

  /// Dispose the service
  void dispose() {
    _performanceService.dispose();
  }
}
