// services/background_store_data_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_location_model.dart';
import 'delivery_service.dart';

class StoreSelectionSnapshot {
  const StoreSelectionSnapshot({
    required this.regions,
    required this.stores,
    required this.fetchedAt,
  });

  final List<Map<String, dynamic>> regions;
  final List<Map<String, dynamic>> stores;
  final DateTime fetchedAt;
}

class BackgroundStoreDataService {
  BackgroundStoreDataService._();

  static Timer? _preloadTimer;
  static bool _isRunning = false;
  static bool _selectionFetchInFlight = false;
  static const Duration _preloadInterval = Duration(hours: 2);
  static const Duration _initialDelay = Duration(seconds: 20);
  static const Duration _cacheExpiration = Duration(hours: 4);
  static const Duration _selectionCacheExpiration = Duration(hours: 12);

  static const _selectionRegionsKey = 'store_selection_regions_v1';
  static const _selectionStoresKey = 'store_selection_stores_v1';
  static const _selectionTimestampKey = 'store_selection_timestamp_v1';

  static const _allowedRegionNames = [
    'greater accra',
    'ashanti',
    'western',
    'accra',
  ];

  static Map<String, dynamic>? _storeDataCache;
  static DateTime? _lastPreloadTime;
  static StoreSelectionSnapshot? _selectionMemoryCache;

  static void startBackgroundPreloading() {
    if (_isRunning) return;
    _isRunning = true;

    Timer(_initialDelay, () {
      unawaited(warmStoreSelectionCache());
    });

    _preloadTimer = Timer.periodic(_preloadInterval, (timer) {
      unawaited(warmStoreSelectionCache());
    });
  }

  static void stopBackgroundPreloading() {
    _isRunning = false;
    _preloadTimer?.cancel();
    _preloadTimer = null;
  }

  /// Prefetch store list when user opens contact / locator flows.
  static Future<void> warmStoreSelectionCache({bool forceRefresh = false}) async {
    if (_selectionFetchInFlight) return;
    if (!forceRefresh) {
      final cached = await readStoreSelectionSnapshot();
      if (cached != null) return;
    }
    await fetchStoreSelectionSnapshot(forceRefresh: forceRefresh);
  }

