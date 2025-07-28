// services/health_tips_service.dart
import 'dart:convert';
import 'dart:math';
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

  static bool get isCacheValid {
    if (!_hasLoadedOnce || _cachedTips.isEmpty) return false;

    // Check if cache has expired
    if (_lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      return timeSinceLastFetch < _cacheExpiration;
    }

    return false;
  }

  static Future<List<HealthTip>> fetchHealthTips({
    int limit = 6,
    String? category,
    int? age,
    String? gender,
  }) async {
    debugPrint('HealthTipsService: Starting fetchHealthTips');

    // Check cache first for faster loading
    if (isCacheValid) {
      debugPrint('HealthTipsService: Using cached data');
      final result = _cachedTips.take(limit).toList();
      debugPrint('HealthTipsService: Returning ${result.length} cached tips');
      return result;
    }

    try {
      debugPrint('HealthTipsService: Fetching fresh data from API');

      // Build query parameters - use simpler approach that works
      final Map<String, String> queryParams = {};

      // For v3 API, use minimal parameters to get general health tips
      queryParams['Lang'] = 'en';
      // Don't use specific TopicId, Age, or Sex as they often return 0 results
      // The v3 API returns general health topics without specific parameters

      // Build URL with query parameters
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      debugPrint('HealthTipsService: Making request to: $uri');

      final response = await http.get(uri).timeout(Duration(seconds: 15));
      debugPrint('HealthTipsService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
            'HealthTipsService: Response data keys: ${data.keys.toList()}');
        debugPrint('HealthTipsService: Full response data: $data');

        // Add more detailed debugging
        if (data.containsKey('Result')) {
          final result = data['Result'];
          debugPrint('HealthTipsService: Result keys: ${result.keys.toList()}');
          if (result.containsKey('Resources')) {
            final resources = result['Resources'];
            debugPrint(
                'HealthTipsService: Resources keys: ${resources.keys.toList()}');
            if (resources.containsKey('Resource')) {
              final resourceList = resources['Resource'];
              debugPrint(
                  'HealthTipsService: Resource list length: ${resourceList.length}');
              if (resourceList.isNotEmpty) {
                debugPrint(
                    'HealthTipsService: First resource: ${resourceList[0]}');
              }
            }
          }
        }

        try {
          final healthfinderResponse = MyHealthfinderResponse.fromJson(data);
          debugPrint(
              'HealthTipsService: Parsed ${healthfinderResponse.tips.length} tips');

          if (healthfinderResponse.tips.isEmpty) {
            debugPrint(
                'HealthTipsService: No tips parsed, throwing exception to use fallback');
            throw Exception('No tips found in API response');
          }

          // Shuffle the tips for variety
          final shuffledTips = List<HealthTip>.from(healthfinderResponse.tips);
          shuffledTips.shuffle(Random());

          // Cache the shuffled results and mark as loaded
          _cachedTips = shuffledTips;
          _hasLoadedOnce = true;
          _lastFetchTime = DateTime.now();

          final result = _cachedTips.take(limit).toList();
          debugPrint(
              'HealthTipsService: Returning ${result.length} fresh, shuffled tips');
          return result;
        } catch (parseError) {
          debugPrint(
              'HealthTipsService: Error parsing API response: $parseError');

          // Try a simpler parsing approach as fallback
          try {
            debugPrint('HealthTipsService: Trying simpler parsing approach');
            final simpleTips = _parseSimpleResponse(data);
            if (simpleTips.isNotEmpty) {
              debugPrint(
                  'HealthTipsService: Simple parsing successful, got ${simpleTips.length} tips');
              final shuffledTips = List<HealthTip>.from(simpleTips);
              shuffledTips.shuffle(Random());
              _cachedTips = shuffledTips;
              _hasLoadedOnce = true;
              _lastFetchTime = DateTime.now();
              final result = _cachedTips.take(limit).toList();
              return result;
            }
          } catch (simpleError) {
            debugPrint(
                'HealthTipsService: Simple parsing also failed: $simpleError');
          }

          throw Exception('Failed to parse health tips: $parseError');
        }
      } else {
        debugPrint(
            'HealthTipsService: API error - status ${response.statusCode}');
        throw Exception('Failed to load health tips: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('HealthTipsService: Exception caught: $e');
      // Return randomized fallback tips if API fails
      final fallbackTips = _getRandomizedFallbackTips(limit);
      debugPrint(
          'HealthTipsService: Returning ${fallbackTips.length} randomized fallback tips');
      return fallbackTips;
    }
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

  static List<String> _getRandomCategories() {
    return [
      'wellness', // No TopicId - works well
      'prevention', // No TopicId - works well
      'nutrition', // TopicId 311 - may work
      'exercise', // TopicId 312 - may work
      'heart health', // TopicId 305 - may work
      'diabetes', // TopicId 306 - may work
      'mental health', // TopicId 308 - may work
      'pregnancy', // TopicId 309 - may work
      'cancer', // TopicId 307 - may work
      'vaccinations', // TopicId 310 - seems to return 0 results
    ];
  }

  static String _getTopicIdForCategory(String category) {
    // Map categories to MyHealthfinder topic IDs
    switch (category.toLowerCase()) {
      case 'heart health':
      case 'cardiovascular':
        return '305'; // Heart Health
      case 'diabetes':
        return '306'; // Diabetes
      case 'cancer':
        return '307'; // Cancer
      case 'mental health':
        return '308'; // Mental Health
      case 'pregnancy':
      case 'women\'s health':
        return '309'; // Pregnancy
      case 'vaccinations':
      case 'immunizations':
        return '310'; // Immunizations - seems to return 0 results
      case 'nutrition':
      case 'diet':
        return '311'; // Nutrition
      case 'exercise':
      case 'physical activity':
        return '312'; // Physical Activity
      case 'wellness':
      case 'prevention':
      default:
        return ''; // Return all topics - this works best
    }
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
