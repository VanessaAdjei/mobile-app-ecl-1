// services/background_store_data_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'delivery_service.dart';

class BackgroundStoreDataService {
  static Timer? _preloadTimer;
  static bool _isRunning = false;
  static const Duration _preloadInterval = Duration(hours: 2);
  static const Duration _initialDelay = Duration(seconds: 120);

  // Cache for store data
  static Map<String, dynamic>? _storeDataCache;
  static DateTime? _lastPreloadTime;
  static const Duration _cacheExpiration = Duration(hours: 4);

  // Start background store data preloading
  static void startBackgroundPreloading() {
    if (_isRunning) return;

    debugPrint(
        '🏪 BackgroundStoreDataService: Starting background store data preloading');
    _isRunning = true;

    // Initial preload after delay
    Timer(_initialDelay, () {
      _preloadStoreDataInBackground();
    });

    // Set up periodic preload
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) {
      _preloadStoreDataInBackground();
    });
  }

  // Stop background preloading
  static void stopBackgroundPreloading() {
    debugPrint(
        '🏪 BackgroundStoreDataService: Stopping background store data preloading');
    _isRunning = false;
    _preloadTimer?.cancel();
    _preloadTimer = null;
  }

  // Preload store data in background
  static Future<void> _preloadStoreDataInBackground() async {
    try {
      debugPrint(
          '🏪 BackgroundStoreDataService: Starting background store data preload');

      // Preload all store data
      final storeData = await DeliveryService.getAllStores();

      if (storeData['success'] == true) {
        _storeDataCache = storeData;
        _lastPreloadTime = DateTime.now();

        // Save to local storage for offline access
        await _saveStoreDataToLocal(storeData);

        debugPrint(
            '🏪 BackgroundStoreDataService: Store data preloaded successfully - ${storeData['data']?.length ?? 0} stores');
      } else {
        debugPrint(
            '🏪 BackgroundStoreDataService: Failed to preload store data');
      }
    } catch (e) {
      debugPrint('🏪 BackgroundStoreDataService: Background preload error: $e');
    }
  }

  // Save store data to local storage
  static Future<void> _saveStoreDataToLocal(
      Map<String, dynamic> storeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_store_data', json.encode(storeData));
      await prefs.setString(
          'store_data_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error saving store data to local: $e');
    }
  }

  // Get cached store data
  static Future<Map<String, dynamic>?> getCachedStoreData() async {
    try {
      // Check if cache is valid
      if (_storeDataCache != null && _lastPreloadTime != null) {
        final timeSinceLastPreload =
            DateTime.now().difference(_lastPreloadTime!);
        if (timeSinceLastPreload < _cacheExpiration) {
          return _storeDataCache;
        }
      }

      // Try to load from local storage
      final prefs = await SharedPreferences.getInstance();
      final cachedDataJson = prefs.getString('cached_store_data');
      final timestampStr = prefs.getString('store_data_timestamp');

      if (cachedDataJson != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final timeSinceLastCache = DateTime.now().difference(timestamp);

        if (timeSinceLastCache < _cacheExpiration) {
          final cachedData =
              json.decode(cachedDataJson) as Map<String, dynamic>;
          _storeDataCache = cachedData;
          _lastPreloadTime = timestamp;
          return cachedData;
        }
      }
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error getting cached store data: $e');
    }
    return null;
  }

  // Preload popular store locations
  static Future<void> _preloadPopularStores() async {
    try {
      final storeData = await getCachedStoreData();
      if (storeData == null) return;

      final stores = storeData['data'] as List;
      final popularStores = <Map<String, dynamic>>[];

      // Identify popular stores (e.g., by region, city, or activity)
      for (final store in stores) {
        final region = store['region_name']?.toString() ?? '';
        final city = store['city_name']?.toString() ?? '';

        // Consider stores in major cities as popular
        if (_isPopularLocation(region, city)) {
          popularStores.add(store);
        }
      }

      // Cache popular stores separately for faster access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('popular_stores', json.encode(popularStores));

      debugPrint(
          '🏪 BackgroundStoreDataService: Preloaded ${popularStores.length} popular stores');
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error preloading popular stores: $e');
    }
  }

  // Check if location is popular
  static bool _isPopularLocation(String region, String city) {
    final popularCities = [
      'Accra',
      'Kumasi',
      'Tamale',
      'Sekondi-Takoradi',
      'Ashaiman',
      'Sunyani',
      'Cape Coast',
      'Obuasi',
      'Tema',
      'Koforidua'
    ];

    final popularRegions = [
      'Greater Accra',
      'Ashanti',
      'Northern',
      'Western',
      'Central',
      'Eastern',
      'Volta',
      'Upper East',
      'Upper West'
    ];

    return popularCities.contains(city) || popularRegions.contains(region);
  }

  // Get popular stores for quick access
  static Future<List<Map<String, dynamic>>> getPopularStores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final popularStoresJson = prefs.getString('popular_stores');

      if (popularStoresJson != null) {
        final stores = json.decode(popularStoresJson) as List;
        return stores.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error getting popular stores: $e');
    }
    return [];
  }

  // Preload store data for specific region
  static Future<void> _preloadRegionStores(String regionName) async {
    try {
      final storeData = await getCachedStoreData();
      if (storeData == null) return;

      final stores = storeData['data'] as List;
      final regionStores = stores
          .where((store) => store['region_name']?.toString() == regionName)
          .toList();

      // Cache region stores
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'region_stores_$regionName', json.encode(regionStores));

      debugPrint(
          '🏪 BackgroundStoreDataService: Preloaded ${regionStores.length} stores for $regionName');
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error preloading region stores: $e');
    }
  }

  // Get stores for specific region
  static Future<List<Map<String, dynamic>>> getRegionStores(
      String regionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regionStoresJson = prefs.getString('region_stores_$regionName');

      if (regionStoresJson != null) {
        final stores = json.decode(regionStoresJson) as List;
        return stores.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint(
          '🏪 BackgroundStoreDataService: Error getting region stores: $e');
    }
    return [];
  }

  // Get service status
  static bool get isRunning => _isRunning;
  static DateTime? get lastPreloadTime => _lastPreloadTime;
  static bool get isCacheValid {
    if (_lastPreloadTime == null) return false;
    final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
    return timeSinceLastPreload < _cacheExpiration;
  }
}
