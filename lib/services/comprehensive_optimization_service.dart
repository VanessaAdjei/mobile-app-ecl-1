// services/comprehensive_optimization_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_optimization_service.dart';

class ComprehensiveOptimizationService {
  static final ComprehensiveOptimizationService _instance =
      ComprehensiveOptimizationService._internal();
  factory ComprehensiveOptimizationService() => _instance;
  ComprehensiveOptimizationService._internal();

  // Core services
  final AppOptimizationService _optimizationService = AppOptimizationService();

  // Cache storage keys
  static const String _homepageCacheKey = 'homepage_cache';
  static const String _homepageCacheTimeKey = 'homepage_cache_time';
  static const String _productsCacheKey = 'products_cache';
  static const String _productsCacheTimeKey = 'products_cache_time';
  static const String _userDataCacheKey = 'user_data_cache';
  static const String _userDataCacheTimeKey = 'user_data_cache_time';
  static const String _notificationsCacheKey = 'notifications_cache';
  static const String _notificationsCacheTimeKey = 'notifications_cache_time';
  static const String _cartCacheKey = 'cart_cache';
  static const String _cartCacheTimeKey = 'cart_cache_time';

  // Cache configuration
  static const Duration _homepageCacheDuration = Duration(minutes: 30);
  static const Duration _productsCacheDuration = Duration(minutes: 15);
  static const Duration _userDataCacheDuration = Duration(minutes: 60);
  static const Duration _notificationsCacheDuration = Duration(minutes: 5);
  static const Duration _cartCacheDuration = Duration(minutes: 10);

  // In-memory cache
  Map<String, dynamic> _homepageCache = {};
  List<dynamic> _productsCache = [];
  Map<String, dynamic> _userDataCache = {};
  List<dynamic> _notificationsCache = [];
  Map<String, dynamic> _cartCache = {};

  DateTime? _homepageCacheTime;
  DateTime? _productsCacheTime;
  DateTime? _userDataCacheTime;
  DateTime? _notificationsCacheTime;
  DateTime? _cartCacheTime;

  // Loading states
  bool _isLoadingHomepage = false;
  bool _isLoadingProducts = false;
  bool _isLoadingUserData = false;
  bool _isLoadingNotifications = false;
  bool _isLoadingCart = false;

  // Image preloading
  final Map<String, bool> _preloadedImages = {};

  // Initialize service
  Future<void> initialize() async {
    await _loadAllFromStorage();
    _optimizationService.startTimer('ComprehensiveService_Initialize');
  }

  // ==================== HOMEPAGE OPTIMIZATION ====================

  Future<Map<String, dynamic>> getHomepageData(
      {bool forceRefresh = false}) async {
    _optimizationService.startTimer('HomepageService_GetData');

    if (_isHomepageCacheValid && _homepageCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetData');
      return _homepageCache;
    }

    if (_isLoadingHomepage) {
      while (_isLoadingHomepage) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('HomepageService_GetData');
      return _homepageCache;
    }

    if (_homepageCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('HomepageService_GetData');
      _fetchHomepageData();
      return _homepageCache;
    }

    return await _fetchHomepageData();
  }

