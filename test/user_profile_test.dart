import 'package:flutter_test/flutter_test.dart';

import 'package:eclapp/models/user_profile.dart';

void main() {
  group('UserProfile.fromApiMap', () {
    test('parses flat backend profile fields', () {
      final profile = UserProfile.fromApiMap({
        'success': true,
        'data': {
          'id': 42,
          'fname': 'Jane Doe',
          'email': 'jane@example.com',
          'number': '0244123456',
          'addr_1': '12 Ring Road',
          'lat': 5.6037,
          'lng': -0.1870,
        },
      });

      expect(profile.id, '42');
      expect(profile.name, 'Jane Doe');
      expect(profile.email, 'jane@example.com');
      expect(profile.phone, '0244123456');
      expect(profile.address, '12 Ring Road');
      expect(profile.lat, 5.6037);
      expect(profile.lng, -0.1870);
    });

    test('merges data.user and data.billing_address from GET /profile', () {
      final profile = UserProfile.fromApiMap({
        'success': true,
        'message': 'Profile retrieved successfully',
        'data': {
          'user': {
            'id': 121,
            'name': 'ECL TEST',
            'email': 'ecltest@yahoo.com',
            'phone': '0504518047',
            'hashed_link':
                'e734bed3a3f7f0ab8ff43018f85a46d98a5d36eb79dc76973f',
          },
          'billing_address': {
            'id': 68,
            'user_id': '121',
            'fname': 'ECL TEST',
            'email': 'ecltest@yahoo.com',
            'phone': '0504518047',
            'addr_1': 'Fishing Harbour Road',
            'region': 'Greater Accra Region',
            'city': 'Tema',
            'lat': '5.6444579',
            'lng': '0.0145282',
          },
        },
      });

      expect(profile.id, '121');
      expect(profile.name, 'ECL TEST');
      expect(profile.email, 'ecltest@yahoo.com');
      expect(profile.phone, '0504518047');
      expect(profile.address,
          'Fishing Harbour Road, Tema, Greater Accra Region');
      expect(profile.city, 'Tema');
      expect(profile.region, 'Greater Accra Region');
      expect(profile.lat, closeTo(5.6444579, 0.000001));
      expect(profile.lng, closeTo(0.0145282, 0.000001));
      expect(
        profile.hashedLink,
        'e734bed3a3f7f0ab8ff43018f85a46d98a5d36eb79dc76973f',
      );
    });

    test('builds update-profile request body', () {
      final profile = UserProfile(
        name: 'John',
        email: 'john@example.com',
        phone: '0201111111',
        address: 'Main St, Accra',
        lat: 5.6,
        lng: -0.18,
      );

      expect(profile.toUpdateRequestBody(), {
        'fname': 'John',
        'email': 'john@example.com',
        'number': '0201111111',
        'addr_1': 'Main St',
        'lat': '5.6',
        'lng': '-0.18',
      });
    });

    test('toAuthStorageMap keeps name, phone, and billing fields', () {
      final profile = UserProfile.fromApiMap({
        'data': {
          'user': {'id': 1, 'name': 'A', 'email': 'a@b.com', 'phone': '024'},
          'billing_address': {
            'addr_1': 'Street',
            'city': 'Tema',
            'region': 'Greater Accra Region',
          },
        },
      });

      final stored = profile.toAuthStorageMap();
      expect(stored['name'], 'A');
      expect(stored['phone'], '024');
      expect(stored['addr_1'], 'Street');
      expect(stored['city'], 'Tema');
      expect(stored['region'], 'Greater Accra Region');
    });

    test('toUpdateRequestBody uses empty strings when coords are missing', () {
      final profile = UserProfile(
        name: 'Jane',
        email: 'jane@example.com',
      );

      expect(profile.toUpdateRequestBody(), {
        'fname': 'Jane',
        'email': 'jane@example.com',
        'number': '',
        'addr_1': '',
        'lat': '',
        'lng': '',
      });
    });

    test('street line uses first comma-separated segment for addr_1', () {
      final profile = UserProfile(
        name: 'Jane',
        email: 'jane@example.com',
        address: 'Walnut Close, Tema, Greater Accra Region',
        lat: 5.6,
        lng: -0.1,
      );

      expect(profile.toUpdateRequestBody()['addr_1'], 'Walnut Close');
    });
  });
}
