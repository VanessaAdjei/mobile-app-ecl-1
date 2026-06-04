import 'dart:async';
import 'dart:convert';

import 'package:eclapp/cache/product_catalog_memory.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/services/product_catalog_service.dart';
import 'package:eclapp/utils/catalog_timer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Product> decodeStoredProductsJson(String jsonStr) {
  final allList = json.decode(jsonStr) as List;
  return allList
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
}

String encodeProductsForStorage(List<Product> products) {
  return json.encode(products.map((p) => p.toJson()).toList());
}

/// In-memory + disk cache for the full product catalog (get-all-products).
class ProductCache {
  ProductCache._();

  static List<Product> _cachedProducts = [];
  static List<Product> _cachedPopularProducts = [];
  static List<Product> _priorityProducts = [];
  static List<dynamic> _cachedRawCatalogItems = [];
  static DateTime? _lastCacheTime;

  /// Fresh catalog TTL — network reload only after this unless forced.
  static const Duration _cacheValidDuration = Duration(hours: 1);
  /// Disk may still be shown offline up to this age; network waits for [_cacheValidDuration].
  static const Duration _staleWhileRevalidateDuration = Duration(hours: 6);
  static const String _allProductsKey = 'cached_all_products';
  static const String _popularProductsKey = 'cached_popular_products';
  static const String _lastCacheTimeKey = 'last_cache_time';
  static bool _prefetchInFlight = false;
  static bool _priorityPrefetchInFlight = false;
  static Future<void>? _catalogLoadFuture;
  static Future<void>? _priorityLoadFuture;
  static Future<void>? _storageLoadFuture;
  static bool _loggedCatalogReady = false;
  static bool _catalogApiSucceeded = false;
  static final List<VoidCallback> _catalogListeners = [];
  static final List<VoidCallback> _priorityListeners = [];
  static final ProductCatalogService _catalogService = ProductCatalogService();

  static bool get isCatalogLoadInFlight =>
      _catalogLoadFuture != null || _prefetchInFlight;

  static bool get isPriorityLoadInFlight =>
      _priorityLoadFuture != null || _priorityPrefetchInFlight;

  static bool get hasPriorityProducts => _priorityProducts.isNotEmpty;

  static List<Product> get cachedPriorityProducts =>
      List<Product>.unmodifiable(_priorityProducts);

  static int get catalogProductCount => _cachedProducts.length;

  /// True after get-all-products returns `status: "success"` / `success: true`.
  static bool get catalogApiSucceeded =>
      _catalogApiSucceeded || hasProductsInMemory;

  static Future<void> waitForCatalogApiSuccess({
    Duration maxWait = const Duration(seconds: 45),
  }) async {
    if (catalogApiSucceeded) return;
    final deadline = DateTime.now().add(maxWait);
    void listener() {
      if (catalogApiSucceeded) {
        removeCatalogListener(listener);
      }
    }

    addCatalogListener(listener);
    try {
      while (DateTime.now().isBefore(deadline)) {
        if (catalogApiSucceeded) return;
        if (!isCatalogLoadInFlight &&
            !isPriorityLoadInFlight &&
            _catalogLoadFuture == null &&
            _prefetchInFlight == false) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (catalogApiSucceeded) return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      removeCatalogListener(listener);
    }
  }

  static void addCatalogListener(VoidCallback listener) {
    _catalogListeners.add(listener);
  }

  static void removeCatalogListener(VoidCallback listener) {
    _catalogListeners.remove(listener);
  }

  static void addPriorityListener(VoidCallback listener) {
    _priorityListeners.add(listener);
  }

  static void removePriorityListener(VoidCallback listener) {
    _priorityListeners.remove(listener);
  }

  static void _notifyCatalogListeners() {
    if (_catalogListeners.isEmpty) return;
    for (final listener in List<VoidCallback>.from(_catalogListeners)) {
      listener();
    }
  }

  static void _notifyPriorityListeners() {
    if (_priorityListeners.isEmpty) return;
    for (final listener in List<VoidCallback>.from(_priorityListeners)) {
      listener();
    }
  }

  static void _cachePriorityProducts(List<Product> products) {
    if (products.isEmpty) return;
    final hadPriority = _priorityProducts.isNotEmpty;
    _priorityProducts = products;
    if (!hadPriority) {
      warmPopularFromCatalog();
      if (_cachedPopularProducts.isEmpty) {
        cachePopularProducts(List<Product>.from(products.take(20)));
      }
      _notifyPriorityListeners();
    }
  }

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  /// True when a network catalog fetch is allowed (hourly gate or no data).
  static bool get shouldRefreshFromNetwork =>
      !hasProductsInMemory || !isCacheValid;

  static bool get canUseStaleData {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) <
        _staleWhileRevalidateDuration;
  }

