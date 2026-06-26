import '../models/category_fetch_result.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import '../services/auth_service.dart';
import '../utils/app_error_utils.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'dart:convert';

class ProfileService {
  ProfileService({ProfileRepository? repository})
      : _repository = repository ?? ProfileRepositoryImpl();

  final ProfileRepository _repository;

  Future<UserProfile> getProfile({bool cacheLocally = false}) async {
    final result = await _repository.getProfile();
    _logGetProfileResult(result);
    final profile =
        _parseProfileResult(result, fallback: 'Failed to load profile');
    if (cacheLocally) {
      await _persistProfile(profile);
    }
    return profile;
  }

  static void _logGetProfileResult(CategoryFetchResult result) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');
    final url = ApiConfig.getEndpointUrl(ApiConfig.getProfile);
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('[GET-PROFILE] GET $url');
    debugPrint('── Response HTTP ${result.statusCode} ──');
    if (result.error != null) {
      debugPrint('Error: ${result.error}');
    }
    final body = result.rawBody;
    if (body != null && body.trim().isNotEmpty) {
      try {
        final decoded = json.decode(body);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(body);
      }
    } else if (result.body != null) {
      debugPrint(encoder.convert(result.body));
    } else {
      debugPrint('(empty body)');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  static void _logUpdateProfileResult(
    Map<String, dynamic> requestBody,
    CategoryFetchResult result,
  ) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');
    final url = ApiConfig.getEndpointUrl(ApiConfig.updateProfile);

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('[UPDATE-PROFILE] POST $url');
    debugPrint('── Request body ──');
    debugPrint(encoder.convert(requestBody));
    debugPrint('── Response HTTP ${result.statusCode} ──');
    if (result.error != null) {
      debugPrint('Error: ${result.error}');
    }
    final responseBody = result.rawBody;
    if (responseBody != null && responseBody.trim().isNotEmpty) {
      try {
        final decoded = json.decode(responseBody);
        debugPrint(encoder.convert(decoded));
      } catch (_) {
        debugPrint(responseBody);
      }
    } else if (result.body != null) {
      debugPrint(encoder.convert(result.body));
    } else {
      debugPrint('(empty body)');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  Future<UserProfile> updateProfile({
    required String fname,
    required String email,
    String? number,
    String? addr1,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'fname': fname.trim(),
      'email': email.trim(),
      'number': number?.trim() ?? '',
      'addr_1': addr1?.trim() ?? '',
      'lat': lat?.toString() ?? '',
      'lng': lng?.toString() ?? '',
    };

    final result = await _repository.updateProfile(body: body);
    _logUpdateProfileResult(body, result);
    final profile = _parseProfileResult(
      result,
      fallback: 'Failed to update profile',
    );
    await _persistProfile(profile);
    return profile;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final result = await _repository.changePassword(
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    _rethrowTransportError(result);
    final body = result.body;
    if (body == null) {
      throw Exception(
        AppErrorUtils.messageFromApiBody(
          result.rawBody ?? '',
          fallback: 'Failed to change password',
        ),
      );
    }
    if (result.statusCode != 200 || body['success'] == false) {
      throw Exception(
        AppErrorUtils.messageFromMap(
          body,
          fallback: 'Failed to change password',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final profile = await getProfile();
    return profile.toJson();
  }

  Future<List<dynamic>> fetchOrderHistory() async {
    final result = await _repository.fetchOrders();
    _rethrowTransportError(result);
    if (!result.isHttpOk || result.body == null) {
      throw Exception('Failed to load orders');
    }
    return List<dynamic>.from(result.body!['orders'] ?? []);
  }

  Future<void> refreshLocalProfile() async {
    await getProfile(cacheLocally: true);
  }

  UserProfile _parseProfileResult(
    CategoryFetchResult result, {
    required String fallback,
  }) {
    _rethrowTransportError(result);
    final body = result.body;
    if (body == null) {
      throw Exception(
        AppErrorUtils.messageFromApiBody(
          result.rawBody ?? '',
          fallback: fallback,
        ),
      );
    }
    if (result.statusCode != 200) {
      throw Exception(AppErrorUtils.messageFromMap(body, fallback: fallback));
    }
    if (body['success'] == false) {
      throw Exception(AppErrorUtils.messageFromMap(body, fallback: fallback));
    }
    return UserProfile.fromApiMap(body);
  }

  Future<void> _persistProfile(UserProfile profile) async {
    await AuthService.storeUserData(profile.toAuthStorageMap());
  }

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
