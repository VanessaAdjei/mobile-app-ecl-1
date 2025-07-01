// widgets/performance_monitor.dart
// widgets/performance_monitor.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/app_optimization_service.dart';

class PerformanceMonitor extends StatefulWidget {
  final bool showInRelease;
  final bool showCacheStats;
  final bool showMetrics;

  const PerformanceMonitor({
    super.key,
    this.showInRelease = false,
    this.showCacheStats = true,
    this.showMetrics = true,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isExpanded = false;
  Map<String, dynamic> _cacheStats = {};
  List<PerformanceMetric> _metrics = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _updateData();
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateData();
      }
    });
  }

  void _updateData() {
    final optimizationService = AppOptimizationService();

    setState(() {
      _cacheStats = optimizationService.getCacheStats();
      _metrics = optimizationService.getPerformanceMetrics();
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode unless explicitly enabled for release
    if (!kDebugMode && !widget.showInRelease) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: _isExpanded ? 300 : 50,
          constraints: BoxConstraints(
            maxHeight: _isExpanded ? 400 : 50,
          ),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),

              // Expanded content
              if (_isExpanded) ...[
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showCacheStats) _buildCacheStats(),
                        if (widget.showCacheStats && widget.showMetrics)
                          const Divider(color: Colors.white24, height: 16),
                        if (widget.showMetrics) _buildMetrics(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: Colors.green,
            size: 20,
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Performance Monitor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          IconButton(
            onPressed: _toggleExpanded,
            icon: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cache Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatRow(
            'API Cache Size', '${_cacheStats['api_cache_size'] ?? 0}'),
        _buildStatRow(
            'Max API Cache', '${_cacheStats['max_api_cache_size'] ?? 0}'),
        _buildStatRow('Metrics Count', '${_cacheStats['metrics_count'] ?? 0}'),
        _buildStatRow('Max Metrics', '${_cacheStats['max_metrics_size'] ?? 0}'),
        _buildStatRow(
            'Backgrounded', '${_cacheStats['is_backgrounded'] ?? false}'),
        _buildStatRow('Low Memory', '${_cacheStats['is_low_memory'] ?? false}'),
      ],
    );
  }

  Widget _buildMetrics() {
    if (_metrics.isEmpty) {
      return Text(
        'No performance metrics available',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      );
    }

    // Get recent metrics (last 10)
    final recentMetrics = _metrics
        .where((metric) =>
            DateTime.now().difference(metric.timestamp) <
            const Duration(minutes: 5))
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Performance Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...recentMetrics.map((metric) => _buildMetricRow(metric)),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(PerformanceMetric metric) {
    final duration = metric.duration;
    final color = duration < 100
        ? Colors.green
        : duration < 500
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              metric.name,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${duration}ms',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple performance monitor overlay
class PerformanceMonitorOverlay extends StatelessWidget {
  final Widget child;
  final bool showInRelease;

  const PerformanceMonitorOverlay({
    super.key,
    required this.child,
    this.showInRelease = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const PerformanceMonitor(),
      ],
    );
  }
}
