import 'dart:convert';

import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/auth_service.dart';
import '../../services/http_client_service.dart';

abstract class PaymentRemoteDataSource {
  Future<CategoryFetchResult> submitExpressPayment({
    required Map<String, dynamic> params,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 60),
  });

  Future<CategoryFetchResult> checkPayment({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> applyCoupon({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  });
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  @override
  Future<CategoryFetchResult> submitExpressPayment({
    required Map<String, dynamic> params,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final formBody = params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
          )
          .join('&');
      final formHeaders = <String, String>{
        ...headers,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      final response = await HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.expressPayment)),
        headers: formHeaders,
        body: formBody,
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
  Future<CategoryFetchResult> checkPayment({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkPayment)),
        headers: headers,
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
  Future<CategoryFetchResult> applyCoupon({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.applyCoupon)),
        headers: headers,
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

/// Builds auth headers for logged-in or guest checkout flows.
Future<Map<String, String>> buildCheckoutAuthHeaders() async {
  final isLoggedIn = await AuthService.isLoggedIn();
  final token = await AuthService.getToken();
  final headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  if (isLoggedIn && token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  } else if (!isLoggedIn && token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Guest $token';
    headers['X-Guest-ID'] = token;
  }
  return headers;
}

Future<Map<String, dynamic>> buildCheckPaymentBody() async {
  final isLoggedIn = await AuthService.isLoggedIn();
  final tokenRaw = await AuthService.getToken();
  if (isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
    final userId = await AuthService.getCurrentUserID();
    if (userId == null) {
      throw Exception('Session expired. Please log in again.');
    }
    return {'user_id': userId};
  }
  if (!isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
    return {'guest_id': tokenRaw};
  }
  throw Exception('Unable to verify payment right now.');
}
