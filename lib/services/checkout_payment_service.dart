import '../database/payment/payment_remote_data_source.dart';
import '../models/category_fetch_result.dart';
import '../repositories/payment_repository.dart';
import '../services/auth_service.dart';

export '../database/payment/payment_remote_data_source.dart'
    show buildCheckoutAuthHeaders, buildCheckPaymentBody;

import '../utils/express_pay_api_log.dart';

class CheckoutPaymentService {
  CheckoutPaymentService({PaymentRepository? repository})
      : _repository = repository ?? PaymentRepositoryImpl();

  final PaymentRepository _repository;

  Future<String> submitExpressPayment({
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final headers = await buildCheckoutAuthHeaders();
    if (!headers.containsKey('Authorization')) {
      throw Exception(
        'You must be logged in or have a guest session to use online payment.',
      );
    }

    final result = await _repository.submitExpressPayment(
      params: params,
      headers: headers,
      timeout: timeout,
    );
    _rethrowTransportError(result);

    final rawBody = result.rawBody ?? result.body?.toString() ?? '';
    ExpressPayApiLog.message(
      'POST /expresspayment raw response: '
      '${rawBody.length > 500 ? '${rawBody.substring(0, 500)}…' : rawBody}',
    );
    if (rawBody.trim().isEmpty) {
      throw Exception(
        'Could not read a payment page URL from the server. Please try again.',
      );
    }
    return rawBody;
  }

  Future<Map<String, dynamic>> verifyPayment({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final headers = await buildCheckoutAuthHeaders();
      final body = await buildCheckPaymentBody();
      final result = await _repository.checkPayment(
        headers: headers,
        body: body,
        timeout: timeout,
      );
      _rethrowTransportError(result);

      if (result.statusCode == 200 && result.body != null) {
        final data = result.body!;
        return {
          'verified': true,
          'status': data['status'] ?? 'success',
          'message': data['message'] ?? 'Payment verified successfully',
        };
      }
      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification failed',
      };
    } catch (e) {
      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> checkPaymentStatus({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = await buildCheckoutAuthHeaders();
    final body = await buildCheckPaymentBody();
    final result = await _repository.checkPayment(
      headers: headers,
      body: body,
      timeout: timeout,
    );
    _rethrowTransportError(result);

    if (result.statusCode == 200) {
      if (result.body == null || result.body!.isEmpty) {
        return {'status': 'pending', 'message': ''};
      }
      return Map<String, dynamic>.from(result.body!);
    }
    return {'status': 'error', 'message': ''};
  }

  Future<Map<String, dynamic>> applyCoupon({
    required String promoCode,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final token = await AuthService.getToken();
    final headers = await buildCheckoutAuthHeaders();
    final requestBody = <String, dynamic>{'coupon': promoCode};

    if (!isLoggedIn && token != null && token.isNotEmpty) {
      requestBody['guest_id'] = token;
    }
    if (!headers.containsKey('Authorization')) {
      throw Exception(
        'You must be logged in or have a guest session to apply a coupon.',
      );
    }

    final result = await _repository.applyCoupon(
      headers: headers,
      body: requestBody,
      timeout: timeout,
    );
    _rethrowTransportError(result);
    return {
      'statusCode': result.statusCode,
      'body': result.body ?? const {},
    };
  }

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
