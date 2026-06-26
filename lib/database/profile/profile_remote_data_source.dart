import 'dart:convert';

import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/auth_service.dart';
import '../../services/http_client_service.dart';

abstract class ProfileRemoteDataSource {
  Future<CategoryFetchResult> fetchUserProfile({
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> getProfile({
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> updateProfile({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> changePassword({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> fetchOrders({
    Duration timeout = const Duration(seconds: 15),
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No auth token');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<CategoryFetchResult> _get(Uri uri, Duration timeout) async {
    try {
      final response = await HttpClientService.get(
        uri,
        headers: await _authHeaders(),
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  Future<CategoryFetchResult> _post(
    Uri uri,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    try {
      final response = await HttpClientService.post(
        uri,
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> fetchUserProfile({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      getProfile(timeout: timeout);

  @override
  Future<CategoryFetchResult> getProfile({
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getProfile)),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> updateProfile({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _post(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.updateProfile)),
      body,
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> changePassword({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _post(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.changePassword)),
      body,
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchOrders({
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.orders)),
      timeout,
    );
  }
}
