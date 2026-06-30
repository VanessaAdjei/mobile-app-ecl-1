import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

/// Clears on-device data according to [STORAGE_POLICY.md].
class LocalStorageCleanup {
  LocalStorageCleanup._();

  /// Removes account-bound session data. Keeps theme, terms, onboarding,
  /// catalog caches, guest_id, and recently viewed products.
  static Future<void> clearOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();

      for (final key in StorageKeys.logoutExactKeys) {
        await prefs.remove(key);
      }

      for (final key in keys) {
        if (_matchesLogoutPrefix(key)) {
          await prefs.remove(key);
        }
      }

      if (kDebugMode) {
        debugPrint('LocalStorageCleanup: session data cleared on logout');
      }
    } catch (e, st) {
      debugPrint('LocalStorageCleanup.clearOnLogout failed: $e\n$st');
    }
  }

  /// Wipes replaceable catalog/perf caches. Does not touch auth or legal flags.
  /// Useful for “clear cache” in settings (future) or low-storage recovery.
  static Future<void> clearReplaceableCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();

      const exact = [
        StorageKeys.cachedAllProducts,
        StorageKeys.cachedPopularProducts,
        StorageKeys.lastCacheTime,
        StorageKeys.bannerCache,
        StorageKeys.bannerCacheTime,
        StorageKeys.storeSelectionRegions,
        StorageKeys.storeSelectionStores,
        StorageKeys.storeSelectionTimestamp,
        StorageKeys.cachedStoreData,
        StorageKeys.storeDataTimestamp,
        StorageKeys.homepageProductsCache,
        StorageKeys.categoriesCache,
        StorageKeys.productsCache,
        StorageKeys.prefetchCache,
        'homepage_cache',
        'homepage_cache_time',
        'homepage_products',
        'homepage_popular_products',
        'homepage_categorized_products',
        'homepage_products_cache_time',
        'homepage_popular_products_cache_time',
        'homepage_categorized_products_cache_time',
        'categories_cache_time',
        'products_cache_time',
        'item_detail_product_cache',
        'item_detail_related_cache',
        'item_detail_images_cache',
        'promotional_events_cache',
        'active_event_cache',
        'clearance_sale_active',
        'clearance_sale_data',
        'wallet_cache',
        'transactions_cache',
      ];

      for (final key in exact) {
        await prefs.remove(key);
      }

      for (final key in keys) {
        if (key.startsWith(StorageKeys.productDetailPrefix) ||
            key.startsWith(StorageKeys.productDetailTsPrefix) ||
            key.startsWith(StorageKeys.perfCachePrefix)) {
          await prefs.remove(key);
        }
      }

      if (kDebugMode) {
        debugPrint('LocalStorageCleanup: replaceable caches cleared');
      }
    } catch (e, st) {
      debugPrint('LocalStorageCleanup.clearReplaceableCaches failed: $e\n$st');
    }
  }

  static bool _matchesLogoutPrefix(String key) {
    for (final prefix in StorageKeys.logoutKeyPrefixes) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }
}
