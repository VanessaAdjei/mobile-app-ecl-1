import 'package:eclapp/database/local_storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout prefixes do not overlap keep-on-logout keys', () {
    for (final kept in StorageKeys.keepOnLogoutKeys) {
      for (final prefix in StorageKeys.logoutKeyPrefixes) {
        expect(
          kept.startsWith(prefix),
          isFalse,
          reason: '$kept should not be cleared by prefix $prefix',
        );
      }
    }
  });

  test('logout exact keys do not include keep-on-logout keys', () {
    for (final key in StorageKeys.logoutExactKeys) {
      expect(
        StorageKeys.keepOnLogoutKeys.contains(key),
        isFalse,
        reason: '$key is both cleared and kept on logout',
      );
    }
  });

  test('guest_id is kept on logout', () {
    expect(StorageKeys.keepOnLogoutKeys, contains(StorageKeys.guestId));
    expect(StorageKeys.logoutExactKeys, isNot(contains(StorageKeys.guestId)));
  });

  test('terms and theme are kept on logout', () {
    expect(StorageKeys.keepOnLogoutKeys, contains(StorageKeys.termsAccepted));
    expect(StorageKeys.keepOnLogoutKeys, contains(StorageKeys.themeChoice));
  });
}
