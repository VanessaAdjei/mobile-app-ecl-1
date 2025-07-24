// services/advanced_performance_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/product_model.dart';

class AdvancedPerformanceService {
  static final AdvancedPerformanceService _instance =
      AdvancedPerformanceService._internal();
  factory AdvancedPerformanceService() => _instance;
  AdvancedPerformanceService._internal();

  // Performance monitoring
  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<double>> _metrics = {};
  final List<PerformanceEvent> _events = [];

  // Cache management
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, Timer> _cacheTimers = {};
  static const int _maxMemoryCacheSize = 100;
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  // Request batching
  final Map<String, List<Completer>> _pendingRequests = {};
  final Map<String, Timer> _batchTimers = {};
  static const Duration _batchTimeout = Duration(milliseconds: 100);

  // Image optimization
  final Map<String, bool> _preloadedImages = {};
  final Map<String, ImageProvider> _imageProviders = {};

  // Memory management
  bool _isLowMemory = false;
  Timer? _memoryCleanupTimer;

  // Configuration
  bool _isEnabled = true;
  bool _shouldLogToConsole = true;
  static const int _maxEvents = 1000;
  static const int _maxMetrics = 100;

  // Getters
  bool get isEnabled => _isEnabled;
  List<PerformanceEvent> get events => List.unmodifiable(_events);
  Map<String, List<double>> get metrics => Map.unmodifiable(_metrics);

  // Initialize the service
  Future<void> initialize() async {
    await _loadSettings();
    _startMemoryCleanup();
    _configureImageCache();
    developer.log('Advanced Performance Service initialized',
        name: 'Performance');
  }

  // ==================== INTELLIGENT CACHING ====================

  /// Get cached data with intelligent fallback
  Future<T?> getCachedData<T>(
    String key,
    Future<T> Function() fetchFunction, {
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    if (!_isEnabled) return await fetchFunction();

    final duration = cacheDuration ?? _defaultCacheDuration;

    // Check memory cache first
    if (!forceRefresh && _memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (DateTime.now().difference(entry.timestamp) < duration) {
        _trackEvent('cache_hit', {'key': key, 'type': 'memory'});
        return entry.data as T;
      } else {
        // Cache expired, remove it
        _memoryCache.remove(key);
        _cacheTimers[key]?.cancel();
        _cacheTimers.remove(key);
      }
    }

    // Check persistent cache
    if (!forceRefresh) {
      final cached = await _getPersistentCache<T>(key);
      if (cached != null) {
        _addToMemoryCache(key, cached, duration);
        _trackEvent('cache_hit', {'key': key, 'type': 'persistent'});
        return cached;
      }
    }

    // Fetch fresh data
    _trackEvent('cache_miss', {'key': key});
    try {
      final data = await fetchFunction();
      await _setPersistentCache(key, data, duration);
      _addToMemoryCache(key, data, duration);
      return data;
    } catch (e) {
      _trackEvent('fetch_error', {'key': key, 'error': e.toString()});
      rethrow;
    }
  }

  /// Add data to memory cache with automatic cleanup
  void _addToMemoryCache<T>(String key, T data, Duration duration) {
    // Remove oldest entries if cache is full
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
      _cacheTimers[oldestKey]?.cancel();
      _cacheTimers.remove(oldestKey);
    }

    _memoryCache[key] = CacheEntry(data, DateTime.now());

    // Set timer to remove from memory cache
    _cacheTimers[key] = Timer(duration, () {
      _memoryCache.remove(key);
      _cacheTimers.remove(key);
    });
  }

  // ==================== REQUEST BATCHING ====================

  /// Batch multiple requests for the same endpoint
  Future<T> batchRequest<T>(
    String endpoint,
    Future<T> Function() requestFunction,
  ) async {
    if (!_isEnabled) return await requestFunction();

    final completer = Completer<T>();

    if (_pendingRequests.containsKey(endpoint)) {
      // Add to existing batch
      _pendingRequests[endpoint]!.add(completer);
    } else {
      // Start new batch
      _pendingRequests[endpoint] = [completer];

      // Set timer to execute batch
      _batchTimers[endpoint] = Timer(_batchTimeout, () async {
        await _executeBatch(endpoint, requestFunction);
      });
    }

    return completer.future;
  }

