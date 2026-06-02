import 'dart:convert';

import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/auth_service.dart';
import '../../services/http_client_service.dart';

abstract class RefillRemoteDataSource {
  Future<CategoryFetchResult> fetchRefillList({
    required String authToken,
    Duration timeout = const Duration(seconds: 10),
  });

  Future<CategoryFetchResult> addToCart({
    required String authToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  });
}

class RefillRemoteDataSourceImpl implements RefillRemoteDataSource {
  @override
  Future<CategoryFetchResult> fetchRefillList({
    required String authToken,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final response = await HttpClientService.get(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.refill)),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
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
  Future<CategoryFetchResult> addToCart({
    required String authToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkAuth)),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
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
}
