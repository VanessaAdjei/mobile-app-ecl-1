// services/item_detail_optimization_service.dart
// services/item_detail_optimization_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_model.dart';
import 'item_detail_service_interface.dart';
import 'performance_service.dart';
import 'product_detail_service.dart';

class ItemDetailOptimizationService implements ItemDetailServiceInterface {
  static final ItemDetailOptimizationService _instance =
      ItemDetailOptimizationService._internal();
  factory ItemDetailOptimizationService() => _instance;
  ItemDetailOptimizationService._internal();

  // Cache configuration
  static const String _productCacheKey = 'item_detail_product_cache';
  static const String _relatedProductsCacheKey = 'item_detail_related_cache';
  static const String _productImagesCacheKey = 'item_detail_images_cache';
  static const Duration _productCacheDuration = Duration(minutes: 30);
  static const Duration _relatedProductsCacheDuration = Duration(minutes: 15);
  static const Duration _imagesCacheDuration = Duration(hours: 2);

  // Performance tracking
  final PerformanceService _performanceService = PerformanceService();
  final ProductDetailService _detailService = ProductDetailService();
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _isLoading = {};

  // Cache storage
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // In-memory cache for frequently accessed data
  final Map<String, Product> _productMemoryCache = {};
  final Map<String, List<Product>> _relatedProductsMemoryCache = {};
  final Map<String, List<String>> _productImagesMemoryCache = {};

  // Initialize the service
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _performanceService.startTimer('item_detail_service_init');

