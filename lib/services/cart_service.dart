import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/category_fetch_result.dart';
import '../repositories/cart_repository.dart';
import '../utils/app_error_utils.dart';
import 'auth_service.dart';

class CartService {
  CartService({CartRepository? repository})
      : _repository = repository ?? CartRepositoryImpl();

  final CartRepository _repository;

  static const Duration cartHttpTimeout = Duration(seconds: 12);

  static bool isSuccessStatus(int statusCode) =>
      statusCode == 200 || statusCode == 201;

  static Map<String, dynamic>? decodeBody(CategoryFetchResult result) {
    if (result.body != null) return result.body;
    return AppErrorUtils.tryDecodeJsonMap(result.rawBody ?? '');
  }

  static Map<String, String> cartAuthHeaders(String token, bool isLoggedIn) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (isLoggedIn) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['Authorization'] = 'Guest $token';
      headers['X-Guest-ID'] = token;
    }
    return headers;
  }

  static Future<Map<String, String>?> resolveSyncAuthHeaders() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();
    if (token != null) {
      if (isLoggedIn) {
        return cartAuthHeaders(token, true);
      }
      if (token.startsWith('guest')) {
        return cartAuthHeaders(token, false);
      }
      return null;
    }
    return null;
  }

  static Future<Map<String, String>?> resolveGuestOrUserTokenHeaders() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();
    if (token == null && !isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('guest_id');
    }
    if (token == null) return null;
    return cartAuthHeaders(token, isLoggedIn);
  }

  void logCartApiResponse({
    required String label,
    required String url,
    Map<String, String>? headers,
    String? requestBody,
    required CategoryFetchResult result,
  }) {
    debugPrint('=== $label ===');
    debugPrint('URL: $url');
    if (requestBody != null) debugPrint('Request Body: $requestBody');
    if (headers != null) debugPrint('Request Headers: $headers');
    debugPrint('Response Status: ${result.statusCode}');
    debugPrint('Response Body: ${result.rawBody}');
    debugPrint('================================');
  }

  Future<CategoryFetchResult> fetchLoggedInCart({
    required String hashedLink,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _repository.fetchCheckoutCart(
        hashedLink: hashedLink,
        headers: headers,
        timeout: timeout,
      );

  /// Resolves the `/check-out/{link}` segment (guest_id or hashed_link).
  static Future<String?> resolveCheckoutLink({
    required String token,
    required bool isLoggedIn,
  }) async {
    if (isLoggedIn) {
      return AuthService.getHashedLink();
    }
    return token;
  }

  /// Loads the current cart via `GET /check-out/{link}`.
  Future<CategoryFetchResult> fetchCartSnapshot({
    required String checkoutLink,
    required Map<String, String> headers,
    Duration timeout = cartHttpTimeout,
  }) =>
      _repository.fetchCheckoutCart(
        hashedLink: checkoutLink,
        headers: headers,
        timeout: timeout,
      );

  Future<CategoryFetchResult> checkAuth({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = cartHttpTimeout,
  }) =>
      _repository.postCheckAuth(
        headers: headers,
        body: jsonEncode(body),
        timeout: timeout,
      );

  Future<CategoryFetchResult> checkAuthWithProductCandidates({
    required Map<String, String> headers,
    required List<int> productIds,
    required int quantity,
    String? batchNo,
    Duration timeout = cartHttpTimeout,
    void Function({
      required String url,
      required Map<String, String> headers,
      required String requestBody,
      required CategoryFetchResult result,
    })? onAttempt,
  }) async {
    final url = ApiConfig.getEndpointUrl(ApiConfig.checkAuth);
    CategoryFetchResult? lastResult;

    const maxTransientRetries = 2;

    for (final productId in productIds) {
      final requestBody = <String, dynamic>{
        'productID': productId,
        'quantity': quantity > 0 ? quantity : 1,
      };
      if (batchNo != null && batchNo.isNotEmpty) {
        requestBody['batch_no'] = batchNo;
      }
      final encoded = jsonEncode(requestBody);

      for (var attempt = 0; attempt <= maxTransientRetries; attempt++) {
        final result = await _repository.postCheckAuth(
          headers: headers,
          body: encoded,
          timeout: timeout,
        );
        lastResult = result;
        onAttempt?.call(
          url: url,
          headers: headers,
          requestBody: encoded,
          result: result,
        );
        if (isSuccessStatus(result.statusCode)) {
          return result;
        }
        if (result.statusCode == 404) {
          debugPrint(
            '⚠️ productID $productId not found (404), trying next id...',
          );
          break;
        }
        final transient = result.statusCode == 0;
        if (transient && attempt < maxTransientRetries) {
          final delayMs = 350 * (attempt + 1);
          debugPrint(
            '⚠️ check-auth transient failure (status 0), retry in ${delayMs}ms',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        return result;
      }
    }

    return lastResult ??
        CategoryFetchResult(statusCode: 0, error: StateError('No product ids'));
  }

  Future<CategoryFetchResult> removeCartLine({
    required Map<String, String> headers,
    required String cartLineId,
    Duration timeout = cartHttpTimeout,
  }) =>
      _repository.postRemoveFromCart(
        headers: headers,
        body: jsonEncode({'cart_id': cartLineId}),
        timeout: timeout,
      );

  Future<CategoryFetchResult> deleteCheckoutItem({
    required Map<String, String> headers,
    required String itemId,
    Duration timeout = const Duration(seconds: 3),
  }) =>
      _repository.deleteCheckoutItem(
        itemId: itemId,
        headers: headers,
        timeout: timeout,
      );

  Future<bool> syncCartPayload({
    required Map<String, dynamic> cartData,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (isLoggedIn) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['Authorization'] = 'Guest $token';
      headers['X-Guest-ID'] = token;
    }

    final result = await _repository.syncCart(
      headers: headers,
      body: jsonEncode(cartData),
      timeout: timeout,
    );
    if (result.statusCode != 200) return false;
    final data = decodeBody(result);
    return data?['success'] == true;
  }
}