  static Future<StoreSelectionSnapshot?> readStoreSelectionSnapshot() async {
    if (_selectionMemoryCache != null) {
      final age = DateTime.now().difference(_selectionMemoryCache!.fetchedAt);
      if (age < _selectionCacheExpiration) {
        return _selectionMemoryCache;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final regionsJson = prefs.getString(_selectionRegionsKey);
      final storesJson = prefs.getString(_selectionStoresKey);
      final timestampStr = prefs.getString(_selectionTimestampKey);

      if (regionsJson == null || storesJson == null || timestampStr == null) {
        return null;
      }

      final fetchedAt = DateTime.tryParse(timestampStr);
      if (fetchedAt == null) return null;
      if (DateTime.now().difference(fetchedAt) >= _selectionCacheExpiration) {
        return null;
      }

      final regions = (json.decode(regionsJson) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final stores = (json.decode(storesJson) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final snapshot = StoreSelectionSnapshot(
        regions: regions,
        stores: stores,
        fetchedAt: fetchedAt,
      );
      _selectionMemoryCache = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  static Future<StoreSelectionSnapshot?> fetchStoreSelectionSnapshot({
    bool forceRefresh = false,
  }) async {
    if (_selectionFetchInFlight) {
      return readStoreSelectionSnapshot();
    }

    if (!forceRefresh) {
      final cached = await readStoreSelectionSnapshot();
      if (cached != null) return cached;
    }

    _selectionFetchInFlight = true;
    try {
      final regionsResult = await DeliveryService.getRegions();
      if (regionsResult['success'] != true) {
        return null;
      }

      final regionsData = regionsResult['data'] ?? [];
      final filteredRegions = _filterAllowedRegions(regionsData);
      if (filteredRegions.isEmpty) return null;

      final dedupedRegions = _dedupeLocationOptions(filteredRegions);
      final stores = await _fetchStoresForRegions(filteredRegions);
      if (stores.isEmpty) return null;

      final snapshot = StoreSelectionSnapshot(
        regions: dedupedRegions,
        stores: stores,
        fetchedAt: DateTime.now(),
      );

      _selectionMemoryCache = snapshot;
      await _saveStoreSelectionSnapshot(snapshot);
      await _saveLegacyStoreDataCache(stores);
      return snapshot;
    } catch (_) {
      return null;
    } finally {
      _selectionFetchInFlight = false;
    }
  }

  static Future<void> _saveStoreSelectionSnapshot(
    StoreSelectionSnapshot snapshot,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectionRegionsKey, json.encode(snapshot.regions));
      await prefs.setString(_selectionStoresKey, json.encode(snapshot.stores));
      await prefs.setString(
        _selectionTimestampKey,
        snapshot.fetchedAt.toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<void> _saveLegacyStoreDataCache(
    List<Map<String, dynamic>> stores,
  ) async {
    try {
      final storeData = {
        'success': true,
        'data': stores,
      };
      _storeDataCache = storeData;
      _lastPreloadTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_store_data', json.encode(storeData));
      await prefs.setString(
        'store_data_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getCachedStoreData() async {
    try {
      if (_storeDataCache != null && _lastPreloadTime != null) {
        final timeSinceLastPreload =
            DateTime.now().difference(_lastPreloadTime!);
        if (timeSinceLastPreload < _cacheExpiration) {
          return _storeDataCache;
        }
      }

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
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getPopularStores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final popularStoresJson = prefs.getString('popular_stores');

      if (popularStoresJson != null) {
        final stores = json.decode(popularStoresJson) as List;
        return stores.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getRegionStores(
    String regionName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regionStoresJson = prefs.getString('region_stores_$regionName');

      if (regionStoresJson != null) {
        final stores = json.decode(regionStoresJson) as List;
        return stores.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static bool get isRunning => _isRunning;
  static DateTime? get lastPreloadTime => _lastPreloadTime;
  static bool get isCacheValid {
    if (_lastPreloadTime == null) return false;
    final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
    return timeSinceLastPreload < _cacheExpiration;
  }

  static List<dynamic> _filterAllowedRegions(List<dynamic> regionsData) {
    return regionsData.where((region) {
      final regionName =
          (region['description'] ?? '').toString().toLowerCase().trim();
      return _allowedRegionNames.any((allowed) => regionName.contains(allowed));
    }).toList();
  }

  static List<Map<String, dynamic>> _dedupeLocationOptions(
    List<dynamic> rows,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final label =
          (map['description'] ?? map['name'] ?? '').toString().trim();
      if (label.isEmpty) continue;
      final id = map['id']?.toString() ?? label;
      if (!seen.add(id)) continue;
      map['description'] = label;
      out.add(map);
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> _fetchStoresForRegions(
    List<dynamic> filteredRegions,
  ) async {
    final cityFutures = <Future<Map<String, dynamic>>>[];
    for (final region in filteredRegions) {
      final regionId = int.tryParse(region['id'].toString()) ?? 0;
      cityFutures.add(DeliveryService.getCitiesByRegion(regionId));
    }

    final cityResults = await Future.wait(cityFutures);
    final storeFutures = <Future<Map<String, dynamic>>>[];
    final cityInfo = <int, Map<String, String>>{};

    for (var i = 0; i < cityResults.length; i++) {
      if (cityResults[i]['success'] != true) continue;
      final citiesData = cityResults[i]['data'] ?? [];
      final region = filteredRegions[i];

      for (final city in citiesData) {
        final cityId = int.tryParse(city['id'].toString()) ?? 0;
        cityInfo[cityId] = {
          'region_name': region['description']?.toString() ?? '',
          'city_name': city['description']?.toString() ?? '',
        };
        storeFutures.add(DeliveryService.getStoresByCity(cityId));
      }
    }

    if (storeFutures.isEmpty) return [];

    final storeResults = await Future.wait(storeFutures);
    final allStores = <Map<String, dynamic>>[];

    for (final storeResult in storeResults) {
      if (storeResult['success'] != true) continue;
      final storesData = storeResult['data'] ?? [];
      for (final store in storesData) {
        if (store is! Map) continue;
        final raw = Map<String, dynamic>.from(store);
        final cityId = int.tryParse(raw['city_id'].toString()) ?? 0;
        var model = StoreLocationModel.fromApiJson(raw);
        if (cityInfo.containsKey(cityId)) {
          model = model.copyWith(
            regionName: cityInfo[cityId]!['region_name'],
            cityName: cityInfo[cityId]!['city_name'],
          );
        }
        allStores.add(model.toMap());
      }
    }

    return allStores;
  }
}
