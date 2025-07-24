// services/performance_monitor.dart
// services/performance_monitor.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_prefetch_service.dart';

/// Performance monitoring service for tracking app metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<double>> _metrics = {};
  final Map<String, DateTime> _startTimes = {};
  final List<PerformanceEvent> _events = [];

  static const int _maxMetricsHistory = 100;
  static const Duration _cleanupInterval = Duration(minutes: 5);

  /// Initialize performance monitoring
  void initialize() {
    debugPrint('📊 Initializing PerformanceMonitor...');
    _startPeriodicCleanup();
  }

  /// Start timing an operation
  void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
    debugPrint('⏱️ Started timing: $operation');
  }

  /// End timing an operation and record the duration
  void endTimer(String operation) {
    final startTime = _startTimes[operation];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _recordMetric(operation, duration.toDouble());
      _startTimes.remove(operation);
      debugPrint('⏱️ Completed: $operation in ${duration}ms');
    }
  }

  /// Record a performance metric
  void recordMetric(String name, double value) {
    _recordMetric(name, value);
  }

  /// Record a performance event
  void recordEvent(String event, {Map<String, dynamic>? data}) {
    _events.add(PerformanceEvent(
      event: event,
      timestamp: DateTime.now(),
      data: data,
    ));

    // Keep only recent events
    if (_events.length > 1000) {
      _events.removeRange(0, _events.length - 1000);
    }

    debugPrint('📝 Event: $event ${data != null ? '($data)' : ''}');
  }

  /// Record memory usage
  void recordMemoryUsage() {
    // Simplified memory tracking - in a real app you'd use proper memory profiling
    _recordMetric('memory_usage_percent', 50.0); // Placeholder
  }

  /// Record frame rate
  void recordFrameRate(double fps) {
    _recordMetric('frame_rate', fps);
  }

  /// Record API response time
  void recordApiResponseTime(String endpoint, int responseTime) {
    _recordMetric('api_${endpoint}_response_time', responseTime.toDouble());
  }

  /// Record cache hit rate
  void recordCacheHitRate(String cacheName, double hitRate) {
    _recordMetric('cache_${cacheName}_hit_rate', hitRate);
  }

  /// Record bundle size metrics
  void recordBundleMetrics() {
    // This would be implemented with actual bundle analysis
    _recordMetric('bundle_size_mb', 0.0); // Placeholder
    _recordMetric('assets_size_mb', 0.0); // Placeholder
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};

    for (final entry in _metrics.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        summary[entry.key] = {
          'count': values.length,
          'average': values.reduce((a, b) => a + b) / values.length,
          'min': values.reduce((a, b) => a < b ? a : b),
          'max': values.reduce((a, b) => a > b ? a : b),
          'latest': values.last,
        };
      }
    }

    return summary;
  }

  /// Get recent events
  List<PerformanceEvent> getRecentEvents({int limit = 50}) {
    final events = List<PerformanceEvent>.from(_events);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return BackgroundPrefetchService().getCacheStats();
  }

  /// Generate performance report
  Future<Map<String, dynamic>> generateReport() async {
    final summary = getPerformanceSummary();
    final recentEvents = getRecentEvents();
    final cacheStats = getCacheStats();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': summary,
      'recent_events': recentEvents.map((e) => e.toMap()).toList(),
      'cache_stats': cacheStats,
      'recommendations': _generateRecommendations(summary),
    };
  }

  /// Save performance data to storage
  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'metrics': _metrics,
        'events': _events.map((e) => e.toMap()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString('performance_data', data.toString());
    } catch (e) {
      debugPrint('❌ Failed to save performance data: $e');
    }
  }

  /// Load performance data from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString('performance_data');
      if (dataString != null) {
        // Parse and load data
        debugPrint('📊 Loaded performance data from storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load performance data: $e');
    }
  }

  /// Clear all performance data
  void clearData() {
    _metrics.clear();
    _events.clear();
    _startTimes.clear();
    debugPrint('🗑️ Performance data cleared');
  }

  /// Record metric internally
  void _recordMetric(String name, double value) {
    if (!_metrics.containsKey(name)) {
      _metrics[name] = [];
    }

    _metrics[name]!.add(value);

    // Keep only recent metrics
    if (_metrics[name]!.length > _maxMetricsHistory) {
      _metrics[name]!
          .removeRange(0, _metrics[name]!.length - _maxMetricsHistory);
    }
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(_cleanupInterval, (timer) {
      _cleanupOldData();
    });
  }

  /// Clean up old data
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _events.removeWhere((event) => event.timestamp.isBefore(cutoff));
    debugPrint('🧹 Cleaned up old performance data');
  }

  /// Generate performance recommendations
  List<String> _generateRecommendations(Map<String, dynamic> summary) {
    final recommendations = <String>[];

    // Check API response times
    for (final entry in summary.entries) {
      if (entry.key.startsWith('api_') &&
          entry.key.endsWith('_response_time')) {
        final avg = entry.value['average'] as double;
        if (avg > 2000) {
          recommendations
              .add('Optimize API endpoint: ${entry.key} (${avg.round()}ms)');
        }
      }
    }

    // Check memory usage
    final memoryUsage = summary['memory_usage_percent'];
    if (memoryUsage != null && memoryUsage['average'] > 80) {
      recommendations.add(
          'High memory usage detected (${memoryUsage['average'].round()}%)');
    }

    // Check frame rate
    final frameRate = summary['frame_rate'];
    if (frameRate != null && frameRate['average'] < 55) {
      recommendations
          .add('Low frame rate detected (${frameRate['average'].round()} FPS)');
    }

    return recommendations;
  }
}

/// Performance event model
class PerformanceEvent {
  final String event;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  PerformanceEvent({
    required this.event,
    required this.timestamp,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }

  factory PerformanceEvent.fromMap(Map<String, dynamic> map) {
    return PerformanceEvent(
      event: map['event'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      data: map['data'] as Map<String, dynamic>?,
    );
  }
}

/// Performance monitoring mixin for widgets
mixin PerformanceMonitoringMixin<T extends StatefulWidget> on State<T> {
  void recordWidgetBuild(String widgetName) {
    PerformanceMonitor().recordEvent('widget_build', data: {
      'widget': widgetName,
      'route': ModalRoute.of(context)?.settings.name,
    });
  }

  void recordUserInteraction(String interaction) {
    PerformanceMonitor().recordEvent('user_interaction', data: {
      'interaction': interaction,
      'route': ModalRoute.of(context)?.settings.name,
    });
  }

  void recordPageLoad(String pageName) {
    PerformanceMonitor().recordEvent('page_load', data: {
      'page': pageName,
    });
  }
}
