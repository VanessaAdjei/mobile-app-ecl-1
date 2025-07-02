// services/banner_cache_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';


class BannerModel {
  final int id;
  final String img;
  final String? urlName;

  BannerModel({required this.id, required this.img, this.urlName});

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      img: json['img'],
      urlName: json['inventory']?['url_name'],
    );
  }
}

class BannerCacheService {
  static final BannerCacheService _instance = BannerCacheService._internal();
  factory BannerCacheService() => _instance;
  BannerCacheService._internal();

  // Cache storage
  static const String _bannerCacheKey = 'banner_cache';
  static const String _bannerCacheTimeKey = 'banner_cache_time';
  static const Duration _cacheValidDuration =
      Duration(hours: 2); // 2 hours cache for better performance

  // In-memory cache
  List<BannerModel> _cachedBanners = [];
  DateTime? _lastCacheTime;
  bool _isLoading = false;

  // Performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _apiCalls = 0;
  DateTime? _lastApiCallTime;

  // Getters
  List<BannerModel> get cachedBanners => List.unmodifiable(_cachedBanners);
  bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  bool get isLoading => _isLoading;
  bool get hasCachedBanners => _cachedBanners.isNotEmpty;

  // Initialize cache service
  Future<void> initialize() async {
    await _loadFromStorage();
    print(
        'BannerCacheService initialized with ${_cachedBanners.length} cached banners');
  }

  // Load banners with caching
  Future<List<BannerModel>> getBanners({bool forceRefresh = false}) async {
    // Return cached banners if valid and not forcing refresh
    if (isCacheValid && hasCachedBanners && !forceRefresh) {
      _cacheHits++;
      print(
          'Banner cache hit: ${_cachedBanners.length} banners returned from cache');
      return cachedBanners;
    }

    // If we have cached banners but they're expired, return them immediately
    // and refresh in background for better UX
    if (hasCachedBanners && !forceRefresh) {
      _cacheHits++;
      print(
          'Banner cache expired but returning cached data while refreshing in background');

      // Refresh in background without blocking
      _refreshInBackground();

      return cachedBanners;
    }

    _cacheMisses++;

    // If already loading, wait for current request
    if (_isLoading) {
      print('Banner request already in progress, waiting...');
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return cachedBanners;
    }

    // Fetch fresh banners
    return await _fetchBannersFromAPI();
  }

  // Refresh cache in background without blocking UI
  Future<void> _refreshInBackground() async {
    if (_isLoading) return; // Don't start multiple refreshes

    try {
      await _fetchBannersFromAPI();
    } catch (e) {
      print('Background banner refresh failed: $e');
      // Keep using old cache data
    }
  }

