class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _cache = {};
  DateTime? _lastUpdated;

  void cacheData(String key, dynamic data) {
    _cache[key] = data;
    _lastUpdated = DateTime.now();
  }

  dynamic getCachedData(String key) {
    return _cache[key];
  }

  bool shouldRefreshCache({Duration threshold = const Duration(minutes: 30)}) {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!) > threshold;
  }

  void clearCache() {
    _cache.clear();
    _lastUpdated = null;
  }
}