  static void cacheProducts(List<Product> products) {
    final hadProducts = _cachedProducts.isNotEmpty;
    if (products.isNotEmpty) {
      _catalogApiSucceeded = true;
    }
    if (products.isNotEmpty && _priorityProducts.isEmpty) {
      _cachePriorityProducts(pickPriorityFromCatalog(products));
      CatalogTimer.mark('priority_from_full_catalog');
    }
    _cachedProducts = products;
    ProductCatalogMemory.setProducts(products);
    _lastCacheTime = DateTime.now();
    unawaited(_saveAllProductsToStorage());
    if (products.isNotEmpty && !hadProducts) {
      _notifyCatalogListeners();
    }
  }

  static void _markCatalogApiSucceeded({bool notifyListeners = true}) {
    if (_catalogApiSucceeded) return;
    _catalogApiSucceeded = true;
    if (notifyListeners) _notifyCatalogListeners();
  }

  static bool isPrescriptionProduct(Product product) =>
      product.otcpom?.trim().toLowerCase() == 'pom';

  /// Popular / home-priority rows — never include prescription (POM) medicines.
  static List<Product> withoutPrescriptionProducts(Iterable<Product> products) =>
      products.where((p) => !isPrescriptionProduct(p)).toList();

  /// Fast home subset — OTC medication first, then other non-POM catalog rows.
  static List<Product> pickPriorityFromCatalog(
    List<Product> catalog, {
    int limit = 24,
  }) {
    if (catalog.isEmpty) return const [];
    final eligible = withoutPrescriptionProducts(catalog);
    if (eligible.isEmpty) return const [];

    final otc = <Product>[];
    for (final p in eligible) {
      if (p.otcpom?.trim().toLowerCase() == 'otc') {
        otc.add(p);
        if (otc.length >= limit) break;
      }
    }
    if (otc.length >= 8) return otc.take(limit).toList();
    return eligible.take(limit).toList();
  }

  static Future<List<Product>> _waitForCatalogPrioritySlice(
    Duration maxWait,
  ) async {
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      if (hasProductsInMemory) {
        return pickPriorityFromCatalog(_cachedProducts);
      }
      if (!isCatalogLoadInFlight && !_prefetchInFlight) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return const [];
  }

  static void cachePopularProducts(List<Product> products) {
    _cachedPopularProducts = withoutPrescriptionProducts(products);
    _lastCacheTime = DateTime.now();
    unawaited(_saveToStorage());
  }

  static bool get hasProductsInMemory => _cachedProducts.isNotEmpty;

  /// True when home can paint from priority subset, disk, or full catalog.
  static bool get hasHomeRenderableCatalog =>
      hasProductsInMemory || hasPriorityProducts;

  static Future<void> waitForPrefetch({
    Duration maxWait = const Duration(seconds: 4),
  }) async {
    await ensureCatalogReady(maxWait: maxWait);
  }

