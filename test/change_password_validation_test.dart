/// Client-side rules mirrored from [ChangePasswordPage] validators.
import 'package:flutter_test/flutter_test.dart';

bool isValidNewPassword(String value, {required String currentPassword}) {
  if (value.length < 8) return false;
  if (!RegExp(r'\d').hasMatch(value)) return false;
  if (value == currentPassword) return false;
  return true;
}

void main() {
  group('change password client rules', () {
    test('requires at least 8 characters', () {
      expect(isValidNewPassword('short1', currentPassword: 'old-pass'), isFalse);
      expect(isValidNewPassword('long-enough1', currentPassword: 'old-pass'),
          isTrue);
    });

    test('requires at least one digit', () {
      expect(isValidNewPassword('allletters', currentPassword: 'old-pass'),
          isFalse);
      expect(isValidNewPassword('letters9', currentPassword: 'old-pass'),
          isTrue);
    });

    test('must differ from current password', () {
      expect(
        isValidNewPassword('same-pass1', currentPassword: 'same-pass1'),
        isFalse,
      );
    });
  });
}
