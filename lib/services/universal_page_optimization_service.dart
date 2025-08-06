// services/universal_page_optimization_service.dart
import 'dart:async';

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'advanced_performance_service.dart';

class UniversalPageOptimizationService {
  static final UniversalPageOptimizationService _instance =
      UniversalPageOptimizationService._internal();
  factory UniversalPageOptimizationService() => _instance;
  UniversalPageOptimizationService._internal();

  // Performance service
  final AdvancedPerformanceService _performanceService =
      AdvancedPerformanceService();

  // Cache configuration
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  // Loading states
  final Map<String, bool> _isLoading = {};
  final Map<String, Timer> _debounceTimers = {};

  // Initialize the service
  Future<void> initialize() async {
    await _performanceService.initialize();
    developer.log('Universal Page Optimization Service initialized',
        name: 'PageOptimization');
  }

  Future<T?> fetchData<T>(
    String cacheKey,
    Future<T> Function() fetchFunction, {
    Duration? cacheDuration,
    bool forceRefresh = false,
    String? pageName,
  }) async {
    final timerName = '${pageName ?? 'page'}_fetch_$cacheKey';
    _performanceService.startTimer(timerName);

    try {
      final data = await _performanceService.getCachedData<T>(
        cacheKey,
        fetchFunction,
        cacheDuration: cacheDuration ?? _defaultCacheDuration,
        forceRefresh: forceRefresh,
      );

      _performanceService.stopTimer(timerName);
      return data;
    } catch (e) {
      _performanceService.stopTimer(timerName);
      developer.log('Failed to fetch data for $cacheKey: $e',
          name: 'PageOptimization');
      rethrow;
    }
  }

  /// Batch fetch multiple data sources
  Future<Map<String, dynamic>> fetchMultipleData(
    Map<String, Future<dynamic> Function()> fetchFunctions, {
    Duration? cacheDuration,
    bool forceRefresh = false,
    String? pageName,
  }) async {
    final timerName = '${pageName ?? 'page'}_batch_fetch';
    _performanceService.startTimer(timerName);

    try {
      final futures = <String, Future<dynamic>>{};

      for (final entry in fetchFunctions.entries) {
        final cacheKey = entry.key;
        final fetchFunction = entry.value;

        futures[cacheKey] = _performanceService.getCachedData(
          cacheKey,
          fetchFunction,
          cacheDuration: cacheDuration ?? _defaultCacheDuration,
          forceRefresh: forceRefresh,
        );
      }

      final results = await Future.wait(futures.values);
      final data = <String, dynamic>{};

      int index = 0;
      for (final key in futures.keys) {
        data[key] = results[index];
        index++;
      }

      _performanceService.stopTimer(timerName);
      return data;
    } catch (e) {
      _performanceService.stopTimer(timerName);
      developer.log('Failed to fetch multiple data: $e',
          name: 'PageOptimization');
      rethrow;
    }
  }

  // ==================== IMAGE OPTIMIZATION ====================

  /// Optimize images for any page
  Future<void> optimizePageImages(
    BuildContext context,
    List<String> imageUrls, {
    int maxImages = 30,
    String? pageName,
  }) async {
    if (imageUrls.isEmpty) return;

    final timerName = '${pageName ?? 'page'}_image_optimization';
    _performanceService.startTimer(timerName);

    try {
      await _performanceService.preloadImages(
        imageUrls,
        context,
        maxImages: maxImages,
      );

      _performanceService.stopTimer(timerName);
    } catch (e) {
      _performanceService.stopTimer(timerName);
      developer.log('Failed to optimize images: $e', name: 'PageOptimization');
    }
  }

  /// Get optimized image widget for any context
  Widget getOptimizedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return _performanceService.getOptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  // ==================== DEBOUNCED OPERATIONS ====================