  /// Blocks until **get-all-products** is in memory (required before home).
  static Future<bool> ensureCatalogReady({
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    if (hasProductsInMemory) {
      if (!_loggedCatalogReady) {
        _loggedCatalogReady = true;
        debugPrint(
          'ProductCache: catalog ready (${_cachedProducts.length} products)',
        );
      }
      return true;
    }

    await loadFromStorage();
    if (hasProductsInMemory) {
      debugPrint(
        'ProductCache: catalog ready from disk (${_cachedProducts.length})',
      );
      if (shouldRefreshFromNetwork) {
        unawaited(prefetchFromNetwork());
      }
      return true;
    }

    final networkFuture = shouldRefreshFromNetwork
        ? prefetchFromNetwork()
        : Future<void>.value();
    try {
      await networkFuture.timeout(maxWait);
    } on TimeoutException {
      debugPrint(
        'ProductCache: get-all-products timed out after ${maxWait.inSeconds}s',
      );
    }

    final ready = hasProductsInMemory;
    debugPrint(
      'ProductCache: ensureCatalogReady ${ready ? "ok" : "FAILED"} '
      '(${_cachedProducts.length} products from get-all-products)',
    );
    return ready;
  }

  /// Waits for the fast home subset (get-home-priority / popular-products).
  static Future<bool> ensurePriorityReady({
    Duration maxWait = const Duration(seconds: 10),
  }) async {
    if (hasPriorityProducts || hasProductsInMemory) return true;

    await loadFromStorage();
    if (hasProductsInMemory) return true;
    if (_cachedPopularProducts.isNotEmpty) {
      _cachePriorityProducts(List<Product>.from(_cachedPopularProducts));
      CatalogTimer.mark('priority_disk_ready');
      return true;
    }

    if (_priorityLoadFuture == null) {
      unawaited(prefetchPriorityFromNetwork());
    }

    try {
      await (_priorityLoadFuture ?? Future.value()).timeout(maxWait);
    } on TimeoutException {
      debugPrint(
        'ProductCache: priority catalog timed out after ${maxWait.inSeconds}s',
      );
    }

    return hasPriorityProducts || hasProductsInMemory;
  }

  static Future<void> prefetchPriorityFromNetwork({bool forceRefresh = false}) async {
    if (!forceRefresh && hasProductsInMemory && isCacheValid) return;
    if (hasPriorityProducts) return;
    if (_priorityLoadFuture != null) return _priorityLoadFuture;

    _priorityLoadFuture = _runPriorityNetworkLoad();
    try {
      await _priorityLoadFuture;
    } finally {
      _priorityLoadFuture = null;
    }
  }

  static Future<void> _runPriorityNetworkLoad() async {
    if (_priorityPrefetchInFlight || hasProductsInMemory) return;
    _priorityPrefetchInFlight = true;
    try {
      debugPrint('ProductCache: GET get-home-priority (fast home subset)...');
      var products = await _catalogService.fetchPriorityProducts(
        timeout: const Duration(seconds: 8),
      );

      if (products.isEmpty && hasProductsInMemory) {
        products = pickPriorityFromCatalog(_cachedProducts);
      }

      if (products.isEmpty && (isCatalogLoadInFlight || _prefetchInFlight)) {
        debugPrint(
          'ProductCache: priority APIs empty — waiting for catalog slice...',
        );
        products = await _waitForCatalogPrioritySlice(
          const Duration(seconds: 25),
        );
        if (products.isNotEmpty) {
          CatalogTimer.mark('priority_from_catalog_wait');
        }
      }

      if (products.isEmpty) {
        debugPrint(
          'ProductCache: priority fetch returned no products '
          '(get-home-priority 404, popular empty)',
        );
        return;
      }

      if (hasPriorityProducts) {
        debugPrint(
          'ProductCache: priority slice already set (${_priorityProducts.length})',
        );
        return;
      }

      _cachePriorityProducts(products);
      CatalogTimer.mark('priority_network_ready');
      debugPrint(
        'ProductCache: priority catalog OK — ${products.length} products',
      );
    } catch (e) {
      debugPrint('ProductCache: priority catalog error: $e');
    } finally {
      _priorityPrefetchInFlight = false;
    }
  }

  static void warmPopularFromCatalog() => _fillPopularFromCatalogIfNeeded();

  static Future<void> ensurePopularReady({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPopularProducts.isNotEmpty &&
        isCacheValid) {
      return;
    }
    warmPopularFromCatalog();
    if (!forceRefresh &&
        _cachedPopularProducts.isNotEmpty &&
        isCacheValid) {
      return;
    }
    if (!_prefetchInFlight && shouldRefreshFromNetwork) {
      await _fetchAndCachePopularProducts();
    }
    warmPopularFromCatalog();
  }

  static List<Product> get cachedProducts => _cachedProducts;
  static List<Product> get cachedPopularProducts => _cachedPopularProducts;

  static bool get hasRawCatalogItems => _cachedRawCatalogItems.isNotEmpty;

  static List<dynamic> get cachedRawCatalogItems =>
      List<dynamic>.from(_cachedRawCatalogItems);

  static void clearCache() {
    _cachedProducts.clear();
    _cachedPopularProducts.clear();
    _priorityProducts.clear();
    _cachedRawCatalogItems = [];
    _lastCacheTime = null;
    _clearFromStorage();
  }

  static Future<void> loadFromStorage() async {
    _storageLoadFuture ??= _loadFromStorageOnce();
    await _storageLoadFuture;
  }

  static Future<void> _loadFromStorageOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTimeString = prefs.getString(_lastCacheTimeKey);

      if (lastCacheTimeString == null) return;

      _lastCacheTime = DateTime.parse(lastCacheTimeString);
      if (!canUseStaleData) {
        await _clearPersistedStorageOnly();
        return;
      }

      final allJson = prefs.getString(_allProductsKey);
      if (allJson != null && allJson.isNotEmpty) {
        _cachedProducts = await compute(decodeStoredProductsJson, allJson);
        ProductCatalogMemory.setProducts(_cachedProducts);
      }

      final popularJson = prefs.getString(_popularProductsKey);
      if (popularJson != null && popularJson.isNotEmpty) {
        cachePopularProducts(
          await compute(decodeStoredProductsJson, popularJson),
        );
      }

      debugPrint(
        'ProductCache: loaded ${_cachedProducts.length} products, '
        '${_cachedPopularProducts.length} popular from disk',
      );

      if (_cachedProducts.isNotEmpty) {
        _catalogApiSucceeded = true;
        if (_priorityProducts.isEmpty) {
          _cachePriorityProducts(pickPriorityFromCatalog(_cachedProducts));
          CatalogTimer.mark('priority_disk_ready');
        }
        warmPopularFromCatalog();
        _notifyCatalogListeners();
      } else if (_cachedPopularProducts.isNotEmpty) {
        _cachePriorityProducts(List<Product>.from(_cachedPopularProducts));
        CatalogTimer.mark('priority_disk_ready');
      }
    } catch (e) {
      debugPrint('ProductCache: Error loading from storage: $e');
      await _clearPersistedStorageOnly();
    }
  }

  static Future<void> prefetchFromNetwork({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProducts.isNotEmpty && isCacheValid) return;
    if (_catalogLoadFuture != null) {
      return _catalogLoadFuture;
    }

    _catalogLoadFuture = _runCatalogNetworkLoad();
    try {
      await _catalogLoadFuture;
    } finally {
      _catalogLoadFuture = null;
    }
  }

  static Future<void> _runCatalogNetworkLoad() async {
    if (_prefetchInFlight) return;
    _prefetchInFlight = true;
    try {
      debugPrint('ProductCache: GET get-all-products (catalog API)...');
      await _fetchAndCacheAllProducts();
      if (!hasProductsInMemory) {
        debugPrint('ProductCache: get-all-products returned no products');
        return;
      }
      debugPrint(
        'ProductCache: get-all-products OK — ${_cachedProducts.length} products',
      );
      _fillPopularFromCatalogIfNeeded();
      if (_cachedPopularProducts.isEmpty) {
        unawaited(_fetchAndCachePopularProducts());
      }
      CatalogTimer.mark('network_catalog_ready');
      _notifyCatalogListeners();
      debugPrint(
        'ProductCache: catalog load done — ${_cachedProducts.length} products, '
        '${_cachedPopularProducts.length} popular',
      );
    } catch (e) {
      debugPrint('ProductCache: catalog load error: $e');
    } finally {
      _prefetchInFlight = false;
    }
  }

  static void _fillPopularFromCatalogIfNeeded() {
    if (_cachedProducts.isEmpty || _cachedPopularProducts.isNotEmpty) return;
    final slice = pickPriorityFromCatalog(_cachedProducts, limit: 20);
    if (slice.isNotEmpty) {
      cachePopularProducts(slice);
    }
  }

  static Future<void> _fetchAndCacheAllProducts() async {
    // One long attempt first — slow 1k+ product payloads often exceed 20s;
    // retrying after a false timeout doubles wall time (~38s → ~60s+).
    const timeouts = <Duration>[
      Duration(seconds: 50),
      Duration(seconds: 70),
    ];
    Object? lastError;
    List<Product> products = const [];

    for (var i = 0; i < timeouts.length; i++) {
      final timeout = timeouts[i];
      final sw = Stopwatch()..start();
      try {
        final bundle =
            await _catalogService.fetchCatalogBundle(timeout: timeout);
        products = bundle.products;
        if (bundle.apiSuccess) {
          _markCatalogApiSucceeded(notifyListeners: products.isEmpty);
        }
        if (bundle.rawItems.isNotEmpty) {
          _cachedRawCatalogItems = List<dynamic>.from(bundle.rawItems);
        }
        lastError = null;
        debugPrint(
          'ProductCache: get-all-products parsed ${products.length} products '
          'in ${sw.elapsedMilliseconds}ms (attempt ${i + 1})',
        );
        break;
      } on TimeoutException catch (e) {
        lastError = e;
        final attempt = i + 1;
        final isLast = i == timeouts.length - 1;
        debugPrint(
          'ProductCache: get-all-products timeout '
          '(attempt $attempt/${timeouts.length}) after ${timeout.inSeconds}s',
        );
        if (!isLast) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    if (lastError != null && products.isEmpty) {
      throw lastError;
    }
    if (products.isNotEmpty) {
      cacheProducts(products);
      _loggedCatalogReady = true;
    }
  }

  static Future<void> _fetchAndCachePopularProducts() async {
    final products = await _catalogService.fetchPopularProducts(
      timeout: const Duration(seconds: 8),
    );
    if (products.isNotEmpty) {
      cachePopularProducts(products);
    } else {
      _fillPopularFromCatalogIfNeeded();
    }
  }

  static Future<void> _saveAllProductsToStorage() async {
    if (_cachedProducts.isEmpty || _lastCacheTime == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = await compute(
        encodeProductsForStorage,
        List<Product>.from(_cachedProducts),
      );
      await prefs.setString(
        _allProductsKey,
        encoded,
      );
      await prefs.setString(
        _lastCacheTimeKey,
        _lastCacheTime!.toIso8601String(),
      );
    } catch (e) {
      debugPrint('ProductCache: Error saving all products: $e');
    }
  }

  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cachedPopularProducts.isNotEmpty) {
        final productsJson = json.encode(
          _cachedPopularProducts.map((p) => p.toJson()).toList(),
        );
        await prefs.setString(_popularProductsKey, productsJson);
      }
      if (_lastCacheTime != null) {
        await prefs.setString(
          _lastCacheTimeKey,
          _lastCacheTime!.toIso8601String(),
        );
      }
      if (_cachedProducts.isNotEmpty) {
        await prefs.setString(
          _allProductsKey,
          json.encode(_cachedProducts.map((p) => p.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('ProductCache: Error saving to storage: $e');
    }
  }

  static Future<void> _clearPersistedStorageOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_allProductsKey);
      await prefs.remove(_popularProductsKey);
      await prefs.remove(_lastCacheTimeKey);
      await prefs.remove('last_shuffle_time');
    } catch (e) {
      debugPrint('ProductCache: Error clearing persisted cache: $e');
    }
  }

  static Future<void> _clearFromStorage() async {
    await _clearPersistedStorageOnly();
    _cachedProducts = [];
    _cachedPopularProducts = [];
    _priorityProducts.clear();
    ProductCatalogMemory.clear();
    _lastCacheTime = null;
  }
}