  /// Execute a batch of requests
  Future<void> _executeBatch<T>(
    String endpoint,
    Future<T> Function() requestFunction,
  ) async {
    final completers = _pendingRequests.remove(endpoint) ?? [];
    _batchTimers[endpoint]?.cancel();
    _batchTimers.remove(endpoint);

    if (completers.isEmpty) return;

    try {
      final result = await requestFunction();

      // Resolve all pending requests with the same result
      for (final completer in completers) {
        completer.complete(result);
      }

      _trackEvent('batch_completed', {
        'endpoint': endpoint,
        'count': completers.length,
      });
    } catch (e) {
      // Reject all pending requests
      for (final completer in completers) {
        completer.completeError(e);
      }

      _trackEvent('batch_error', {
        'endpoint': endpoint,
        'error': e.toString(),
      });
    }
  }

  // ==================== IMAGE OPTIMIZATION ====================

  /// Preload images with intelligent sizing
  Future<void> preloadImages(
    List<String> imageUrls,
    BuildContext context, {
    int maxImages = 20,
    bool prioritizeVisible = true,
  }) async {
    if (!_isEnabled) return;

    final urlsToPreload = imageUrls
        .where((url) => url.isNotEmpty && !_preloadedImages.containsKey(url))
        .take(maxImages)
        .toList();

    if (urlsToPreload.isEmpty) return;

    developer.log('Preloading ${urlsToPreload.length} images',
        name: 'Performance');

    // Preload in background
    unawaited(_preloadImagesInBackground(urlsToPreload, context));
  }

  /// Preload images in background thread
  Future<void> _preloadImagesInBackground(
    List<String> imageUrls,
    BuildContext context,
  ) async {
    for (final imageUrl in imageUrls) {
      if (!_preloadedImages.containsKey(imageUrl)) {
        try {
          _preloadedImages[imageUrl] = true;

          // Use optimized image provider
          final provider = CachedNetworkImageProvider(
            imageUrl,
            maxWidth: 400,
            maxHeight: 400,
          );

          _imageProviders[imageUrl] = provider;
          await precacheImage(provider, context);

          _trackEvent('image_preloaded', {'url': imageUrl});
        } catch (e) {
          _preloadedImages.remove(imageUrl);
          _imageProviders.remove(imageUrl);
          developer.log('Failed to preload image: $imageUrl - $e',
              name: 'Performance');
        }
      }
    }
  }

  /// Get optimized image widget
  Widget getOptimizedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: (width * 2).round(),
        memCacheHeight: (height * 2).round(),
        maxWidthDiskCache: (width * 2).round(),
        maxHeightDiskCache: (height * 2).round(),
        placeholder:
            placeholder ?? (context, url) => _buildDefaultPlaceholder(),
        errorWidget: errorWidget ??
            (context, url, error) => _buildDefaultErrorWidget(error),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // ==================== PERFORMANCE MONITORING ====================

  /// Start performance timer
  void startTimer(String name) {
    if (!_isEnabled) return;
    _timers[name] = Stopwatch()..start();
  }

  /// Stop performance timer and record metric
  void stopTimer(String name) {
    if (!_isEnabled || !_timers.containsKey(name)) return;

    final timer = _timers.remove(name)!;
    timer.stop();

    final duration = timer.elapsedMilliseconds.toDouble();

    if (!_metrics.containsKey(name)) {
      _metrics[name] = [];
    }

    _metrics[name]!.add(duration);

    // Keep only recent metrics
    if (_metrics[name]!.length > _maxMetrics) {
      _metrics[name] =
          _metrics[name]!.sublist(_metrics[name]!.length - _maxMetrics);
    }

    _trackEvent('timer_stopped', {
      'name': name,
      'duration': duration,
    });
  }

  /// Track custom performance event
  void _trackEvent(String type, Map<String, dynamic> data) {
    if (!_isEnabled) return;

    final event = PerformanceEvent(type, data, DateTime.now());
    _events.add(event);

    // Keep only recent events
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }

    if (_shouldLogToConsole) {
      developer.log('Performance Event: $type - $data', name: 'Performance');
    }
  }

  // ==================== MEMORY MANAGEMENT ====================

  /// Start periodic memory cleanup
  void _startMemoryCleanup() {
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performMemoryCleanup();
    });
  }

  /// Perform memory cleanup
  void _performMemoryCleanup() {
    if (_isLowMemory) {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear memory cache
      _memoryCache.clear();
      for (final timer in _cacheTimers.values) {
        timer.cancel();
      }
      _cacheTimers.clear();

      // Clear preloaded images
      _preloadedImages.clear();
      _imageProviders.clear();

      developer.log('Memory cleanup performed', name: 'Performance');
    }

    // Clean up old events
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
    _events.removeWhere((event) => event.timestamp.isBefore(cutoffTime));
  }

  /// Configure image cache settings
  void _configureImageCache() {
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
  }

  // ==================== PERSISTENT CACHE ====================

  /// Get data from persistent cache
  Future<T?> _getPersistentCache<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('perf_cache_$key');
      final cachedTime = prefs.getInt('perf_cache_time_$key');

      if (cachedData != null && cachedTime != null) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedTime);
        if (DateTime.now().difference(timestamp) < _defaultCacheDuration) {
          final decodedData = json.decode(cachedData);

          // For complex types, we'll let the calling code handle the conversion
          // This avoids runtime type checking issues
          try {
            return decodedData as T;
          } catch (e) {
            developer.log('Cache type conversion failed for key $key: $e',
                name: 'Performance');
            return null;
          }
        }
      }
    } catch (e) {
      developer.log('Failed to get persistent cache: $e', name: 'Performance');
    }
    return null;
  }

  /// Set data in persistent cache
  Future<void> _setPersistentCache<T>(
      String key, T data, Duration duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perf_cache_$key', json.encode(data));
      await prefs.setInt(
          'perf_cache_time_$key', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('Failed to set persistent cache: $e', name: 'Performance');
    }
  }

  // ==================== SETTINGS MANAGEMENT ====================

  /// Load performance settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('perf_enabled') ?? true;
      _shouldLogToConsole = prefs.getBool('perf_log_console') ?? true;
    } catch (e) {
      developer.log('Failed to load performance settings: $e',
          name: 'Performance');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Build default placeholder widget
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget(dynamic error) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};

    // Cache statistics
    stats['memory_cache_size'] = _memoryCache.length;
    stats['preloaded_images'] = _preloadedImages.length;
    stats['pending_requests'] = _pendingRequests.length;

    // Timer statistics
    for (final entry in _metrics.entries) {
      if (entry.value.isNotEmpty) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final min = entry.value.reduce((a, b) => a < b ? a : b);
        final max = entry.value.reduce((a, b) => a > b ? a : b);

        stats['${entry.key}_avg'] = avg;
        stats['${entry.key}_min'] = min;
        stats['${entry.key}_max'] = max;
        stats['${entry.key}_count'] = entry.value.length;
      }
    }

    // Event statistics
    final eventCounts = <String, int>{};
    for (final event in _events) {
      eventCounts[event.type] = (eventCounts[event.type] ?? 0) + 1;
    }
    stats['event_counts'] = eventCounts;

    return stats;
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _memoryCache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
    _preloadedImages.clear();
    _imageProviders.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('perf_cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      developer.log('Failed to clear persistent cache: $e',
          name: 'Performance');
    }

    developer.log('All caches cleared', name: 'Performance');
  }

  /// Dispose the service
  void dispose() {
    _memoryCleanupTimer?.cancel();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _timers.clear();
    _metrics.clear();
    _events.clear();
    _memoryCache.clear();
    _pendingRequests.clear();
    _preloadedImages.clear();
    _imageProviders.clear();
  }
}

// Helper classes
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);
}

class PerformanceEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  PerformanceEvent(this.type, this.data, this.timestamp);
}