  /// Debounce operations to prevent excessive calls
  void debounceOperation(
    String key,
    VoidCallback operation, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, operation);
  }

  /// Cancel debounced operation
  void cancelDebouncedOperation(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }

  // ==================== LOADING STATE MANAGEMENT ====================

  /// Set loading state for a specific operation
  void setLoading(String key, bool isLoading) {
    _isLoading[key] = isLoading;
  }

  /// Check if operation is loading
  bool isLoading(String key) {
    return _isLoading[key] ?? false;
  }

  /// Wait for operation to complete
  Future<void> waitForOperation(String key) async {
    while (_isLoading[key] == true) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // ==================== ERROR HANDLING ====================

  /// Handle errors with user-friendly messages
  String getErrorMessage(dynamic error) {
    if (error is http.ClientException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error.toString().contains('404')) {
      return 'Data not found. Please try again later.';
    } else if (error.toString().contains('500')) {
      return 'Server error. Please try again later.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Show error snackbar
  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Clear specific cache
  Future<void> clearCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('perf_cache_$cacheKey');
      await prefs.remove('perf_cache_time_$cacheKey');
      developer.log('Cleared cache: $cacheKey', name: 'PageOptimization');
    } catch (e) {
      developer.log('Failed to clear cache: $e', name: 'PageOptimization');
    }
  }

  /// Clear all page caches
  Future<void> clearAllPageCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('perf_cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      developer.log('Cleared all page caches', name: 'PageOptimization');
    } catch (e) {
      developer.log('Failed to clear page caches: $e',
          name: 'PageOptimization');
    }
  }

  // ==================== PERFORMANCE MONITORING ====================

  /// Track page performance
  void trackPagePerformance(String pageName, String operation) {
    _performanceService.startTimer('${pageName}_$operation');
  }

  /// Stop page performance tracking
  void stopPagePerformanceTracking(String pageName, String operation) {
    _performanceService.stopTimer('${pageName}_$operation');
  }

  /// Get page performance statistics
  Map<String, dynamic> getPagePerformanceStats() {
    return _performanceService.getPerformanceStats();
  }

  // ==================== UTILITY METHODS ====================

  /// Get optimized image URL
  String getOptimizedImageUrl(String? imagePath, {String? baseUrl}) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    final base = baseUrl ?? 'https://adm-ecommerce.ernestchemists.com.gh';

    if (imagePath.startsWith('/uploads/')) {
      return '$base$imagePath';
    }

    if (imagePath.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$imagePath';
    }

    return '$base/uploads/product/$imagePath';
  }

  /// Build loading widget
  Widget buildLoadingWidget({
    String? message,
    double size = 40.0,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build error widget
  Widget buildErrorWidget({
    required String message,
    required VoidCallback onRetry,
    IconData? icon,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build empty state widget
  Widget buildEmptyStateWidget({
    required String message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== PAGE-SPECIFIC OPTIMIZATIONS ====================

  /// Optimize cart page
  Future<Map<String, dynamic>> optimizeCartPage({
    required Future<List<dynamic>> Function() fetchCartItems,
    required Future<Map<String, dynamic>> Function() fetchCartSummary,
    bool forceRefresh = false,
  }) async {
    return fetchMultipleData({
      'cart_items': fetchCartItems,
      'cart_summary': fetchCartSummary,
    }, pageName: 'cart', forceRefresh: forceRefresh);
  }

  /// Optimize profile page
  Future<Map<String, dynamic>> optimizeProfilePage({
    required Future<Map<String, dynamic>> Function() fetchUserProfile,
    required Future<List<dynamic>> Function() fetchOrderHistory,
    bool forceRefresh = false,
  }) async {
    return fetchMultipleData({
      'user_profile': fetchUserProfile,
      'order_history': fetchOrderHistory,
    }, pageName: 'profile', forceRefresh: forceRefresh);
  }

  /// Optimize categories page
  Future<Map<String, dynamic>> optimizeCategoriesPage({
    required Future<List<dynamic>> Function() fetchCategories,
    required Future<List<dynamic>> Function() fetchProducts,
    bool forceRefresh = false,
  }) async {
    return fetchMultipleData({
      'categories': fetchCategories,
      'products': fetchProducts,
    }, pageName: 'categories', forceRefresh: forceRefresh);
  }

  /// Optimize payment page
  Future<Map<String, dynamic>> optimizePaymentPage({
    required Future<Map<String, dynamic>> Function() fetchPaymentMethods,
    required Future<Map<String, dynamic>> Function() fetchOrderDetails,
    bool forceRefresh = false,
  }) async {
    return fetchMultipleData({
      'payment_methods': fetchPaymentMethods,
      'order_details': fetchOrderDetails,
    }, pageName: 'payment', forceRefresh: forceRefresh);
  }

  // ==================== DISPOSE ====================

  /// Dispose the service
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _isLoading.clear();
  }
}
