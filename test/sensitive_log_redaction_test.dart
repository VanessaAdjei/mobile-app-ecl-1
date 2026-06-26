import 'package:flutter_test/flutter_test.dart';
import 'package:eclapp/utils/sensitive_log_redaction.dart';

void main() {
  group('redactSensitiveLogFields', () {
    test('masks nested user PII and leaves non-sensitive coords', () {
      final redacted = redactSensitiveLogFields({
        'user': {
          'email': 'a@b.com',
          'fname': 'Jane',
          'phone': '024',
        },
        'token': 'secret',
        'lat': '5.6',
      });

      expect(redacted, {
        'user': {
          'email': '***',
          'fname': '***',
          'phone': '***',
        },
        'token': '***',
        'lat': '5.6',
      });
    });

    test('masks password fields in change-password payloads', () {
      final redacted = redactSensitiveLogFields({
        'current_password': 'old',
        'new_password': 'new12345',
        'confirm_password': 'new12345',
      });

      expect(redacted, {
        'current_password': '***',
        'new_password': '***',
        'confirm_password': '***',
      });
    });

    test('redacts items inside lists', () {
      final redacted = redactSensitiveLogFields([
        {'email': 'one@example.com'},
        {'number': '0240000000'},
      ]);

      expect(redacted, [
        {'email': '***'},
        {'number': '***'},
      ]);
    });

    test('redacts profile update request shape', () {
      final redacted = redactSensitiveLogFields({
        'fname': 'ECL TEST ACCOUNT',
        'email': 'ecltest@yahoo.com',
        'number': '0504518047',
        'addr_1': 'Walnut Close',
        'lat': '5.6463334',
        'lng': '-0.0723893',
      });

      expect(redacted, {
        'fname': '***',
        'email': '***',
        'number': '***',
        'addr_1': '***',
        'lat': '5.6463334',
        'lng': '-0.0723893',
      });
    });

    test('leaves primitives unchanged', () {
      expect(redactSensitiveLogFields('ok'), 'ok');
      expect(redactSensitiveLogFields(42), 42);
      expect(redactSensitiveLogFields(true), true);
    });
  });
}
