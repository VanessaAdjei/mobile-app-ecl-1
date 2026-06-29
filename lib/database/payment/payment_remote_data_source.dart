import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/checkout_log.dart';
import '../../utils/express_pay_api_log.dart';

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
  if (bodyMap != null) {
    checkoutLog('[$tag] $method $url body=$bodyMap');
  } else {
    checkoutLog('[$tag] $method $url');
  }
}

void _logPaymentHttpResponse({
  required String tag,
  required int statusCode,
  required String body,
  String? method,
  String? url,
  Map<String, dynamic>? request,
}) {
  if (tag.contains('expresspayment') ||
      tag.contains('check-payment') ||
      tag.contains('EXPRESS') ||
      tag.contains('CHECK PAYMENT')) {
    ExpressPayApiLog.exchange(
      step: tag,
      method: method ?? 'POST',
      url: url ?? '',
      request: request,
      statusCode: statusCode,
      responseBody: body,
    );
    return;
  }
  checkoutLog('[$tag] ← HTTP $statusCode');
  if (body.trim().isNotEmpty) {
    checkoutLog('[$tag] body=$body');
  }
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

      // Preserve numeric types in JSON (e.g. deliveryFee: 20.0) so backends
      // that bind typed fields get both string and number representations.
      final jsonHeaders = <String, String>{
        ...headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final jsonBody = jsonEncode(params);

      _logPaymentHttp(
        tag: 'EXPRESS PAYMENT SUBMIT',
        method: 'POST',
        url: url,
        headers: jsonHeaders,
        body: jsonBody,
        bodyMap: params,
      );

      var response = await HttpClientService.post(
        Uri.parse(url),
        headers: jsonHeaders,
        body: jsonBody,
      ).timeout(timeout);

      // Some Laravel handlers only bind form fields — retry once if JSON is rejected.
      if (response.statusCode == 415 ||
          (response.statusCode == 422 && response.body.contains('amount'))) {
        final formBody = params.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
            )
            .join('&');
        final formHeaders = <String, String>{
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        };
        if (kDebugMode) {
          debugPrint(
            '[EXPRESS PAYMENT SUBMIT] JSON rejected (${response.statusCode}), '
            'retrying as form-urlencoded',
          );
        }
        _logPaymentHttp(
          tag: 'EXPRESS PAYMENT SUBMIT (form fallback)',
          method: 'POST',
          url: url,
          headers: formHeaders,
          body: formBody,
          bodyMap: params,
        );
        response = await HttpClientService.post(
          Uri.parse(url),
          headers: formHeaders,
          body: formBody,
        ).timeout(timeout);
      }

      _logPaymentHttpResponse(
        tag: 'POST /expresspayment',
        statusCode: response.statusCode,
        body: response.body,
        method: 'POST',
        url: url,
        request: params,
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
        tag: 'POST /check-payment',
        statusCode: response.statusCode,
        body: response.body,
        method: 'POST',
        url: url,
        request: body,
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