  // Fetch banners from API
  Future<List<BannerModel>> _fetchBannersFromAPI() async {
    _isLoading = true;
    _apiCalls++;
    _lastApiCallTime = DateTime.now();

    try {
      print('Fetching banners from API...');
      final stopwatch = Stopwatch()..start();

      final response = await http
          .get(
            Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/banner'),
          )
          .timeout(const Duration(seconds: 15));

      stopwatch.stop();
      print('Banner API call completed in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List bannersData = data['data'] ?? [];

        final banners = bannersData
            .map<BannerModel>((item) => BannerModel.fromJson(item))
            .toList();

        print('Successfully fetched ${banners.length} banners from API');

        // Cache the banners
        await _cacheBanners(banners);

        return banners;
      } else {
        print('Banner API error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      print('Banner API timeout');
      throw Exception('Request timeout. Please check your connection.');
    } on http.ClientException {
      print('Banner API client error - no internet connection');
      throw Exception('No internet connection.');
    } catch (e) {
      print('Banner API error: $e');
      throw Exception('Failed to load banners: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Cache banners in memory and storage
  Future<void> _cacheBanners(List<BannerModel> banners) async {
    _cachedBanners = banners;
    _lastCacheTime = DateTime.now();

    // Save to persistent storage
    await _saveToStorage();
    print('Banners cached successfully: ${banners.length} banners');
  }

  // Save banners to persistent storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert banners to JSON
      final bannersJson = _cachedBanners
          .map((banner) => {
                'id': banner.id,
                'img': banner.img,
                'urlName': banner.urlName,
              })
          .toList();

      await prefs.setString(_bannerCacheKey, json.encode(bannersJson));
      await prefs.setString(
          _bannerCacheTimeKey, _lastCacheTime!.toIso8601String());
    } catch (e) {
      print('Failed to save banner cache: $e');
    }
  }

  // Load banners from persistent storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bannersJson = prefs.getString(_bannerCacheKey);
      final cacheTimeString = prefs.getString(_bannerCacheTimeKey);

      if (bannersJson != null && cacheTimeString != null) {
        final bannersData = json.decode(bannersJson) as List;
        final cacheTime = DateTime.parse(cacheTimeString);

        _cachedBanners = bannersData
            .map<BannerModel>((item) => BannerModel.fromJson(item))
            .toList();
        _lastCacheTime = cacheTime;

        print('Loaded ${_cachedBanners.length} banners from storage cache');
      }
    } catch (e) {
      print('Failed to load banner cache: $e');
      _cachedBanners = [];
      _lastCacheTime = null;
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    _cachedBanners.clear();
    _lastCacheTime = null;
    _isLoading = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bannerCacheKey);
      await prefs.remove(_bannerCacheTimeKey);
      print('Banner cache cleared successfully');
    } catch (e) {
      print('Failed to clear banner cache: $e');
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'banner_count': _cachedBanners.length,
      'is_cache_valid': isCacheValid,
      'last_cache_time': _lastCacheTime?.toIso8601String(),
      'is_loading': _isLoading,
      'cache_duration_minutes': _cacheValidDuration.inMinutes,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'api_calls': _apiCalls,
      'last_api_call': _lastApiCallTime?.toIso8601String(),
      'cache_hit_rate': _cacheHits + _cacheMisses > 0
          ? (_cacheHits / (_cacheHits + _cacheMisses) * 100)
                  .toStringAsFixed(1) +
              '%'
          : '0%',
    };
  }

  // Preload banner images with optimization
  Future<void> preloadBannerImages(BuildContext context) async {
    if (_cachedBanners.isEmpty) return;

    print('Preloading ${_cachedBanners.length} banner images...');

    // Preload images in background with optimized settings
    for (final banner in _cachedBanners) {
      final imageUrl = _getBannerImageUrl(banner.img);
      if (imageUrl.isNotEmpty) {
        try {
          // Use precacheImage without size constraints for better quality
          precacheImage(
            NetworkImage(imageUrl),
            context,
          );
        } catch (e) {
          print('Failed to preload banner image: $imageUrl - $e');
        }
      }
    }

    print('Banner image preloading completed');
  }

  // Get banner image URL with optimization
  String _getBannerImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return 'https://eclcommerce.ernestchemists.com.gh/storage/banners/${Uri.encodeComponent(imagePath)}';
  }

  // Refresh cache
  Future<List<BannerModel>> refreshBanners() async {
    print('Forcing banner cache refresh...');
    return await getBanners(forceRefresh: true);
  }

  // Print performance summary
  void printPerformanceSummary() {
    final stats = getCacheStats();
    print('=== Banner Cache Performance Summary ===');
    print('Cache Hits: ${stats['cache_hits']}');
    print('Cache Misses: ${stats['cache_misses']}');
    print('API Calls: ${stats['api_calls']}');
    print('Cache Hit Rate: ${stats['cache_hit_rate']}');
    print('Cached Banners: ${stats['banner_count']}');
    print('Cache Valid: ${stats['is_cache_valid']}');
    print('Cache Duration: ${_cacheValidDuration.inHours} hours');
    print('========================================');
  }

  // Check if cache is working efficiently
  bool get isCacheWorkingEfficiently {
    final totalRequests = _cacheHits + _cacheMisses;
    if (totalRequests == 0) return true;
    return (_cacheHits / totalRequests) > 0.7; // 70% hit rate is good
  }

  // Get cache efficiency percentage
  double get cacheEfficiencyPercentage {
    final totalRequests = _cacheHits + _cacheMisses;
    if (totalRequests == 0) return 100.0;
    return (_cacheHits / totalRequests) * 100;
  }
}
