import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../models/order_tracking_model.dart';

abstract class OrderTrackingRemoteDataSource {
  Future<PaymentStatusResult> checkPaymentStatus();
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
  });
}

class OrderTrackingRemoteDataSourceImpl
    implements OrderTrackingRemoteDataSource {
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';

  @override
  Future<PaymentStatusResult> checkPaymentStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      final tokenRaw = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      String? authHeader;
      Map<String, dynamic> requestBody = {};

      if (isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
        authHeader = 'Bearer $tokenRaw';
        if (userId == null) {
          return const PaymentStatusResult(
            status: 'error',
            message: 'Session expired. Please log in again.',
          );
        }
        requestBody = {'user_id': userId};
      } else if (!isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
        authHeader = 'Guest $tokenRaw';
        requestBody = {'guest_id': tokenRaw};
      } else {
        return const PaymentStatusResult(
          status: 'error',
          message: 'Unable to verify payment right now.',
        );
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      };

      if (!isLoggedIn && tokenRaw.isNotEmpty) {
        headers['X-Guest-ID'] = tokenRaw;
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/check-payment'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return const PaymentStatusResult(
            status: 'pending',
            message: 'Waiting for payment confirmation...',
            isEmptyResponse: true,
          );
        }

        final payload = _decodeResponse(response.body);
        return _mapPaymentStatus(payload);
      }

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      }
      if (response.statusCode == 403) {
        throw Exception('You do not have permission to check payment status.');
      }
      if (response.statusCode == 404) {
        throw Exception('Payment record not found. Please contact support.');
      }
      if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      }

      throw Exception('Failed to verify payment: ${response.statusCode}');
    } on SocketException {
      throw Exception(
        'No internet connection. Please check your network and try again.',
      );
    } on FormatException {
      throw Exception('Invalid response format from server. Please try again.');
    } on http.ClientException {
      throw Exception('Unable to reach the payment server right now.');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
  }) async {
    final result = await AuthService.getOrders();
    if (result['status'] != 'success' || result['data'] is! List) {
      return null;
    }

    final orders = result['data'] as List;
    final directStatus = await _fetchDirectStatus(
        _pickLookupId(orderId, orderNumber, transactionId));

    Map<String, dynamic>? matchedOrder;
    for (final item in orders) {
      if (item is! Map) {
        continue;
      }

      final order = Map<String, dynamic>.from(item);
      final candidateIds = <String>{
        order['id']?.toString() ?? '',
        order['order_number']?.toString() ?? '',
        order['transaction_id']?.toString() ?? '',
        order['delivery_id']?.toString() ?? '',
      }..removeWhere((value) => value.isEmpty);

      final requestedIds = <String>{orderId, orderNumber, transactionId}
        ..removeWhere((value) => value.isEmpty);

      if (candidateIds.intersection(requestedIds).isNotEmpty) {
        matchedOrder = order;
        break;
      }
    }

    if (matchedOrder == null) {
      return directStatus == null ? null : {'status': directStatus};
    }

    if (directStatus != null && directStatus.isNotEmpty) {
      matchedOrder['status'] = directStatus;
    }

    return matchedOrder;
  }

  String _pickLookupId(
      String orderId, String orderNumber, String transactionId) {
    if (transactionId.isNotEmpty) {
      return transactionId;
    }
    if (orderId.isNotEmpty) {
      return orderId;
    }
    return orderNumber;
  }

  Future<String?> _fetchDirectStatus(String orderId) async {
    if (orderId.isEmpty) {
      return null;
    }

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final data = _decodeResponse(response.body);
      return data['status']?.toString() ?? data['data']?['status']?.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeResponse(String responseBody) {
    var body = responseBody.trim();
    final jsonStart = body.indexOf('{');
    if (jsonStart != -1) {
      body = body.substring(jsonStart);
    }
    return Map<String, dynamic>.from(json.decode(body) as Map);
  }

  PaymentStatusResult _mapPaymentStatus(Map<String, dynamic> data) {
    final rawStatus = data['status']?.toString() ?? '';
    final status = rawStatus.toLowerCase();

    if (status.contains('completed') || status.contains('success')) {
      return PaymentStatusResult(
        status: 'success',
        message: 'Payment completed successfully',
        transactionId: data['transaction_id']?.toString(),
        rawStatus: rawStatus,
      );
    }

    if (status.contains('declined') || status.contains('failed')) {
      return PaymentStatusResult(
        status: 'failed',
        message: 'Payment was declined. Please try another method.',
        transactionId: data['transaction_id']?.toString(),
        rawStatus: rawStatus,
      );
    }

    if (status.contains('pending') || status.contains('processing')) {
      return PaymentStatusResult(
        status: 'pending',
        message: 'Payment is being processed. Please wait...',
        transactionId: data['transaction_id']?.toString(),
        rawStatus: rawStatus,
      );
    }

    return PaymentStatusResult(
      status: 'pending',
      message: 'Payment status is being processed',
      transactionId: data['transaction_id']?.toString(),
      rawStatus: rawStatus,
    );
  }
}
