// services/background_store_data_service.dart
import 'dart:async';
import 'dart:convert';
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
  
    _isRunning = false;
    _preloadTimer?.cancel();
    _preloadTimer = null;
  }

  // Preload store data in background
  static Future<void> _preloadStoreDataInBackground() async {
    try {
      

      // Preload all store data
      final storeData = await DeliveryService.getAllStores();

      if (storeData['success'] == true) {
        _storeDataCache = storeData;
        _lastPreloadTime = DateTime.now();

        // Save to local storage for offline access
        await _saveStoreDataToLocal(storeData);

      } else {

      }
    } catch (e) {
     
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
      
    }
    return null;
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

    }
    return [];
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
