// services/health_tips_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/health_tip.dart';
import 'package:flutter/foundation.dart';

class HealthTipsService {
  static const String _baseUrl =
      'https://health.gov/myhealthfinder/api/v4/topicsearch.json';

  // Enhanced cache for health tips with time-based expiration
  static List<HealthTip> _cachedTips = [];
  static bool _hasLoadedOnce = false;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiration =
      Duration(minutes: 30); // Cache for 30 minutes

  // Background service properties
  static Timer? _backgroundTimer;
  static bool _isBackgroundServiceRunning = false;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 10);
  static const Duration _initialLoadDelay = Duration(seconds: 5);

  // Background service management
  static void startBackgroundService() {
    if (_isBackgroundServiceRunning) return;

    debugPrint('HealthTipsService: Starting background service');
    _isBackgroundServiceRunning = true;

    // Initial load after a short delay
    Timer(_initialLoadDelay, () {
      _loadTipsInBackground();
    });

    // Set up periodic background refresh
    _backgroundTimer = Timer.periodic(_backgroundRefreshInterval, (timer) {
      _loadTipsInBackground();
    });
  }

  static void stopBackgroundService() {
    debugPrint('HealthTipsService: Stopping background service');
    _isBackgroundServiceRunning = false;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  static Future<void> _loadTipsInBackground() async {
    try {
      debugPrint('HealthTipsService: Background refresh started');

      final tips = await _fetchTipsFromAPI();
      if (tips.isNotEmpty) {
        _cachedTips = tips;
        _hasLoadedOnce = true;
        _lastFetchTime = DateTime.now();
        debugPrint(
            'HealthTipsService: Background refresh successful - ${tips.length} tips cached');
      }
    } catch (e) {
      debugPrint('HealthTipsService: Background refresh failed: $e');
    }
  }

  static Future<List<HealthTip>> _fetchTipsFromAPI() async {
    try {
      final Map<String, String> queryParams = {'Lang': 'en'};
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        try {
          final healthfinderResponse = MyHealthfinderResponse.fromJson(data);
          if (healthfinderResponse.tips.isNotEmpty) {
            final shuffledTips =
                List<HealthTip>.from(healthfinderResponse.tips);
            shuffledTips.shuffle(Random());
            return shuffledTips;
          }
        } catch (parseError) {
          debugPrint(
              'HealthTipsService: Error parsing API response: $parseError');

          // Try simpler parsing as fallback
          final simpleTips = _parseSimpleResponse(data);
          if (simpleTips.isNotEmpty) {
            final shuffledTips = List<HealthTip>.from(simpleTips);
            shuffledTips.shuffle(Random());
            return shuffledTips;
          }
        }
      }
    } catch (e) {
      debugPrint('HealthTipsService: API fetch error: $e');
    }

    return [];
  }

  static bool get isCacheValid {
    if (!_hasLoadedOnce || _cachedTips.isEmpty) return false;

    // Check if cache has expired
    if (_lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      return timeSinceLastFetch < _cacheExpiration;
    }

    return false;
  }

  // Get current cached tips for instant access
  static List<HealthTip> getCurrentTips({int limit = 6}) {
    if (isCacheValid) {
      return _cachedTips.take(limit).toList();
    }
    return [];
  }

  // Check if background service is running
  static bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;

  static Future<List<HealthTip>> fetchHealthTips({
    int limit = 6,
    String? category,
    int? age,
    String? gender,
  }) async {
    debugPrint('HealthTipsService: Starting fetchHealthTips');

    // Start background service if not running
    if (!_isBackgroundServiceRunning) {
      startBackgroundService();
    }

    // Check cache first for instant response
    if (isCacheValid) {
      debugPrint('HealthTipsService: Using cached data');
      final result = _cachedTips.take(limit).toList();
      debugPrint(
          'HealthTipsService: Returning ${result.length} cached tips instantly');
      return result;
    }

    // If no cache, try to fetch immediately but with shorter timeout
    try {
      debugPrint('HealthTipsService: Cache miss, fetching fresh data');
      final tips = await _fetchTipsFromAPI().timeout(Duration(seconds: 4));

      if (tips.isNotEmpty) {
        _cachedTips = tips;
        _hasLoadedOnce = true;
        _lastFetchTime = DateTime.now();

        final result = _cachedTips.take(limit).toList();
        debugPrint('HealthTipsService: Returning ${result.length} fresh tips');
        return result;
      }
    } catch (e) {
      debugPrint('HealthTipsService: Immediate fetch failed: $e');
    }

    // Return fallback tips if everything fails
    debugPrint('HealthTipsService: Using fallback tips');
    final fallbackTips = _getRandomizedFallbackTips(limit);
    return fallbackTips;
  }

  static List<HealthTip> _parseSimpleResponse(Map<String, dynamic> data) {
    final List<HealthTip> tips = [];

    try {
      // Try different possible response structures
      if (data.containsKey('Result')) {
        final result = data['Result'];
        if (result is Map<String, dynamic>) {
          if (result.containsKey('Resources')) {
            final resources = result['Resources'];
            if (resources is Map<String, dynamic> &&
                resources.containsKey('Resource')) {
              final resourceList = resources['Resource'];
              if (resourceList is List) {
                for (final item in resourceList) {
                  if (item is Map<String, dynamic>) {
                    try {
                      final tip = HealthTip.fromJson(item);
                      tips.add(tip);
                    } catch (e) {
                      debugPrint(
                          'HealthTipsService: Error parsing individual tip: $e');
                    }
                  }
                }
              }
            }
          }
        }
      }

      // If no tips found, try alternative structure
      if (tips.isEmpty && data.containsKey('Resource')) {
        final resourceList = data['Resource'];
        if (resourceList is List) {
          for (final item in resourceList) {
            if (item is Map<String, dynamic>) {
              try {
                final tip = HealthTip.fromJson(item);
                tips.add(tip);
              } catch (e) {
                debugPrint(
                    'HealthTipsService: Error parsing individual tip (alt): $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('HealthTipsService: Error in simple parsing: $e');
    }

    return tips;
  }

  static List<HealthTip> _getRandomizedFallbackTips(int limit) {
    final allFallbackTips = [
      HealthTip(
        title: 'Stay Hydrated',
        url: '',
        content:
            'Drink 8 glasses of water daily for better health and hydration.',
        category: 'Wellness',
        summary:
            'Proper hydration helps maintain body temperature, lubricate joints, and transport nutrients throughout your body.',
      ),
      HealthTip(
        title: 'Exercise Regularly',
        url: '',
        content: '30 minutes of daily exercise keeps you fit and healthy.',
        category: 'Physical Activity',
        summary:
            'Regular physical activity strengthens your heart, improves mood, and helps maintain a healthy weight.',
      ),
      HealthTip(
        title: 'Get Enough Sleep',
        url: '',
        content:
            '7-8 hours of sleep is essential for overall health and well-being.',
        category: 'Wellness',
        summary:
            'Quality sleep supports immune function, memory consolidation, and overall physical and mental recovery.',
      ),
      HealthTip(
        title: 'Eat Healthy',
        url: '',
        content:
            'Include fruits and vegetables in your daily diet for better nutrition.',
        category: 'Nutrition',
        summary:
            'A balanced diet rich in fruits, vegetables, and whole grains provides essential nutrients for optimal health.',
      ),
      HealthTip(
        title: 'Wash Hands Regularly',
        url: '',
        content:
            'Regular hand washing prevents infections and keeps you healthy.',
        category: 'Prevention',
        summary:
            'Proper hand hygiene is one of the most effective ways to prevent the spread of germs and infections.',
      ),
      HealthTip(
        title: 'Take Breaks from Screens',
        url: '',
        content:
            'Take regular breaks from screen time to protect your eyes and mental health.',
        category: 'Wellness',
        summary:
            'Regular breaks from digital devices help reduce eye strain, improve posture, and maintain mental well-being.',
      ),
      HealthTip(
        title: 'Practice Mindfulness',
        url: '',
        content:
            'Take time to meditate or practice mindfulness for better mental health.',
        category: 'Mental Health',
        summary:
            'Mindfulness practices help reduce stress, improve focus, and enhance overall emotional well-being.',
      ),
      HealthTip(
        title: 'Limit Sugar Intake',
        url: '',
        content:
            'Reduce added sugars in your diet to maintain healthy blood sugar levels.',
        category: 'Nutrition',
        summary:
            'Reducing added sugars helps prevent weight gain, diabetes, and other chronic health conditions.',
      ),
      HealthTip(
        title: 'Get Regular Check-ups',
        url: '',
        content: 'Schedule regular health check-ups to catch issues early.',
        category: 'Prevention',
        summary:
            'Regular preventive care helps detect health issues early when they are most treatable.',
      ),
      HealthTip(
        title: 'Practice Good Posture',
        url: '',
        content: 'Maintain good posture to prevent back and neck problems.',
        category: 'Wellness',
        summary:
            'Good posture reduces strain on muscles and joints, preventing chronic pain and improving breathing.',
      ),
      HealthTip(
        title: 'Stay Socially Connected',
        url: '',
        content:
            'Maintain social connections for better mental and emotional health.',
        category: 'Mental Health',
        summary:
            'Strong social connections improve mental health, reduce stress, and increase life satisfaction.',
      ),
      HealthTip(
        title: 'Use Sunscreen Daily',
        url: '',
        content:
            'Apply sunscreen with SPF 30+ daily to protect your skin from UV damage.',
        category: 'Prevention',
        summary:
            'Daily sunscreen use prevents skin cancer, premature aging, and protects against harmful UV radiation.',
      ),
    ];

    // Shuffle the fallback tips for variety
    final shuffledTips = List<HealthTip>.from(allFallbackTips);
    shuffledTips.shuffle(Random());

    return shuffledTips.take(limit).toList();
  }

  static void clearCache() {
    _cachedTips.clear();
    _hasLoadedOnce = false;
  }
}
