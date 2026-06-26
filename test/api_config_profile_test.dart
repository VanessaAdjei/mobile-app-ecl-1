import 'package:eclapp/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig profile endpoints', () {
    test('getProfile resolves to /api/profile', () {
      expect(
        ApiConfig.getEndpointUrl(ApiConfig.getProfile),
        '${ApiConfig.baseUrl}/profile',
      );
    });

    test('updateProfile resolves to /api/profile/update', () {
      expect(
        ApiConfig.getEndpointUrl(ApiConfig.updateProfile),
        '${ApiConfig.baseUrl}/profile/update',
      );
    });

    test('changePassword resolves to /api/change-password', () {
      expect(
        ApiConfig.getEndpointUrl(ApiConfig.changePassword),
        '${ApiConfig.baseUrl}/change-password',
      );
    });

    test('legacy aliases point at canonical profile paths', () {
      expect(ApiConfig.userProfile, ApiConfig.getProfile);
      expect(ApiConfig.userProfileUpdate, ApiConfig.updateProfile);
      expect(ApiConfig.getUserProfile, ApiConfig.getProfile);
    });
  });
}