  Future<Map<String, dynamic>> _fetchHomepageData() async {
    _isLoadingHomepage = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/homepage'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cacheHomepageData(data);
          _optimizationService.endTimer('HomepageService_GetData');
          return data;
        }
      }
      throw Exception('Failed to load homepage data');
    } catch (e) {
      _optimizationService.endTimer('HomepageService_GetData');
      rethrow;
    } finally {
      _isLoadingHomepage = false;
    }
  }

  // ==================== PRODUCTS OPTIMIZATION ====================

  Future<List<dynamic>> getProducts({bool forceRefresh = false}) async {
    _optimizationService.startTimer('ProductsService_GetData');

    if (_isProductsCacheValid && _productsCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('ProductsService_GetData');
      return _productsCache;
    }

    if (_isLoadingProducts) {
      while (_isLoadingProducts) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('ProductsService_GetData');
      return _productsCache;
    }

    if (_productsCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('ProductsService_GetData');
      _fetchProductsData();
      return _productsCache;
    }

    return await _fetchProductsData();
  }

  Future<List<dynamic>> _fetchProductsData() async {
    _isLoadingProducts = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/products'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final products = data['data'] as List;
          _cacheProductsData(products);
          _optimizationService.endTimer('ProductsService_GetData');
          return products;
        }
      }
      throw Exception('Failed to load products');
    } catch (e) {
      _optimizationService.endTimer('ProductsService_GetData');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // ==================== USER DATA OPTIMIZATION ====================

  Future<Map<String, dynamic>> getUserData({bool forceRefresh = false}) async {
    _optimizationService.startTimer('UserDataService_GetData');

    if (_isUserDataCacheValid && _userDataCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('UserDataService_GetData');
      return _userDataCache;
    }

    if (_isLoadingUserData) {
      while (_isLoadingUserData) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('UserDataService_GetData');
      return _userDataCache;
    }

    return await _fetchUserData();
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    _isLoadingUserData = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/user/profile'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cacheUserData(data);
          _optimizationService.endTimer('UserDataService_GetData');
          return data;
        }
      }
      throw Exception('Failed to load user data');
    } catch (e) {
      _optimizationService.endTimer('UserDataService_GetData');
      rethrow;
    } finally {
      _isLoadingUserData = false;
    }
  }

  // ==================== NOTIFICATIONS OPTIMIZATION ====================

  Future<List<dynamic>> getNotifications({bool forceRefresh = false}) async {
    _optimizationService.startTimer('NotificationsService_GetData');

    if (_isNotificationsCacheValid &&
        _notificationsCache.isNotEmpty &&
        !forceRefresh) {
      _optimizationService.endTimer('NotificationsService_GetData');
      return _notificationsCache;
    }

    if (_isLoadingNotifications) {
      while (_isLoadingNotifications) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('NotificationsService_GetData');
      return _notificationsCache;
    }

    return await _fetchNotificationsData();
  }

  Future<List<dynamic>> _fetchNotificationsData() async {
    _isLoadingNotifications = true;

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/notifications'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final notifications = data['data'] as List;
          _cacheNotificationsData(notifications);
          _optimizationService.endTimer('NotificationsService_GetData');
          return notifications;
        }
      }
      throw Exception('Failed to load notifications');
    } catch (e) {
      _optimizationService.endTimer('NotificationsService_GetData');
      rethrow;
    } finally {
      _isLoadingNotifications = false;
    }
  }

  // ==================== CART OPTIMIZATION ====================

  Future<Map<String, dynamic>> getCartData({bool forceRefresh = false}) async {
    _optimizationService.startTimer('CartService_GetData');

    if (_isCartCacheValid && _cartCache.isNotEmpty && !forceRefresh) {
      _optimizationService.endTimer('CartService_GetData');
      return _cartCache;
    }

    if (_isLoadingCart) {
      while (_isLoadingCart) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _optimizationService.endTimer('CartService_GetData');
      return _cartCache;
    }

    return await _fetchCartData();
  }

  Future<Map<String, dynamic>> _fetchCartData() async {
    _isLoadingCart = true;

    try {
      final response = await http
          .get(Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/cart'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cacheCartData(data);
          _optimizationService.endTimer('CartService_GetData');
          return data;
        }
      }
      throw Exception('Failed to load cart data');
    } catch (e) {
      _optimizationService.endTimer('CartService_GetData');
      rethrow;
    } finally {
      _isLoadingCart = false;
    }
  }

  // ==================== CACHE VALIDATION ====================

  bool get _isHomepageCacheValid {
    if (_homepageCacheTime == null) return false;
    return DateTime.now().difference(_homepageCacheTime!) <
        _homepageCacheDuration;
  }

  bool get _isProductsCacheValid {
    if (_productsCacheTime == null) return false;
    return DateTime.now().difference(_productsCacheTime!) <
        _productsCacheDuration;
  }

  bool get _isUserDataCacheValid {
    if (_userDataCacheTime == null) return false;
    return DateTime.now().difference(_userDataCacheTime!) <
        _userDataCacheDuration;
  }

  bool get _isNotificationsCacheValid {
    if (_notificationsCacheTime == null) return false;
    return DateTime.now().difference(_notificationsCacheTime!) <
        _notificationsCacheDuration;
  }

  bool get _isCartCacheValid {
    if (_cartCacheTime == null) return false;
    return DateTime.now().difference(_cartCacheTime!) < _cartCacheDuration;
  }

  // ==================== CACHE OPERATIONS ====================

  void _cacheHomepageData(Map<String, dynamic> data) {
    _homepageCache = data;
    _homepageCacheTime = DateTime.now();
    _saveHomepageToStorage();
  }

  void _cacheProductsData(List<dynamic> products) {
    _productsCache = products;
    _productsCacheTime = DateTime.now();
    _saveProductsToStorage();
  }

  void _cacheUserData(Map<String, dynamic> data) {
    _userDataCache = data;
    _userDataCacheTime = DateTime.now();
    _saveUserDataToStorage();
  }

  void _cacheNotificationsData(List<dynamic> notifications) {
    _notificationsCache = notifications;
    _notificationsCacheTime = DateTime.now();
    _saveNotificationsToStorage();
  }

  void _cacheCartData(Map<String, dynamic> data) {
    _cartCache = data;
    _cartCacheTime = DateTime.now();
    _saveCartToStorage();
  }

  // ==================== STORAGE OPERATIONS ====================

  void _saveHomepageToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_homepageCacheKey, json.encode(_homepageCache));
      prefs.setString(
          _homepageCacheTimeKey, _homepageCacheTime!.toIso8601String());
    });
  }

  void _saveProductsToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_productsCacheKey, json.encode(_productsCache));
      prefs.setString(
          _productsCacheTimeKey, _productsCacheTime!.toIso8601String());
    });
  }

  void _saveUserDataToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_userDataCacheKey, json.encode(_userDataCache));
      prefs.setString(
          _userDataCacheTimeKey, _userDataCacheTime!.toIso8601String());
    });
  }

  void _saveNotificationsToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_notificationsCacheKey, json.encode(_notificationsCache));
      prefs.setString(_notificationsCacheTimeKey,
          _notificationsCacheTime!.toIso8601String());
    });
  }

  void _saveCartToStorage() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_cartCacheKey, json.encode(_cartCache));
      prefs.setString(_cartCacheTimeKey, _cartCacheTime!.toIso8601String());
    });
  }

  Future<void> _loadAllFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load homepage cache
      final homepageJson = prefs.getString(_homepageCacheKey);
      final homepageTimeString = prefs.getString(_homepageCacheTimeKey);
      if (homepageJson != null && homepageTimeString != null) {
        _homepageCache = json.decode(homepageJson);
        _homepageCacheTime = DateTime.parse(homepageTimeString);
      }

      // Load products cache
      final productsJson = prefs.getString(_productsCacheKey);
      final productsTimeString = prefs.getString(_productsCacheTimeKey);
      if (productsJson != null && productsTimeString != null) {
        _productsCache = json.decode(productsJson) as List;
        _productsCacheTime = DateTime.parse(productsTimeString);
      }

      // Load user data cache
      final userDataJson = prefs.getString(_userDataCacheKey);
      final userDataTimeString = prefs.getString(_userDataCacheTimeKey);
      if (userDataJson != null && userDataTimeString != null) {
        _userDataCache = json.decode(userDataJson);
        _userDataCacheTime = DateTime.parse(userDataTimeString);
      }

      // Load notifications cache
      final notificationsJson = prefs.getString(_notificationsCacheKey);
      final notificationsTimeString =
          prefs.getString(_notificationsCacheTimeKey);
      if (notificationsJson != null && notificationsTimeString != null) {
        _notificationsCache = json.decode(notificationsJson) as List;
        _notificationsCacheTime = DateTime.parse(notificationsTimeString);
      }

      // Load cart cache
      final cartJson = prefs.getString(_cartCacheKey);
      final cartTimeString = prefs.getString(_cartCacheTimeKey);
      if (cartJson != null && cartTimeString != null) {
        _cartCache = json.decode(cartJson);
        _cartCacheTime = DateTime.parse(cartTimeString);
      }
    } catch (e) {
      print('Failed to load comprehensive cache: $e');
    }
  }

  // ==================== IMAGE PRELOADING ====================

  Future<void> preloadImages(
      BuildContext context, List<String> imageUrls) async {
    for (final imageUrl in imageUrls.take(20)) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        _preloadedImages[imageUrl] = true;
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    }
  }

  // ==================== UTILITY METHODS ====================

  Future<List<dynamic>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final products = await getProducts();

    return products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final description =
          product['description']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) || description.contains(searchQuery);
    }).toList();
  }

  Future<void> clearAllCaches() async {
    _homepageCache.clear();
    _productsCache.clear();
    _userDataCache.clear();
    _notificationsCache.clear();
    _cartCache.clear();
    _preloadedImages.clear();

    _homepageCacheTime = null;
    _productsCacheTime = null;
    _userDataCacheTime = null;
    _notificationsCacheTime = null;
    _cartCacheTime = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homepageCacheKey);
      await prefs.remove(_homepageCacheTimeKey);
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_productsCacheTimeKey);
      await prefs.remove(_userDataCacheKey);
      await prefs.remove(_userDataCacheTimeKey);
      await prefs.remove(_notificationsCacheKey);
      await prefs.remove(_notificationsCacheTimeKey);
      await prefs.remove(_cartCacheKey);
      await prefs.remove(_cartCacheTimeKey);
    } catch (e) {
      print('Failed to clear comprehensive cache: $e');
    }
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'homepage_cache_valid': _isHomepageCacheValid,
      'products_cache_valid': _isProductsCacheValid,
      'user_data_cache_valid': _isUserDataCacheValid,
      'notifications_cache_valid': _isNotificationsCacheValid,
      'cart_cache_valid': _isCartCacheValid,
      'homepage_cache_size': _homepageCache.length,
      'products_cache_size': _productsCache.length,
      'notifications_cache_size': _notificationsCache.length,
      'preloaded_images_count': _preloadedImages.length,
    };
  }

  Future<void> refreshAllData() async {
    await getHomepageData(forceRefresh: true);
    await getProducts(forceRefresh: true);
    await getUserData(forceRefresh: true);
    await getNotifications(forceRefresh: true);
    await getCartData(forceRefresh: true);
  }
}
