import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../database/payment/payment_remote_data_source.dart';
import '../../models/category_fetch_result.dart';
import '../../repositories/payment_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/app_error_utils.dart';
import '../../services/order_history_transformer.dart';
import '../../models/order_tracking_model.dart';

abstract class OrderTrackingRemoteDataSource {
  Future<PaymentStatusResult> checkPaymentStatus();
  Future<String?> fetchOrderStatus(String orderId);
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
    String? checkoutOrderId,
  });
}

class OrderTrackingRemoteDataSourceImpl
    implements OrderTrackingRemoteDataSource {
  OrderTrackingRemoteDataSourceImpl({PaymentRepository? paymentRepository})
      : _paymentRepository = paymentRepository ?? PaymentRepositoryImpl();

  final PaymentRepository _paymentRepository;

  @override
  Future<PaymentStatusResult> checkPaymentStatus() async {
    try {
      final headers = await buildCheckoutAuthHeaders();
      if (!headers.containsKey('Authorization')) {
        return const PaymentStatusResult(
          status: 'error',
          message: 'Unable to verify payment right now.',
        );
      }

      final requestBody = await buildCheckPaymentBody();
      final result = await _paymentRepository.checkPayment(
        headers: headers,
        body: requestBody,
        timeout: const Duration(seconds: 15),
      );

      if (result.error != null) {
        throw result.error!;
      }

      print(
        '[CHECK STATUS BUTTON] Raw API response: statusCode=${result.statusCode}, body=${result.rawBody}',
      );

      if (result.statusCode == 200) {
        final rawBody = result.rawBody?.trim() ?? '';
        if (rawBody.isEmpty) {
          print('[CHECK STATUS BUTTON] Empty response body from API');
          return const PaymentStatusResult(
            status: 'pending',
            message: 'Waiting for payment confirmation...',
            isEmptyResponse: true,
          );
        }

        if (result.body == null) {
          print('[CHECK STATUS BUTTON] Unparseable JSON; treating as pending');
          return const PaymentStatusResult(
            status: 'pending',
            message: 'Waiting for payment confirmation...',
            isEmptyResponse: true,
          );
        }

        final payload = _normalizePaymentPayload(result.body!);
        print('[CHECK STATUS BUTTON] Decoded payload: $payload');
        return _mapPaymentStatus(payload);
      }

      if (result.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      }
      if (result.statusCode == 403) {
        throw Exception('You do not have permission to check payment status.');
      }
      if (result.statusCode == 404) {
        throw Exception('Payment record not found. Please contact support.');
      }
      if (result.statusCode >= 500) {
        throw Exception(AppErrorUtils.oopsTryAgainMessage);
      }

      throw Exception('Failed to verify payment: ${result.statusCode}');
    } on SocketException {
      throw Exception(
        'No internet connection. Please check your network and try again.',
      );
    } on http.ClientException {
      throw Exception('Unable to reach the payment server right now.');
    } on Exception catch (e) {
      final message = e.toString();
      if (message.contains('Session expired') ||
          message.contains('Unable to verify payment')) {
        return PaymentStatusResult(
          status: 'error',
          message: message.replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }
  }

  @override
  Future<String?> fetchOrderStatus(String orderId) =>
      _fetchDirectStatus(orderId);

  @override
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
    String? checkoutOrderId,
  }) async {
    final result = await AuthService.getOrders();
    if (result['status'] != 'success' || result['data'] is! List) {
      return null;
    }

    final orders = result['data'] as List;
    final directStatus = await _fetchDirectStatus(
        _pickLookupId(orderId, orderNumber, transactionId));

    final requestedIds = <String>{
      orderId,
      orderNumber,
      transactionId,
      if (checkoutOrderId != null && checkoutOrderId.isNotEmpty)
        checkoutOrderId,
    }..removeWhere((value) => value.isEmpty);

    final matchedRows = <dynamic>[];
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

      if (candidateIds.intersection(requestedIds).isNotEmpty) {
        matchedRows.add(order);
      }
    }

    if (matchedRows.isEmpty) {
      return directStatus == null ? null : {'status': directStatus};
    }

    final mergeKey = transactionId.isNotEmpty
        ? transactionId
        : OrderHistoryTransformer.getTransactionId(matchedRows.first);

    final Map<String, dynamic> merged = matchedRows.length == 1
        ? OrderHistoryTransformer.processSingleOrder(
            matchedRows.first,
            mergeKey,
          )
        : OrderHistoryTransformer.processMultiOrder(matchedRows, mergeKey);

    if (directStatus != null && directStatus.isNotEmpty) {
      merged['status'] = directStatus;
    }

    return merged;
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
        Uri.parse(ApiConfig.getOrderStatusUrl(orderId)),
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
    final parsed = CategoryFetchResult.fromResponse(200, responseBody);
    if (parsed.body != null) {
      return parsed.body!;
    }
    var body = responseBody.trim();
    final jsonStart = body.indexOf('{');
    if (jsonStart != -1) {
      body = body.substring(jsonStart);
    }
    return Map<String, dynamic>.from(json.decode(body) as Map);
  }

  /// Flattens `{ data: { status, transaction_id, ... } }` and similar API shapes.
  Map<String, dynamic> _normalizePaymentPayload(Map<String, dynamic> data) {
    final nested = data['data'];
    if (nested is! Map) {
      return data;
    }

    final inner = Map<String, dynamic>.from(nested);
    final status = inner['status'] ??
        inner['payment_status'] ??
        inner['order_status'] ??
        data['status'] ??
        data['payment_status'];
    final transactionId =
        inner['transaction_id'] ?? data['transaction_id'];

    return {
      ...data,
      ...inner,
      if (status != null) 'status': status,
      if (transactionId != null) 'transaction_id': transactionId,
    };
  }

  PaymentStatusResult _mapPaymentStatus(Map<String, dynamic> data) {
    final rawStatus = data['status']?.toString() ??
        data['payment_status']?.toString() ??
        '';
    final status = rawStatus.toLowerCase();

    if (status.isEmpty && data['success'] == true) {
      return PaymentStatusResult(
        status: 'success',
        message: 'Payment completed successfully',
        transactionId: data['transaction_id']?.toString(),
        rawStatus: 'success',
      );
    }

    if (status.contains('completed') ||
        status.contains('success') ||
        status.contains('payment completed')) {
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
