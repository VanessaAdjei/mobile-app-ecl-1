// services/performance_monitoring_dashboard.dart
// services/performance_monitoring_dashboard.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'universal_page_optimization_service.dart';
import 'advanced_performance_service.dart';

class PerformanceMonitoringDashboard extends StatefulWidget {
  const PerformanceMonitoringDashboard({super.key});

  @override
  PerformanceMonitoringDashboardState createState() =>
      PerformanceMonitoringDashboardState();
}

class PerformanceMonitoringDashboardState
    extends State<PerformanceMonitoringDashboard> {
  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();
  final AdvancedPerformanceService _performanceService =
      AdvancedPerformanceService();

  Map<String, dynamic> _performanceStats = {};
  Map<String, dynamic> _cacheStats = {};
  List<Map<String, dynamic>> _recentEvents = [];
  Timer? _refreshTimer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isVisible) {
        _loadPerformanceData();
      }
    });
  }

  Future<void> _loadPerformanceData() async {
    try {
      final stats = _optimizationService.getPagePerformanceStats();
      final cacheStats = await _getCacheStatistics();
      final events = _performanceService.events
          .take(20)
          .map((event) => {
                'name': event.type,
                'timestamp': event.timestamp.toIso8601String(),
                'data': event.data,
              })
          .toList();

      if (mounted) {
        setState(() {
          _performanceStats = stats;
          _cacheStats = cacheStats;
          _recentEvents = events;
        });
      }
    } catch (e) {
      developer.log('Failed to load performance data: $e',
          name: 'PerformanceDashboard');
    }
  }

  Future<Map<String, dynamic>> _getCacheStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('perf_cache_'))
          .toList();

      int totalCacheEntries = 0;
      int validCacheEntries = 0;
      int expiredCacheEntries = 0;

      for (final key in keys) {
        totalCacheEntries++;
        final timeKey = key.replaceFirst('perf_cache_', 'perf_cache_time_');
        final timestamp = prefs.getInt(timeKey);

        if (timestamp != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final difference = now.difference(cacheTime);

          if (difference.inMinutes < 30) {
            validCacheEntries++;
          } else {
            expiredCacheEntries++;
          }
        }
      }

      return {
        'total_entries': totalCacheEntries,
        'valid_entries': validCacheEntries,
        'expired_entries': expiredCacheEntries,
        'cache_hit_rate': totalCacheEntries > 0
            ? (validCacheEntries / totalCacheEntries * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      return {
        'total_entries': 0,
        'valid_entries': 0,
        'expired_entries': 0,
        'cache_hit_rate': '0.0',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformanceData,
          ),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        setState(() {
          _isVisible = notification.metrics.pixels > 0;
        });
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPerformanceOverview(),
            const SizedBox(height: 24),
            _buildCacheStatistics(),
            const SizedBox(height: 24),
            _buildRecentEvents(),
            const SizedBox(height: 24),
            _buildOptimizationActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Cache Hit Rate',
              '${_performanceStats['cache_hit_rate'] ?? '0.0'}%',
              _getCacheHitRateColor(),
            ),
            _buildMetricRow(
              'Memory Cache Size',
              '${_performanceStats['memory_cache_size'] ?? 0}',
              Colors.blue,
            ),
            _buildMetricRow(
              'Preloaded Images',
              '${_performanceStats['preloaded_images'] ?? 0}',
              Colors.green,
            ),
            _buildMetricRow(
              'Pending Requests',
              '${_performanceStats['pending_requests'] ?? 0}',
              Colors.orange,
            ),
            _buildMetricRow(
              'Avg Response Time',
              '${_performanceStats['avg_response_time'] ?? '0'}ms',
              _getResponseTimeColor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatistics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cache Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Cache Entries',
              '${_cacheStats['total_entries'] ?? 0}',
              Colors.blue,
            ),
            _buildMetricRow(
              'Valid Entries',
              '${_cacheStats['valid_entries'] ?? 0}',
              Colors.green,
            ),
            _buildMetricRow(
              'Expired Entries',
              '${_cacheStats['expired_entries'] ?? 0}',
              Colors.red,
            ),
            _buildMetricRow(
              'Cache Hit Rate',
              '${_cacheStats['cache_hit_rate'] ?? '0.0'}%',
              _getCacheHitRateColor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEvents() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Performance Events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_recentEvents.isEmpty)
              const Text(
                'No recent events',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...(_recentEvents.map((event) => _buildEventItem(event))),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final timestamp = DateTime.parse(event['timestamp']);
    final timeAgo = DateTime.now().difference(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getEventIcon(event['name']),
                size: 16,
                color: _getEventColor(event['name']),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                _formatTimeAgo(timeAgo),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (event['data'] != null) ...[
            const SizedBox(height: 4),
            Text(
              event['data'].toString(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptimizationActions() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optimization Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAllCaches,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All Caches'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshPerformanceData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportPerformanceData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showOptimizationTips,
                    icon: const Icon(Icons.lightbulb),
                    label: const Text('Tips'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCacheHitRateColor() {
    final rate = double.tryParse(
            _performanceStats['cache_hit_rate']?.toString() ?? '0') ??
        0;
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getResponseTimeColor() {
    final time = double.tryParse(
            _performanceStats['avg_response_time']?.toString() ?? '0') ??
        0;
    if (time <= 500) return Colors.green;
    if (time <= 1000) return Colors.orange;
    return Colors.red;
  }

  IconData _getEventIcon(String eventName) {
    switch (eventName) {
      case 'cache_hit':
        return Icons.check_circle;
      case 'cache_miss':
        return Icons.error;
      case 'fetch_error':
        return Icons.warning;
      case 'batch_completed':
        return Icons.done_all;
      case 'timer_stopped':
        return Icons.timer;
      default:
        return Icons.info;
    }
  }

  Color _getEventColor(String eventName) {
    switch (eventName) {
      case 'cache_hit':
        return Colors.green;
      case 'cache_miss':
        return Colors.orange;
      case 'fetch_error':
        return Colors.red;
      case 'batch_completed':
        return Colors.blue;
      case 'timer_stopped':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inSeconds > 0) {
      return '${duration.inSeconds}s ago';
    } else {
      return 'now';
    }
  }

  Future<void> _clearAllCaches() async {
    try {
      await _optimizationService.clearAllPageCaches();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All caches cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPerformanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear caches: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshPerformanceData() async {
    await _loadPerformanceData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance data refreshed'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _exportPerformanceData() async {
    try {
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'performance_stats': _performanceStats,
        'cache_stats': _cacheStats,
        'recent_events': _recentEvents,
      };

      developer.log('Performance Data Export: $data',
          name: 'PerformanceDashboard');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Performance data exported to console'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOptimizationTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Optimization Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯 Cache Hit Rate < 80%:'),
              Text(
                  '• Increase cache duration\n• Preload more data\n• Optimize cache keys'),
              SizedBox(height: 16),
              Text('⏱️ Response Time > 1000ms:'),
              Text(
                  '• Implement request batching\n• Use concurrent loading\n• Optimize API endpoints'),
              SizedBox(height: 16),
              Text('🖼️ Image Loading Issues:'),
              Text(
                  '• Preload critical images\n• Use appropriate sizes\n• Implement lazy loading'),
              SizedBox(height: 16),
              Text('🔄 Frequent Cache Misses:'),
              Text(
                  '• Review cache invalidation\n• Adjust cache duration\n• Monitor cache size'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
