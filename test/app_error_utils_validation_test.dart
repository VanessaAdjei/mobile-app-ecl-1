import 'dart:convert';

import 'package:eclapp/models/category_fetch_result.dart';
import 'package:eclapp/utils/app_error_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryFetchResult.fromResponse', () {
    test('parses JSON body only for HTTP 200', () {
      final ok = CategoryFetchResult.fromResponse(
        200,
        jsonEncode({'success': true, 'data': {'id': 1}}),
      );
      expect(ok.body?['success'], isTrue);
      expect(ok.rawBody, isNotNull);

      final validation = CategoryFetchResult.fromResponse(
        422,
        jsonEncode({
          'success': false,
          'message': 'Validation failed',
          'errors': {'lat': ['The lat field must be a string.']},
        }),
      );
      expect(validation.statusCode, 422);
      expect(validation.body, isNull);
      expect(validation.rawBody, contains('lat'));
    });
  });

  group('AppErrorUtils validation messages', () {
    test('firstFieldValidationError returns first field message', () {
      final message = AppErrorUtils.firstFieldValidationError({
        'errors': {
          'lat': ['The lat field must be a string.'],
          'lng': ['The lng field must be a string.'],
        },
      });

      expect(message, 'The lat field must be a string.');
    });

    test('messageFromMap prefers field errors over generic validation message', () {
      final message = AppErrorUtils.messageFromMap({
        'message': 'Validation failed',
        'errors': {
          'email': ['The email has already been taken.'],
        },
      });

      expect(message, 'The email has already been taken.');
    });

    test('messageFromApiBody parses 422 profile update payload', () {
      final message = AppErrorUtils.messageFromApiBody(
        jsonEncode({
          'success': false,
          'message': 'Validation failed',
          'errors': {
            'lng': ['The lng field must be a string.'],
          },
        }),
      );

      expect(message, 'The lng field must be a string.');
    });
  });
}
