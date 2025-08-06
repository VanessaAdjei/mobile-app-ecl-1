// services/performance_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance metrics
  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<double>> _metrics = {};
  final List<PerformanceEvent> _events = [];

  // Configuration
  bool _isEnabled = true;
  bool _shouldLogToConsole = true;
  bool _shouldSaveToStorage = true;
  final int _maxEvents = 1000;
  final int _maxMetrics = 100;

  // Cache configuration

  static const String _lastCleanupKey = 'last_cache_cleanup';

  // Cache configuration
  static const int maxMemoryCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxDiskCacheSize = 500 * 1024 * 1024; // 500MB
  static const Duration cacheCleanupInterval = Duration(days: 7);

  // Image size configurations
  static const Map<String, Map<String, int>> imageSizes = {
    'thumbnail': {
      'width': 120,
      'height': 120,
      'disk_width': 240,
      'disk_height': 240,
    },
    'medium': {
      'width': 400,
      'height': 400,
      'disk_width': 800,
      'disk_height': 800,
    },
    'large': {
      'width': 800,
      'height': 800,
      'disk_width': 1200,
      'disk_height': 1200,
    },
  };

  // Getters
  bool get isEnabled => _isEnabled;
  List<PerformanceEvent> get events => List.unmodifiable(_events);
  Map<String, List<double>> get metrics => Map.unmodifiable(_metrics);

  // Initialize performance monitoring
  Future<void> initialize() async {
    await _loadSettings();
    _startPeriodicCleanup();
    await _checkAndCleanupCache();
  }

  // Enable/Disable performance monitoring
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _saveSettings();
  }

  void setLogToConsole(bool enabled) {
    _shouldLogToConsole = enabled;
    _saveSettings();
  }

  void setSaveToStorage(bool enabled) {
    _shouldSaveToStorage = enabled;
    _saveSettings();
  }

  // Timer management
  void startTimer(String name) {
    if (!_isEnabled) return;

    _timers[name] = Stopwatch()..start();

    if (_shouldLogToConsole) {
      developer.log('Timer started: $name', name: 'Performance');
    }
  }

  void stopTimer(String name) {
    if (!_isEnabled || !_timers.containsKey(name)) return;

    final timer = _timers[name]!;
    timer.stop();

    final duration = timer.elapsedMilliseconds.toDouble();
    _addMetric('timer_$name', duration);

    _addEvent(PerformanceEvent(
      type: 'timer',
      name: name,
      value: duration,
      unit: 'ms',
      timestamp: DateTime.now(),
    ));

    _timers.remove(name);

    if (_shouldLogToConsole) {
      developer.log('Timer stopped: $name - ${duration}ms',
          name: 'Performance');
    }
  }

  // Memory usage tracking
  void trackMemoryUsage(String context) {
    if (!_isEnabled) return;

    // This is a simplified memory tracking
    // In a real app, you might use platform channels to get actual memory usage
    final memoryUsage = _estimateMemoryUsage();

    _addMetric('memory_$context', memoryUsage);

    _addEvent(PerformanceEvent(
      type: 'memory',
      name: context,
      value: memoryUsage,
      unit: 'MB',
      timestamp: DateTime.now(),
    ));

    if (_shouldLogToConsole) {
      developer.log('Memory usage ($context): ${memoryUsage}MB',
          name: 'Performance');
    }
  }

  // Widget build performance
  void trackWidgetBuild(String widgetName, VoidCallback buildCallback) {
    if (!_isEnabled) return;

    startTimer('widget_build_$widgetName');
    buildCallback();
    stopTimer('widget_build_$widgetName');
  }

  // API call performance
  void trackApiCall(String endpoint, Future<dynamic> Function() apiCall) async {
    if (!_isEnabled) return;

    startTimer('api_$endpoint');
    try {
      await apiCall();
    } finally {
      stopTimer('api_$endpoint');
    }
  }

  // Page load performance
  void trackPageLoad(String pageName) {
    if (!_isEnabled) return;

    _addEvent(PerformanceEvent(
      type: 'page_load',
      name: pageName,
      value: 1,
      unit: 'load',
      timestamp: DateTime.now(),
    ));

    if (_shouldLogToConsole) {
      developer.log('Page loaded: $pageName', name: 'Performance');
    }
  }

  // User interaction tracking
  void trackUserInteraction(String interaction,
      {Map<String, dynamic>? metadata}) {
    if (!_isEnabled) return;

    _addEvent(PerformanceEvent(
      type: 'interaction',
      name: interaction,
      value: 1,
      unit: 'interaction',
      timestamp: DateTime.now(),
      metadata: metadata,
    ));

    if (_shouldLogToConsole) {
      developer.log('User interaction: $interaction', name: 'Performance');
    }
  }

  // Error tracking
  void trackError(String error, {String? context, StackTrace? stackTrace}) {
    if (!_isEnabled) return;

    _addEvent(PerformanceEvent(
      type: 'error',
      name: error,
      value: 1,
      unit: 'error',
      timestamp: DateTime.now(),
      metadata: {
        'context': context,
        'stackTrace': stackTrace?.toString(),
      },
    ));

    if (_shouldLogToConsole) {
      developer.log('Error tracked: $error', name: 'Performance');
    }
  }

  // Add metric
  void _addMetric(String name, double value) {
    if (!_metrics.containsKey(name)) {
      _metrics[name] = [];
    }

    _metrics[name]!.add(value);

    // Keep only the last N metrics
    if (_metrics[name]!.length > _maxMetrics) {
      _metrics[name] =
          _metrics[name]!.skip(_metrics[name]!.length - _maxMetrics).toList();
    }
  }

  // Add event
  void _addEvent(PerformanceEvent event) {
    _events.add(event);

    // Keep only the last N events
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }

    if (_shouldSaveToStorage) {
      _saveEvents();
    }
  }

  // Get performance statistics
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};

    for (final entry in _metrics.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        stats[entry.key] = {
          'count': values.length,
          'average': values.reduce((a, b) => a + b) / values.length,
          'min': values.reduce((a, b) => a < b ? a : b),
          'max': values.reduce((a, b) => a > b ? a : b),
          'latest': values.last,
        };
      }
    }

    return stats;
  }

  // Get recent events
  List<PerformanceEvent> getRecentEvents({int count = 50}) {
    return _events.take(count).toList();
  }

  // Get events by type
  List<PerformanceEvent> getEventsByType(String type) {
    return _events.where((event) => event.type == type).toList();
  }

  // Clear all data
  void clearData() {
    _timers.clear();
    _metrics.clear();
    _events.clear();
    _saveEvents();
  }

  // Estimate memory usage (simplified)
  double _estimateMemoryUsage() {
    // This is a very rough estimate
    // In a real app, you'd use platform channels to get actual memory usage
    return (_events.length * 0.1 +
        _metrics.values.fold(0.0, (sum, list) => sum + list.length * 0.01));
  }

  // Periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupOldData();
    });
  }

  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    // Remove old events
    _events.removeWhere((event) => event.timestamp.isBefore(cutoff));

    // Remove old metrics (keep only last 24 hours worth)
    for (final entry in _metrics.entries) {
      if (entry.value.length > _maxMetrics) {
        _metrics[entry.key] =
            entry.value.skip(entry.value.length - _maxMetrics).toList();
      }
    }

    if (_shouldSaveToStorage) {
      _saveEvents();
    }
  }

  // Storage management
  Future<void> _saveEvents() async {
    if (!_shouldSaveToStorage) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = _events.map((e) => e.toJson()).toList();
      await prefs.setString('performance_events', json.encode(eventsJson));
    } catch (e) {
      developer.log('Failed to save performance events: $e',
          name: 'Performance');
    }
  }

  Future<void> _loadEvents() async {
    if (!_shouldSaveToStorage) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString('performance_events');
      if (eventsJson != null) {
        final eventsList = json.decode(eventsJson) as List;
        _events.clear();
        _events.addAll(eventsList.map((e) => PerformanceEvent.fromJson(e)));
      }
    } catch (e) {
      developer.log('Failed to load performance events: $e',
          name: 'Performance');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('performance_enabled', _isEnabled);
      await prefs.setBool('performance_log_console', _shouldLogToConsole);
      await prefs.setBool('performance_save_storage', _shouldSaveToStorage);
    } catch (e) {
      developer.log('Failed to save performance settings: $e',
          name: 'Performance');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('performance_enabled') ?? true;
      _shouldLogToConsole = prefs.getBool('performance_log_console') ?? true;
      _shouldSaveToStorage = prefs.getBool('performance_save_storage') ?? true;

      await _loadEvents();
    } catch (e) {
      developer.log('Failed to load performance settings: $e',
          name: 'Performance');
    }
  }

  // Dispose
  void dispose() {
    _timers.clear();
    _metrics.clear();
    _events.clear();
  }

  /// Get optimized image widget for thumbnails
  static Widget getOptimizedThumbnail({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    final size = imageSizes['thumbnail']!;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: size['width'],
        memCacheHeight: size['height'],
        maxWidthDiskCache: size['disk_width'],
        maxHeightDiskCache: size['disk_height'],
        placeholder:
            placeholder ?? (context, url) => _buildDefaultPlaceholder(),
        errorWidget: errorWidget ??
            (context, url, error) => _buildDefaultErrorWidget(error),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// Get optimized image widget for medium size images
  static Widget getOptimizedMediumImage({
    required String imageUrl,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    final size = imageSizes['medium']!;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: size['width'],
        memCacheHeight: size['height'],
        maxWidthDiskCache: size['disk_width'],
        maxHeightDiskCache: size['disk_height'],
        placeholder: placeholder ?? (context, url) => _buildMediumPlaceholder(),
        errorWidget: errorWidget ??
            (context, url, error) => _buildMediumErrorWidget(error),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Get optimized image widget for large images
  static Widget getOptimizedLargeImage({
    required String imageUrl,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    final size = imageSizes['large']!;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: size['width'],
        memCacheHeight: size['height'],
        maxWidthDiskCache: size['disk_width'],
        maxHeightDiskCache: size['disk_height'],
        placeholder: placeholder ?? (context, url) => _buildLargePlaceholder(),
        errorWidget: errorWidget ??
            (context, url, error) => _buildLargeErrorWidget(error),
        fadeInDuration: const Duration(milliseconds: 400),
        fadeOutDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Build default placeholder for thumbnails
  static Widget _buildDefaultPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        ),
      ),
    );
  }

  /// Build default error widget for thumbnails
  static Widget _buildDefaultErrorWidget(dynamic error) {
    String errorCode = '404';
    if (error.toString().contains('timeout')) {
      errorCode = 'TO';
    } else if (error.toString().contains('network')) {
      errorCode = 'NE';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 2),
          Text(
            errorCode,
            style: TextStyle(
              fontSize: 8,
              color: Colors.red.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build medium placeholder
  static Widget _buildMediumPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build medium error widget
  static Widget _buildMediumErrorWidget(dynamic error) {
    String errorTitle = 'Failed to load image';
    String errorMessage = 'The image could not be loaded.';

    if (error.toString().contains('404')) {
      errorTitle = 'Image File Not Found';
      errorMessage =
          'The image file has been removed or is no longer available.';
    } else if (error.toString().contains('timeout')) {
      errorTitle = 'Connection Timeout';
      errorMessage =
          'The request to load the image timed out. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      errorTitle = 'Network Error';
      errorMessage = 'There was a network error while loading the image.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build large placeholder
  static Widget _buildLargePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading prescription...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Build large error widget
  static Widget _buildLargeErrorWidget(dynamic error) {
    String errorTitle = 'Failed to load prescription image';
    String errorMessage = 'The image could not be loaded.';

    if (error.toString().contains('404')) {
      errorTitle = 'Image File Not Found';
      errorMessage =
          'The prescription image file has been removed or is no longer available on the server.';
    } else if (error.toString().contains('timeout')) {
      errorTitle = 'Connection Timeout';
      errorMessage =
          'The request to load the image timed out. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      errorTitle = 'Network Error';
      errorMessage = 'There was a network error while loading the image.';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Check and cleanup cache if needed
  Future<void> _checkAndCleanupCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);

      if (lastCleanup == null) {
        await _performCacheCleanup();
        return;
      }

      final lastCleanupDate = DateTime.parse(lastCleanup);
      final now = DateTime.now();

      if (now.difference(lastCleanupDate) > cacheCleanupInterval) {
        await _performCacheCleanup();
      }
    } catch (e) {
      // Silently handle cleanup errors
      debugPrint('Cache cleanup error: $e');
    }
  }

  /// Perform cache cleanup
  Future<void> _performCacheCleanup() async {
    try {
      // Note: In cached_network_image 3.4.1, we can't clear all cache without specific URLs
      // The cache will be managed automatically by the package

      // Update last cleanup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCleanupKey, DateTime.now().toIso8601String());

      debugPrint('Cache cleanup timestamp updated');
    } catch (e) {
      debugPrint('Cache cleanup failed: $e');
    }
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    try {
      // Note: In cached_network_image 3.4.1, we can't clear all cache without specific URLs
      // This method is kept for future compatibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastCleanupKey);
      debugPrint('Cache cleanup timestamp cleared');
    } catch (e) {
      debugPrint('Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);

      return {
        'last_cleanup': lastCleanup,
        'max_memory_cache': maxMemoryCacheSize,
        'max_disk_cache': maxDiskCacheSize,
        'cleanup_interval_days': cacheCleanupInterval.inDays,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

// Performance event class
class PerformanceEvent {
  final String type;
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceEvent({
    required this.type,
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory PerformanceEvent.fromJson(Map<String, dynamic> json) {
    return PerformanceEvent(
      type: json['type'],
      name: json['name'],
      value: json['value'].toDouble(),
      unit: json['unit'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
    );
  }

  @override
  String toString() {
    return 'PerformanceEvent(type: $type, name: $name, value: $value $unit, timestamp: $timestamp)';
  }
}
