// widgets/performance_monitor_widget.dart
// widgets/performance_monitor_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/universal_page_optimization_service.dart';
import '../services/performance_monitoring_dashboard.dart';

class PerformanceMonitorWidget extends StatefulWidget {
  final bool showDetailed;
  final VoidCallback? onTap;

  const PerformanceMonitorWidget({
    super.key,
    this.showDetailed = false,
    this.onTap,
  });

  @override
  _PerformanceMonitorWidgetState createState() =>
      _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget> {
  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();
  Map<String, dynamic> _performanceStats = {};
  Timer? _refreshTimer;

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadPerformanceData();
    });
  }

  Future<void> _loadPerformanceData() async {
    try {
      final stats = _optimizationService.getPagePerformanceStats();
      if (mounted) {
        setState(() {
          _performanceStats = stats;
        });
      }
    } catch (e) {
      // Silently handle errors for the widget
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDetailed) {
      return _buildCompactWidget();
    }
    return _buildDetailedWidget();
  }

  Widget _buildCompactWidget() {
    final cacheHitRate = double.tryParse(
            _performanceStats['cache_hit_rate']?.toString() ?? '0') ??
        0;
    final responseTime = double.tryParse(
            _performanceStats['avg_response_time']?.toString() ?? '0') ??
        0;

    return GestureDetector(
      onTap: widget.onTap ?? () => _openPerformanceDashboard(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed,
              size: 16,
              color: _getPerformanceColor(cacheHitRate, responseTime),
            ),
            const SizedBox(width: 4),
            Text(
              '${cacheHitRate.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${responseTime.toStringAsFixed(0)}ms',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedWidget() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _openPerformanceDashboard(),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMetricRow('Cache Hit Rate',
                '${_performanceStats['cache_hit_rate'] ?? '0.0'}%'),
            _buildMetricRow('Response Time',
                '${_performanceStats['avg_response_time'] ?? '0'}ms'),
            _buildMetricRow('Memory Cache',
                '${_performanceStats['memory_cache_size'] ?? 0}'),
            _buildMetricRow('Preloaded Images',
                '${_performanceStats['preloaded_images'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double cacheHitRate, double responseTime) {
    if (cacheHitRate >= 80 && responseTime <= 500) return Colors.green;
    if (cacheHitRate >= 60 && responseTime <= 1000) return Colors.orange;
    return Colors.red;
  }

  void _openPerformanceDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PerformanceMonitoringDashboard(),
      ),
    );
  }
}

// Floating performance monitor that can be added to any page
class FloatingPerformanceMonitor extends StatelessWidget {
  final bool showDetailed;

  const FloatingPerformanceMonitor({
    super.key,
    this.showDetailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      right: 16,
      child: PerformanceMonitorWidget(
        showDetailed: showDetailed,
      ),
    );
  }
}
