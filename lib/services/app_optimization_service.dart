// services/app_optimization_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

class AppOptimizationService {
  static final AppOptimizationService _instance =
      AppOptimizationService._internal();
  factory AppOptimizationService() => _instance;
  AppOptimizationService._internal();

  // Performance monitoring
  final Map<String, Stopwatch> _performanceTimers = {};
  final List<PerformanceMetric> _metrics = [];

  // Memory management
  Timer? _memoryCleanupTimer;
  Timer? _cacheCleanupTimer;

  // Network optimization
  final Map<String, DateTime> _apiCallTimestamps = {};
  final Map<String, dynamic> _apiResponseCache = {};

  // App state
  bool _isBackgrounded = false;
  bool _isLowMemory = false;

  // Configuration
  static const Duration _memoryCleanupInterval = Duration(minutes: 5);
  static const Duration _cacheCleanupInterval = Duration(hours: 1);
  static const Duration _apiCacheExpiry = Duration(minutes: 15);
  static const int _maxApiCacheSize = 100;
  static const int _maxMetricsSize = 1000;

  // Initialize optimization service
  Future<void> initialize() async {
    await _configureSystemUI();
    await _setupMemoryManagement();
    await _setupCacheManagement();
    await _loadOptimizationSettings();

    developer.log('AppOptimizationService initialized', name: 'Optimization');
  }

  // Configure system UI for better performance
  Future<void> _configureSystemUI() async {
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Configure system UI overlay
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Setup memory management
  Future<void> _setupMemoryManagement() async {
    _memoryCleanupTimer = Timer.periodic(_memoryCleanupInterval, (timer) {
      _performMemoryCleanup();
    });
  }

  // Setup cache management
  Future<void> _setupCacheManagement() async {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (timer) {
      _performCacheCleanup();
    });
  }

  // Load optimization settings
  Future<void> _loadOptimizationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load any saved optimization settings here
    } catch (e) {
      developer.log('Failed to load optimization settings: $e',
          name: 'Optimization');
    }
  }

  // Performance monitoring
  void startTimer(String name) {
    _performanceTimers[name] = Stopwatch()..start();
  }

  void endTimer(String name) {
    final timer = _performanceTimers[name];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds;

      _metrics.add(PerformanceMetric(
        name: name,
        duration: duration,
        timestamp: DateTime.now(),
      ));

      // Keep only recent metrics
      if (_metrics.length > _maxMetricsSize) {
        _metrics.removeRange(0, _metrics.length - _maxMetricsSize);
      }

      _performanceTimers.remove(name);

      developer.log('Performance: $name took ${duration}ms',
          name: 'Optimization');
    }
  }

  // API response caching
  Future<T?> getCachedResponse<T>(
      String key, Future<T> Function() fetchFunction) async {
    // Check if we have a valid cached response
    if (_apiResponseCache.containsKey(key)) {
      final cachedData = _apiResponseCache[key];
      final timestamp = _apiCallTimestamps[key];

      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _apiCacheExpiry) {
        developer.log('Using cached response for: $key', name: 'Optimization');
        return cachedData as T;
      }
    }

    // Fetch fresh data
    try {
      final data = await fetchFunction();

      // Cache the response
      _apiResponseCache[key] = data;
      _apiCallTimestamps[key] = DateTime.now();

      // Cleanup old cache entries
      if (_apiResponseCache.length > _maxApiCacheSize) {
        final oldestKey = _apiCallTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _apiResponseCache.remove(oldestKey);
        _apiCallTimestamps.remove(oldestKey);
      }

      return data;
    } catch (e) {
      developer.log('Failed to fetch data for: $key - $e',
          name: 'Optimization');
      rethrow;
    }
  }

  // Memory cleanup
  void _performMemoryCleanup() {
    try {
      // Clear image cache if memory is low
      if (_isLowMemory) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      // Clear old performance metrics
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
      _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoffTime));

      developer.log('Memory cleanup performed', name: 'Optimization');
    } catch (e) {
      developer.log('Memory cleanup failed: $e', name: 'Optimization');
    }
  }

  // Cache cleanup
  void _performCacheCleanup() {
    try {
      // Clear expired API cache
      final cutoffTime = DateTime.now().subtract(_apiCacheExpiry);
      final expiredKeys = _apiCallTimestamps.entries
          .where((entry) => entry.value.isBefore(cutoffTime))
          .map((entry) => entry.key)
          .toList();

      for (final key in expiredKeys) {
        _apiResponseCache.remove(key);
        _apiCallTimestamps.remove(key);
      }

      developer.log(
          'Cache cleanup performed, removed ${expiredKeys.length} entries',
          name: 'Optimization');
    } catch (e) {
      developer.log('Cache cleanup failed: $e', name: 'Optimization');
    }
  }

  // App lifecycle management
  void onAppBackgrounded() {
    _isBackgrounded = true;
    _performMemoryCleanup();
    developer.log('App backgrounded, performing cleanup', name: 'Optimization');
  }

  void onAppForegrounded() {
    _isBackgrounded = false;
    developer.log('App foregrounded', name: 'Optimization');
  }

  void onLowMemory() {
    _isLowMemory = true;
    _performMemoryCleanup();
    developer.log('Low memory detected, performing cleanup',
        name: 'Optimization');
  }

  // Get performance metrics
  List<PerformanceMetric> getPerformanceMetrics() {
    return List.unmodifiable(_metrics);
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'api_cache_size': _apiResponseCache.length,
      'max_api_cache_size': _maxApiCacheSize,
      'metrics_count': _metrics.length,
      'max_metrics_size': _maxMetricsSize,
      'is_backgrounded': _isBackgrounded,
      'is_low_memory': _isLowMemory,
    };
  }

  // Clear all caches
  Future<void> clearAllCaches() async {
    _apiResponseCache.clear();
    _apiCallTimestamps.clear();
    _metrics.clear();
    _performanceTimers.clear();

    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    developer.log('All caches cleared', name: 'Optimization');
  }

  // Dispose resources
  void dispose() {
    _memoryCleanupTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    _performanceTimers.clear();
    _metrics.clear();
    _apiResponseCache.clear();
    _apiCallTimestamps.clear();
  }
}

// Performance metric model
class PerformanceMetric {
  final String name;
  final int duration;
  final DateTime timestamp;

  PerformanceMetric({
    required this.name,
    required this.duration,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// Widget optimization utilities
class WidgetOptimizer {
  // Optimize list view with automatic item caching
  static Widget optimizedListView<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    ScrollController? controller,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
  }) {
    return ListView.builder(
      controller: controller,
      itemCount: items.length,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }

  // Optimize grid view with automatic item caching
  static Widget optimizedGridView<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
  }) {
    return GridView.builder(
      controller: controller,
      gridDelegate: gridDelegate,
      itemCount: items.length,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }

  // Create a debounced text field
  static Widget debouncedTextField({
    required TextEditingController controller,
    required Function(String) onChanged,
    Duration debounceDuration = const Duration(milliseconds: 500),
    InputDecoration? decoration,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    Timer? _debounceTimer;

    return TextField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: (value) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(debounceDuration, () {
          onChanged(value);
        });
      },
    );
  }
}
