import 'dart:convert';

import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/models/category_fetch_result.dart';
import 'package:eclapp/repositories/profile_repository.dart';
import 'package:eclapp/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileRepository implements ProfileRepository {
  CategoryFetchResult? getProfileResult;
  CategoryFetchResult? updateProfileResult;
  CategoryFetchResult? changePasswordResult;
  Map<String, dynamic>? lastUpdateBody;
  Map<String, dynamic>? lastChangePasswordBody;

  @override
  Future<CategoryFetchResult> fetchUserProfile({Duration timeout = const Duration(seconds: 15)}) =>
      getProfile(timeout: timeout);

  @override
  Future<CategoryFetchResult> getProfile({Duration timeout = const Duration(seconds: 15)}) async {
    return getProfileResult ??
        const CategoryFetchResult(statusCode: 500, rawBody: 'missing stub');
  }

  @override
  Future<CategoryFetchResult> updateProfile({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastUpdateBody = body;
    return updateProfileResult ??
        const CategoryFetchResult(statusCode: 500, rawBody: 'missing stub');
  }

  @override
  Future<CategoryFetchResult> changePassword({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastChangePasswordBody = body;
    return changePasswordResult ??
        const CategoryFetchResult(statusCode: 500, rawBody: 'missing stub');
  }

  @override
  Future<CategoryFetchResult> fetchOrders({Duration timeout = const Duration(seconds: 15)}) async {
    return const CategoryFetchResult(statusCode: 200, body: {'orders': []});
  }
}

CategoryFetchResult _profileSuccessResult() {
  return CategoryFetchResult.fromResponse(
    200,
    jsonEncode({
      'success': true,
      'data': {
        'user': {
          'id': 121,
          'name': 'ECL TEST ACCOUNT',
          'email': 'ecltest@yahoo.com',
          'phone': '0504518047',
        },
        'billing_address': {
          'fname': 'ECL TEST ACCOUNT',
          'addr_1': 'Walnut Close',
          'lat': '5.6463334',
          'lng': '-0.0723893',
        },
      },
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProfileRepository repository;
  late ProfileService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeProfileRepository();
    service = ProfileService(repository: repository);
  });

  group('ProfileService.updateProfile', () {
    test('sends lat and lng as strings for backend validation', () async {
      repository.updateProfileResult = _profileSuccessResult();

      await service.updateProfile(
        fname: 'ECL TEST ACCOUNT',
        email: 'ecltest@yahoo.com',
        number: '0504518047',
        addr1: 'Walnut Close',
        lat: 5.6463334,
        lng: -0.0723893,
      );

      expect(repository.lastUpdateBody, {
        'fname': 'ECL TEST ACCOUNT',
        'email': 'ecltest@yahoo.com',
        'number': '0504518047',
        'addr_1': 'Walnut Close',
        'lat': '5.6463334',
        'lng': '-0.0723893',
      });
    });

    test('trims whitespace and uses empty strings for missing coords', () async {
      repository.updateProfileResult = _profileSuccessResult();

      await service.updateProfile(
        fname: '  Jane  ',
        email: '  jane@example.com ',
        number: null,
        addr1: null,
        lat: null,
        lng: null,
      );

      expect(repository.lastUpdateBody, {
        'fname': 'Jane',
        'email': 'jane@example.com',
        'number': '',
        'addr_1': '',
        'lat': '',
        'lng': '',
      });
    });

    test('surfaces first validation error from 422 response', () async {
      repository.updateProfileResult = CategoryFetchResult(
        statusCode: 422,
        rawBody: jsonEncode({
          'success': false,
          'message': 'Validation failed',
          'errors': {
            'lat': ['The lat field must be a string.'],
            'lng': ['The lng field must be a string.'],
          },
        }),
      );

      await expectLater(
        service.updateProfile(
          fname: 'Test',
          email: 'test@example.com',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('The lat field must be a string.'),
          ),
        ),
      );
    });

    test('parses successful update response into UserProfile', () async {
      repository.updateProfileResult = _profileSuccessResult();

      final profile = await service.updateProfile(
        fname: 'ECL TEST ACCOUNT',
        email: 'ecltest@yahoo.com',
        number: '0504518047',
        addr1: 'Walnut Close',
        lat: 5.6463334,
        lng: -0.0723893,
      );

      expect(profile.name, 'ECL TEST ACCOUNT');
      expect(profile.email, 'ecltest@yahoo.com');
      expect(profile.phone, '0504518047');
      expect(profile.address, 'Walnut Close');
      expect(profile.lat, closeTo(5.6463334, 0.000001));
      expect(profile.lng, closeTo(-0.0723893, 0.000001));
    });
  });

  group('ProfileService.getProfile', () {
    test('loads merged user and billing profile', () async {
      repository.getProfileResult = _profileSuccessResult();

      final profile = await service.getProfile();

      expect(profile.id, '121');
      expect(profile.name, 'ECL TEST ACCOUNT');
      expect(profile.address, 'Walnut Close');
    });
  });

  group('ProfileService.changePassword', () {
    test('posts password fields to repository', () async {
      repository.changePasswordResult = CategoryFetchResult.fromResponse(
        200,
        jsonEncode({'success': true, 'message': 'Password updated'}),
      );

      await service.changePassword(
        currentPassword: 'old-pass-1',
        newPassword: 'new-pass-12',
        confirmPassword: 'new-pass-12',
      );

      expect(repository.lastChangePasswordBody, {
        'current_password': 'old-pass-1',
        'new_password': 'new-pass-12',
        'confirm_password': 'new-pass-12',
      });
    });

    test('throws when API reports failure', () async {
      repository.changePasswordResult = CategoryFetchResult.fromResponse(
        200,
        jsonEncode({
          'success': false,
          'message': 'Current password is incorrect',
        }),
      );

      await expectLater(
        service.changePassword(
          currentPassword: 'wrong',
          newPassword: 'new-pass-12',
          confirmPassword: 'new-pass-12',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Current password is incorrect'),
          ),
        ),
      );
    });
  });
}
