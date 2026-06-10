import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../database/payment/payment_remote_data_source.dart';
import '../../repositories/payment_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/order_steps_api_logger.dart';
import '../../services/order_history_transformer.dart';
import '../../models/order_tracking_model.dart';
import '../../services/order_tracking_service.dart';

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
  Future<String?> fetchOrderStatus(String orderId) async {
    if (orderId.isEmpty) return null;
    final result = await AuthService.getOrders();
    if (result['status'] != 'success' || result['data'] is! List) {
      return null;
    }
    return _statusFromOrdersList(
      result['data'] as List,
      requestedIds: {orderId},
    );
  }

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
      return null;
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

    final rowMaps = matchedRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final furthestStatus = OrderTrackingService().pickFurthestRawStatus(
      rowMaps,
      fallback: merged['status']?.toString(),
    );
    if (furthestStatus.isNotEmpty) {
      merged['status'] = furthestStatus;
    }

    final mergedHistory = <Map<String, dynamic>>[];
    for (final row in rowMaps) {
      final history = row['status_history'] ?? row['order_status_history'];
      if (history is! List) continue;
      for (final item in history) {
        if (item is Map) {
          mergedHistory.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (mergedHistory.isNotEmpty) {
      merged['status_history'] = mergedHistory;
    }

    OrderStepsApiLogger.logSnapshotStageFields(
      'fetchLatestOrderSnapshot',
      snapshot: merged,
    );

    return merged;
  }

  /// Reads status from GET /orders rows (per-order status route is not deployed).
  String? _statusFromOrdersList(
    List orders, {
    required Set<String> requestedIds,
  }) {
    if (requestedIds.isEmpty) return null;

    for (final item in orders) {
      if (item is! Map) continue;
      final order = Map<String, dynamic>.from(item);
      final candidateIds = <String>{
        order['delivery_id']?.toString() ?? '',
        order['transaction_id']?.toString() ?? '',
        order['id']?.toString() ?? '',
        order['order_number']?.toString() ?? '',
        order['order_id']?.toString() ?? '',
      }..removeWhere((value) => value.isEmpty);

      if (candidateIds.intersection(requestedIds).isNotEmpty) {
        final status = order['status']?.toString();
        if (status != null && status.isNotEmpty) return status;
      }
    }
    return null;
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
