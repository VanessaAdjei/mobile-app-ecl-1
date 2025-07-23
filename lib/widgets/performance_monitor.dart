// widgets/performance_monitor.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/advanced_performance_service.dart';
import '../services/optimized_homepage_service.dart';

class PerformanceMonitor extends StatefulWidget {
  final bool showInDebug;
  final bool showInRelease;

  const PerformanceMonitor({
    super.key,
    this.showInDebug = true,
    this.showInRelease = false,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  Timer? _updateTimer;
  Map<String, dynamic> _performanceStats = {};
  bool _isExpanded = false;

  final AdvancedPerformanceService _performanceService = AdvancedPerformanceService();
  final OptimizedHomepageService _homepageService = OptimizedHomepageService();

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateStats();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  void _updateStats() {
    final performanceStats = _performanceService.getPerformanceStats();
    final homepageStats = _homepageService.getPerformanceStats();

    setState(() {
      _performanceStats = {
        ...performanceStats,
        ...homepageStats,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode unless explicitly enabled for release
    if (!widget.showInDebug && !widget.showInRelease) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: _isExpanded ? 300 : 60,
          constraints: const BoxConstraints(
            maxHeight: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),
              
              // Content
              if (_isExpanded) _buildExpandedContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isExpanded)
            const Text(
              'Performance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            )
          else
            const Icon(
              Icons.speed,
              color: Colors.white,
              size: 20,
            ),
          
          Row(
            children: [
              if (_isExpanded)
                IconButton(
                  onPressed: _updateStats,
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              
              IconButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cache Statistics
          _buildSection(
            'Cache Stats',
            [
              _buildStatItem('Memory Cache', '${_performanceStats['memory_cache_size'] ?? 0}'),
              _buildStatItem('Preloaded Images', '${_performanceStats['preloaded_images'] ?? 0}'),
              _buildStatItem('Pending Requests', '${_performanceStats['pending_requests'] ?? 0}'),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Performance Metrics
          _buildSection(
            'Performance Metrics',
            _buildPerformanceMetrics(),
          ),
          
          const SizedBox(height: 12),
          
          // Event Counts
          if (_performanceStats['event_counts'] != null)
            _buildSection(
              'Events',
              _buildEventCounts(),
            ),
          
          const SizedBox(height: 12),
          
          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPerformanceMetrics() {
    final metrics = <Widget>[];
    
    // Timer metrics
    for (final entry in _performanceStats.entries) {
      if (entry.key.endsWith('_avg') && entry.value != null) {
        final metricName = entry.key.replaceAll('_avg', '');
        final avg = entry.value.toStringAsFixed(1);
        final min = _performanceStats['${metricName}_min']?.toStringAsFixed(1) ?? '0';
        final max = _performanceStats['${metricName}_max']?.toStringAsFixed(1) ?? '0';
        
        metrics.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metricName.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Avg: ${avg}ms',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Min: ${min}ms',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Max: ${max}ms',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return metrics.isEmpty 
        ? [_buildStatItem('No metrics', 'available')]
        : metrics;
  }

  List<Widget> _buildEventCounts() {
    final eventCounts = _performanceStats['event_counts'] as Map<String, dynamic>?;
    if (eventCounts == null) return [_buildStatItem('No events', 'recorded')];
    
    return eventCounts.entries.map((entry) {
      return _buildStatItem(
        entry.key.replaceAll('_', ' ').toUpperCase(),
        entry.value.toString(),
      );
    }).toList();
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await _performanceService.clearAllCaches();
              await _homepageService.clearAllCaches();
              _updateStats();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All caches cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Clear Cache',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await _homepageService.refreshAllData();
                _updateStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data refreshed'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Refresh failed: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// Performance indicator widget for showing quick stats
class PerformanceIndicator extends StatelessWidget {
  final Map<String, dynamic> stats;

  const PerformanceIndicator({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final memoryCacheSize = stats['memory_cache_size'] ?? 0;
    final preloadedImages = stats['preloaded_images'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'C:$memoryCacheSize I:$preloadedImages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