    try {
      _prefs = await SharedPreferences.getInstance();
      await _cleanupExpiredCache();
      _isInitialized = true;

      _performanceService.stopTimer('item_detail_service_init');
      developer.log('Item detail optimization service initialized',
          name: 'ItemDetailService');
    } catch (e) {
      _performanceService.stopTimer('item_detail_service_init');
      developer.log('Failed to initialize item detail service: $e',
          name: 'ItemDetailService');
    }
  }

  // Get product details with comprehensive caching
  @override
  Future<Product> getProductDetails(String urlName,
      {bool forceRefresh = false}) async {
    await _ensureInitialized();

    // Check memory cache first
    if (!forceRefresh && _productMemoryCache.containsKey(urlName)) {
      _performanceService.trackUserInteraction('product_memory_cache_hit');
      return _productMemoryCache[urlName]!;
    }

    // Check persistent cache
    final cached = await _getCachedProduct(urlName);
    if (!forceRefresh && cached != null) {
      _productMemoryCache[urlName] = cached;
      _performanceService.trackUserInteraction('product_persistent_cache_hit');
      return cached;
    }

    // Prevent duplicate requests
    if (_isLoading['product_$urlName'] == true) {
      while (_isLoading['product_$urlName'] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _productMemoryCache[urlName] ?? cached!;
    }

    _isLoading['product_$urlName'] = true;
    _performanceService.startTimer('product_details_fetch');

    try {
      final product = await _fetchProductDetails(urlName);

      // Cache in memory and persistent storage
      _productMemoryCache[urlName] = product;
      await _cacheProduct(urlName, product);

      _performanceService.stopTimer('product_details_fetch');
      return product;
    } catch (e) {
      _performanceService.stopTimer('product_details_fetch');
      developer.log('Failed to fetch product details: $e',
          name: 'ItemDetailService');
      rethrow;
    } finally {
      _isLoading['product_$urlName'] = false;
    }
  }

  // Get related products with optimization
  @override
  Future<List<Product>> getRelatedProducts(String urlName,
      {bool forceRefresh = false}) async {
    await _ensureInitialized();

    // Check memory cache first
    if (!forceRefresh && _relatedProductsMemoryCache.containsKey(urlName)) {
      _performanceService
          .trackUserInteraction('related_products_memory_cache_hit');
      return _relatedProductsMemoryCache[urlName]!;
    }

    // Check persistent cache
    final cached = await _getCachedRelatedProducts(urlName);
    if (!forceRefresh && cached != null) {
      _relatedProductsMemoryCache[urlName] = cached;
      _performanceService
          .trackUserInteraction('related_products_persistent_cache_hit');
      return cached;
    }

    // Prevent duplicate requests
    if (_isLoading['related_$urlName'] == true) {
      while (_isLoading['related_$urlName'] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _relatedProductsMemoryCache[urlName] ?? cached ?? [];
    }

    _isLoading['related_$urlName'] = true;
    _performanceService.startTimer('related_products_fetch');

    try {
      final products = await _fetchRelatedProducts(urlName);

      // Cache in memory and persistent storage
      _relatedProductsMemoryCache[urlName] = products;
      await _cacheRelatedProducts(urlName, products);

      _performanceService.stopTimer('related_products_fetch');
      return products;
    } catch (e) {
      _performanceService.stopTimer('related_products_fetch');
      developer.log('Failed to fetch related products: $e',
          name: 'ItemDetailService');
      return [];
    } finally {
      _isLoading['related_$urlName'] = false;
    }
  }

  // Get product images with optimization
  @override
  Future<List<String>> getProductImages(String urlName,
      {bool forceRefresh = false}) async {
    await _ensureInitialized();

    // Check memory cache first
    if (!forceRefresh && _productImagesMemoryCache.containsKey(urlName)) {
      return _productImagesMemoryCache[urlName]!;
    }

    // Check persistent cache
    final cached = await _getCachedProductImages(urlName);
    if (!forceRefresh && cached != null) {
      _productImagesMemoryCache[urlName] = cached;
      return cached;
    }

    // Extract images from product details
    try {
      final product =
          await getProductDetails(urlName, forceRefresh: forceRefresh);
      final images = <String>[];

      if (product.thumbnail.isNotEmpty) {
        images.add(product.thumbnail);
      }

      // Add more images if available in the future
      // For now, we'll use the thumbnail as the main image

      _productImagesMemoryCache[urlName] = images;
      await _cacheProductImages(urlName, images);

      return images;
    } catch (e) {
      developer.log('Failed to get product images: $e',
          name: 'ItemDetailService');
      return [];
    }
  }

  // Preload product images for better UX
  Future<void> preloadProductImages(
      BuildContext context, String urlName) async {
    try {
      final images = await getProductImages(urlName);
      for (final imageUrl in images.take(5)) {
        // Limit to 5 images
        if (imageUrl.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(imageUrl),
            context,
            onError: (exception, stackTrace) {
              developer.log(
                'Skipping preload product image (may be missing): $imageUrl',
                name: 'ItemDetailService',
              );
            },
          );
        }
      }
    } catch (e) {
      developer.log('Failed to preload images: $e', name: 'ItemDetailService');
    }
  }

  // Fetch product details from API
  Future<Product> _fetchProductDetails(String urlName) =>
      _detailService.fetchProductDetails(urlName);

  // Fetch related products from API
  Future<List<Product>> _fetchRelatedProducts(String urlName) =>
      _detailService.fetchRelatedProducts(urlName);

  // Cache product details
  Future<void> _cacheProduct(String urlName, Product product) async {
    try {
      final cacheKey = '${_productCacheKey}_$urlName';
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'product': product.toJson(),
      };
      await _prefs.setString(cacheKey, json.encode(dataToCache));
    } catch (e) {
      developer.log('Failed to cache product: $e', name: 'ItemDetailService');
    }
  }

  // Get cached product details
  Future<Product?> _getCachedProduct(String urlName) async {
    try {
      final cacheKey = '${_productCacheKey}_$urlName';
      final cached = _prefs.getString(cacheKey);

      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _productCacheDuration) {
          return Product.fromJson(data['product']);
        }
      }
    } catch (e) {
      developer.log('Failed to get cached product: $e',
          name: 'ItemDetailService');
    }
    return null;
  }

  // Cache related products
  Future<void> _cacheRelatedProducts(
      String urlName, List<Product> products) async {
    try {
      final cacheKey = '${_relatedProductsCacheKey}_$urlName';
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'products': products.map((p) => p.toJson()).toList(),
      };
      await _prefs.setString(cacheKey, json.encode(dataToCache));
    } catch (e) {
      developer.log('Failed to cache related products: $e',
          name: 'ItemDetailService');
    }
  }

  // Get cached related products
  Future<List<Product>?> _getCachedRelatedProducts(String urlName) async {
    try {
      final cacheKey = '${_relatedProductsCacheKey}_$urlName';
      final cached = _prefs.getString(cacheKey);

      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) <
            _relatedProductsCacheDuration) {
          return (data['products'] as List)
              .map((p) => Product.fromJson(p))
              .toList();
        }
      }
    } catch (e) {
      developer.log('Failed to get cached related products: $e',
          name: 'ItemDetailService');
    }
    return null;
  }

  // Cache product images
  Future<void> _cacheProductImages(String urlName, List<String> images) async {
    try {
      final cacheKey = '${_productImagesCacheKey}_$urlName';
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'images': images,
      };
      await _prefs.setString(cacheKey, json.encode(dataToCache));
    } catch (e) {
      developer.log('Failed to cache product images: $e',
          name: 'ItemDetailService');
    }
  }

  // Get cached product images
  Future<List<String>?> _getCachedProductImages(String urlName) async {
    try {
      final cacheKey = '${_productImagesCacheKey}_$urlName';
      final cached = _prefs.getString(cacheKey);

      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _imagesCacheDuration) {
          return List<String>.from(data['images']);
        }
      }
    } catch (e) {
      developer.log('Failed to get cached product images: $e',
          name: 'ItemDetailService');
    }
    return null;
  }

  // Debounced function calls
  void debounce(String key, VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, callback);
  }

  // Cleanup expired cache
  Future<void> _cleanupExpiredCache() async {
    try {
      final keys = _prefs.getKeys();
      final now = DateTime.now();

      for (final key in keys) {
        if (key.startsWith(_productCacheKey) ||
            key.startsWith(_relatedProductsCacheKey) ||
            key.startsWith(_productImagesCacheKey)) {
          final cached = _prefs.getString(key);
          if (cached != null) {
            try {
              final data = json.decode(cached);
              final timestamp = DateTime.parse(data['timestamp']);

              Duration cacheDuration;
              if (key.startsWith(_productCacheKey)) {
                cacheDuration = _productCacheDuration;
              } else if (key.startsWith(_relatedProductsCacheKey)) {
                cacheDuration = _relatedProductsCacheDuration;
              } else {
                cacheDuration = _imagesCacheDuration;
              }

              if (now.difference(timestamp) > cacheDuration) {
                await _prefs.remove(key);
              }
            } catch (e) {
              // Remove invalid cache entries
              await _prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      developer.log('Cache cleanup failed: $e', name: 'ItemDetailService');
    }
  }

  // Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    await _ensureInitialized();

    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_productCacheKey) ||
            key.startsWith(_relatedProductsCacheKey) ||
            key.startsWith(_productImagesCacheKey)) {
          await _prefs.remove(key);
        }
      }

      _productMemoryCache.clear();
      _relatedProductsMemoryCache.clear();
      _productImagesMemoryCache.clear();

      developer.log('Item detail cache cleared', name: 'ItemDetailService');
    } catch (e) {
      developer.log('Failed to clear cache: $e', name: 'ItemDetailService');
    }
  }

  // Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'isEnabled': _performanceService.isEnabled,
      'events': _performanceService.events.length,
      'metrics': _performanceService.metrics.length,
      'memory_cache_size': _productMemoryCache.length,
      'related_products_cache_size': _relatedProductsMemoryCache.length,
      'images_cache_size': _productImagesMemoryCache.length,
    };
  }

  // Dispose resources
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _isLoading.clear();
  }
}
