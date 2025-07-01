// services/banner_cache_service.dart
// services/banner_cache_service.dart
// services/banner_cache_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// Banner model for caching (matching the one used in homepage.dart)
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
      Duration(minutes: 30); // 30 minutes cache

  // In-memory cache
  List<BannerModel> _cachedBanners = [];
  DateTime? _lastCacheTime;
  bool _isLoading = false;

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
  }

  // Load banners with caching
  Future<List<BannerModel>> getBanners({bool forceRefresh = false}) async {
    // Return cached banners if valid and not forcing refresh
    if (isCacheValid && hasCachedBanners && !forceRefresh) {
      return cachedBanners;
    }

    // If already loading, wait for current request
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return cachedBanners;
    }

    // Fetch fresh banners
    return await _fetchBannersFromAPI();
  }

  // Fetch banners from API
  Future<List<BannerModel>> _fetchBannersFromAPI() async {
    _isLoading = true;

    try {
      final response = await http
          .get(
            Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/banner'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List bannersData = data['data'] ?? [];

        final banners = bannersData
            .map<BannerModel>((item) => BannerModel.fromJson(item))
            .toList();

        // Cache the banners
        await _cacheBanners(banners);

        return banners;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your connection.');
    } on http.ClientException {
      throw Exception('No internet connection.');
    } catch (e) {
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
      // Silently handle storage errors
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
      }
    } catch (e) {
      // Silently handle storage errors
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
    };
  }

  // Preload banner images
  Future<void> preloadBannerImages(BuildContext context) async {
    if (_cachedBanners.isEmpty) return;

    // Preload images in background
    for (final banner in _cachedBanners) {
      final imageUrl = _getBannerImageUrl(banner.img);
      if (imageUrl.isNotEmpty) {
        // Use precacheImage for better performance
        precacheImage(NetworkImage(imageUrl), context);
      }
    }
  }

  // Get banner image URL
  String _getBannerImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return 'https://eclcommerce.ernestchemists.com.gh/storage/banners/${Uri.encodeComponent(imagePath)}';
  }

  // Refresh cache
  Future<List<BannerModel>> refreshBanners() async {
    return await getBanners(forceRefresh: true);
  }
}
