// services/background_prefetch_service.dart
// services/background_prefetch_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Background data prefetching service for improved performance
class BackgroundPrefetchService {
  static final BackgroundPrefetchService _instance =
      BackgroundPrefetchService._internal();
  factory BackgroundPrefetchService() => _instance;
  BackgroundPrefetchService._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, bool> _prefetchingTasks = {};

  static const Duration _cacheExpiry = Duration(hours: 1);
  static const Duration _prefetchDelay = Duration(seconds: 2);

  /// Initialize the prefetch service
  Future<void> initialize() async {
    debugPrint('🔄 Initializing BackgroundPrefetchService...');
    await _loadCacheFromStorage();
    _startPeriodicCleanup();
  }

  /// Prefetch categories data
  Future<void> prefetchCategories() async {
    if (_prefetchingTasks['categories'] == true) return;

    _prefetchingTasks['categories'] = true;
    debugPrint('🔄 Prefetching categories...');

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/categories'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData('categories', data);
        debugPrint('✅ Categories prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch categories: $e');
    } finally {
      _prefetchingTasks['categories'] = false;
    }
  }

  /// Prefetch popular products
  Future<void> prefetchPopularProducts() async {
    if (_prefetchingTasks['popular_products'] == true) return;

    _prefetchingTasks['popular_products'] = true;
    debugPrint('🔄 Prefetching popular products...');

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/popular-products'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData('popular_products', data);
        debugPrint('✅ Popular products prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch popular products: $e');
    } finally {
      _prefetchingTasks['popular_products'] = false;
    }
  }

  /// Prefetch category products
  Future<void> prefetchCategoryProducts(int categoryId) async {
    final key = 'category_products_$categoryId';
    if (_prefetchingTasks[key] == true) return;

    _prefetchingTasks[key] = true;
    debugPrint('🔄 Prefetching products for category $categoryId...');

    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/product-categories/$categoryId'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData(key, data);
        debugPrint('✅ Category $categoryId products prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch category $categoryId products: $e');
    } finally {
      _prefetchingTasks[key] = false;
    }
  }

  /// Prefetch product details
  Future<void> prefetchProductDetails(int productId) async {
    final key = 'product_details_$productId';
    if (_prefetchingTasks[key] == true) return;

    _prefetchingTasks[key] = true;
    debugPrint('🔄 Prefetching product details for $productId...');

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/products/$productId'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData(key, data);
        debugPrint('✅ Product $productId details prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch product $productId details: $e');
    } finally {
      _prefetchingTasks[key] = false;
    }
  }

  /// Prefetch user profile data
  Future<void> prefetchUserProfile() async {
    if (_prefetchingTasks['user_profile'] == true) return;

    _prefetchingTasks['user_profile'] = true;
    debugPrint('🔄 Prefetching user profile...');

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData('user_profile', data);
        debugPrint('✅ User profile prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch user profile: $e');
    } finally {
      _prefetchingTasks['user_profile'] = false;
    }
  }

  /// Prefetch cart data
  Future<void> prefetchCart() async {
    if (_prefetchingTasks['cart'] == true) return;

    _prefetchingTasks['cart'] = true;
    debugPrint('🔄 Prefetching cart data...');

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/cart'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cacheData('cart', data);
        debugPrint('✅ Cart data prefetched successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to prefetch cart data: $e');
    } finally {
      _prefetchingTasks['cart'] = false;
    }
  }

  /// Get cached data
  dynamic getCachedData(String key) {
    if (_isCacheValid(key)) {
      debugPrint('📦 Returning cached data for: $key');
      return _cache[key];
    }
    debugPrint('❌ Cache expired or not found for: $key');
    return null;
  }

  /// Check if cache is valid
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final timestamp = _cacheTimestamps[key]!;
    final now = DateTime.now();
    return now.difference(timestamp) < _cacheExpiry;
  }

  /// Cache data with timestamp
  Future<void> _cacheData(String key, dynamic data) async {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    await _saveCacheToStorage();
  }

  /// Save cache to persistent storage
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': _cache,
        'timestamps': _cacheTimestamps.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      };
      await prefs.setString('prefetch_cache', json.encode(cacheData));
    } catch (e) {
      debugPrint('❌ Failed to save cache to storage: $e');
    }
  }

  /// Load cache from persistent storage
  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('prefetch_cache');

      if (cacheString != null) {
        final cacheData = json.decode(cacheString);
        _cache.addAll(Map<String, dynamic>.from(cacheData['data']));

        final timestamps = cacheData['timestamps'] as Map<String, dynamic>;
        _cacheTimestamps.addAll(
          timestamps.map((key, value) => MapEntry(
                key,
                DateTime.parse(value as String),
              )),
        );

        debugPrint('📦 Loaded ${_cache.length} cached items from storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load cache from storage: $e');
    }
  }

  /// Start periodic cache cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 30), (timer) {
      _cleanupExpiredCache();
    });
  }

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
      _saveCacheToStorage();
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _cache.clear();
    _cacheTimestamps.clear();
    await _saveCacheToStorage();
    debugPrint('🗑️ Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'total_items': _cache.length,
      'valid_items': _cache.keys.where((key) => _isCacheValid(key)).length,
      'expired_items':
          _cache.length - _cache.keys.where((key) => _isCacheValid(key)).length,
      'prefetching_tasks': _prefetchingTasks.length,
    };
  }

  /// Get headers for API requests
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Smart prefetch based on user behavior
  Future<void> smartPrefetch() async {
    debugPrint('🧠 Starting smart prefetch...');

    // Prefetch essential data first
    await Future.wait([
      prefetchCategories(),
      prefetchPopularProducts(),
    ]);

    // Wait a bit before prefetching more data
    await Future.delayed(_prefetchDelay);

    // Prefetch user-specific data
    await Future.wait([
      prefetchUserProfile(),
      prefetchCart(),
    ]);
  }

  /// Prefetch data for specific page
  Future<void> prefetchForPage(String pageName) async {
    switch (pageName.toLowerCase()) {
      case 'home':
        await Future.wait([
          prefetchCategories(),
          prefetchPopularProducts(),
        ]);
        break;
      case 'categories':
        await prefetchCategories();
        break;
      case 'profile':
        await prefetchUserProfile();
        break;
      case 'cart':
        await prefetchCart();
        break;
      default:
        debugPrint('⚠️ Unknown page for prefetch: $pageName');
    }
  }
}
