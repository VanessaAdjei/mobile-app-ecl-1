import 'package:eclapp/database/local_storage/local_storage_cleanup.dart';
import 'package:eclapp/database/local_storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageCleanup.clearOnLogout', () {
    test('removes session keys and prefixed order keys', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.localCart: '[]',
        StorageKeys.userProfile: '{"name":"Ada"}',
        StorageKeys.isLoggedIn: true,
        StorageKeys.orderTotal('42'): '76.00',
        StorageKeys.orderStageTimestamps('42'): '{}',
        StorageKeys.guestRecentOrder('guest-1'): '{"id":"42"}',
        StorageKeys.guestId: 'guest-1',
        StorageKeys.themeChoice: 'dark',
        StorageKeys.termsAccepted: true,
        StorageKeys.cachedAllProducts: '[]',
        StorageKeys.recentlyViewedProducts: '[]',
      });

      await LocalStorageCleanup.clearOnLogout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(StorageKeys.localCart), isFalse);
      expect(prefs.containsKey(StorageKeys.userProfile), isFalse);
      expect(prefs.containsKey(StorageKeys.isLoggedIn), isFalse);
      expect(prefs.containsKey(StorageKeys.orderTotal('42')), isFalse);
      expect(prefs.containsKey(StorageKeys.orderStageTimestamps('42')), isFalse);
      expect(
        prefs.containsKey(StorageKeys.guestRecentOrder('guest-1')),
        isFalse,
      );

      expect(prefs.getString(StorageKeys.guestId), 'guest-1');
      expect(prefs.getString(StorageKeys.themeChoice), 'dark');
      expect(prefs.getBool(StorageKeys.termsAccepted), isTrue);
      expect(prefs.containsKey(StorageKeys.cachedAllProducts), isTrue);
      expect(prefs.containsKey(StorageKeys.recentlyViewedProducts), isTrue);
    });
  });

  group('LocalStorageCleanup.clearReplaceableCaches', () {
    test('removes catalog caches but keeps auth and legal flags', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.cachedAllProducts: '[]',
        StorageKeys.categoriesCache: '[]',
        StorageKeys.bannerCache: '{}',
        StorageKeys.storeSelectionTimestamp: '123',
        '${StorageKeys.productDetailPrefix}99': '{}',
        '${StorageKeys.perfCachePrefix}home': '{}',
        StorageKeys.localCart: '[]',
        StorageKeys.guestId: 'guest-1',
        StorageKeys.termsAccepted: true,
      });

      await LocalStorageCleanup.clearReplaceableCaches();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(StorageKeys.cachedAllProducts), isFalse);
      expect(prefs.containsKey(StorageKeys.categoriesCache), isFalse);
      expect(prefs.containsKey(StorageKeys.bannerCache), isFalse);
      expect(prefs.containsKey(StorageKeys.storeSelectionTimestamp), isFalse);
      expect(
        prefs.containsKey('${StorageKeys.productDetailPrefix}99'),
        isFalse,
      );
      expect(prefs.containsKey('${StorageKeys.perfCachePrefix}home'), isFalse);

      expect(prefs.getString(StorageKeys.localCart), '[]');
      expect(prefs.getString(StorageKeys.guestId), 'guest-1');
      expect(prefs.getBool(StorageKeys.termsAccepted), isTrue);
    });
  });
}
