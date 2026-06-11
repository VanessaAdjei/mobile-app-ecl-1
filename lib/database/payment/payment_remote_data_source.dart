import 'dart:convert';

import 'package:flutter/foundation.dart';

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

void _logPaymentHttp({
  required String tag,
  required String method,
  required String url,
  required Map<String, String> headers,
  required String body,
  Map<String, dynamic>? bodyMap,
}) {
  if (!kDebugMode) return;

  final encoder = const JsonEncoder.withIndent('  ');
  final safeHeaders = headers.map((key, value) {
    if (key.toLowerCase() == 'authorization' && value.length > 16) {
      return MapEntry(key, '${value.substring(0, 14)}…(${value.length} chars)');
    }
    return MapEntry(key, value);
  });

  debugPrint('');
  debugPrint('══════════════════════════════════════════════════════');
  debugPrint('[$tag] $method $url');
  debugPrint('── Headers ──');
  debugPrint(encoder.convert(safeHeaders));
  if (bodyMap != null) {
    debugPrint('── Body (map) ──');
    debugPrint(encoder.convert(bodyMap));
  }
  debugPrint('── Body (wire) ──');
  debugPrint(body);
  debugPrint('══════════════════════════════════════════════════════');
}

void _logPaymentHttpResponse({
  required String tag,
  required int statusCode,
  required String body,
}) {
  if (!kDebugMode) return;

  debugPrint('[$tag] ← HTTP $statusCode');
  debugPrint('── Response body ──');
  debugPrint(body.isEmpty ? '(empty)' : body);
  debugPrint('══════════════════════════════════════════════════════');
  debugPrint('');
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  @override
  Future<CategoryFetchResult> submitExpressPayment({
    required Map<String, dynamic> params,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final url = ApiConfig.getEndpointUrl(ApiConfig.expressPayment);
      final bodyMap = params.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
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

      _logPaymentHttp(
        tag: 'EXPRESS PAYMENT SUBMIT',
        method: 'POST',
        url: url,
        headers: formHeaders,
        body: formBody,
        bodyMap: bodyMap,
      );

      final response = await HttpClientService.post(
        Uri.parse(url),
        headers: formHeaders,
        body: formBody,
      ).timeout(timeout);

      _logPaymentHttpResponse(
        tag: 'EXPRESS PAYMENT SUBMIT',
        statusCode: response.statusCode,
        body: response.body,
      );

      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EXPRESS PAYMENT SUBMIT] ✗ Error: $e');
      }
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
      final url = ApiConfig.getEndpointUrl(ApiConfig.checkPayment);
      final jsonBody = jsonEncode(body);

      _logPaymentHttp(
        tag: 'CHECK PAYMENT',
        method: 'POST',
        url: url,
        headers: headers,
        body: jsonBody,
        bodyMap: body,
      );

      final response = await HttpClientService.post(
        Uri.parse(url),
        headers: headers,
        body: jsonBody,
      ).timeout(timeout);

      _logPaymentHttpResponse(
        tag: 'CHECK PAYMENT',
        statusCode: response.statusCode,
        body: response.body,
      );

      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CHECK PAYMENT] ✗ Error: $e');
      }
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
