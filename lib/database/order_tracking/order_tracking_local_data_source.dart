import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order_tracking_model.dart';
import '../../services/order_notification_service.dart';
import '../../utils/order_timestamp_parser.dart';

abstract class OrderTrackingLocalDataSource {
  Future<void> storeOrderAmounts({
    required OrderTrackingModel order,
    String? initialTransactionId,
  });

  Future<void> createOrderPlacedNotification(
    OrderTrackingModel order, {
    bool isGuestCheckout = false,
  });

  Future<Map<String, DateTime>> loadStageTimestamps(String orderKey);

  Future<void> recordStageTimestampIfAbsent(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  );

  Future<void> upsertStageTimestamp(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  );

  Future<void> saveStageTimestamps(
    String orderKey,
    Map<String, DateTime> timestamps,
  );

  Future<int> loadHighestTimelineIndex(String orderKey);

  Future<void> saveHighestTimelineIndexIfHigher(
    String orderKey,
    int timelineIndex,
  );

  Future<void> saveStatusHint({
    required String status,
    String? orderId,
    String? orderNumber,
    String? transactionId,
  });

  Future<List<String>> loadStatusHints(Set<String> lookupKeys);
}

class OrderTrackingLocalDataSourceImpl implements OrderTrackingLocalDataSource {
  @override
  Future<void> storeOrderAmounts({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) async {
    final orderId = order.transactionId;
    if (orderId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('order_total_$orderId', order.totalAmount);

    if (initialTransactionId != null &&
        initialTransactionId.isNotEmpty &&
        initialTransactionId != orderId) {
      await prefs.setDouble(
        'order_total_$initialTransactionId',
        order.totalAmount,
      );
    }
  }

  @override
  Future<void> createOrderPlacedNotification(
    OrderTrackingModel order, {
    bool isGuestCheckout = false,
  }) async {
    final orderData = {
      'id': order.orderId.isNotEmpty ? order.orderId : order.transactionId,
      'transaction_id': order.transactionId,
      'order_number':
          order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId,
      'total_amount': order.totalAmount.toStringAsFixed(2),
      'status': order.stageLabel,
      'payment_method': order.paymentMethod,
      'contact_number': order.contactNumber,
      'email': _emailFromPaymentParams(order.paymentParams),
      'items': order.items
          .map((item) => {
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'imageUrl': item.imageUrl,
                'batchNo': item.batchNo,
              })
          .toList(),
      'created_at': order.createdAt.toIso8601String(),
    };

    if (isGuestCheckout) {
      await OrderNotificationService.createGuestOrderPlacedNotification(
        orderData,
      );
      return;
    }

    await OrderNotificationService.createOrderPlacedNotification(orderData);
  }

  static String? _emailFromPaymentParams(Map<String, dynamic> params) {
    for (final key in ['email', 'user_email', 'guest_email', 'customer_email']) {
      final value = params[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _stageTimestampsKey(String orderKey) =>
      'order_stage_ts_$orderKey';

  @override
  Future<Map<String, DateTime>> loadStageTimestamps(String orderKey) async {
    if (orderKey.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stageTimestampsKey(orderKey));
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final parsed = parseOrderTimestamp(entry.value);
        if (parsed != null) {
          result[entry.key.toString()] = parsed;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> recordStageTimestampIfAbsent(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  ) async {
    if (orderKey.isEmpty || stageId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _stageTimestampsKey(orderKey);
    final existing = await loadStageTimestamps(orderKey);
    if (existing.containsKey(stageId)) return;

    existing[stageId] = occurredAt;
    final encoded = json.encode(
      existing.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await prefs.setString(key, encoded);
  }

  @override
  Future<void> upsertStageTimestamp(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  ) async {
    if (orderKey.isEmpty || stageId.isEmpty) return;
    final existing = await loadStageTimestamps(orderKey);
    existing[stageId] = occurredAt.toLocal();
    await saveStageTimestamps(orderKey, existing);
  }

  @override
  Future<void> saveStageTimestamps(
    String orderKey,
    Map<String, DateTime> timestamps,
  ) async {
    if (orderKey.isEmpty || timestamps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      timestamps.map(
        (k, v) => MapEntry(k, v.toLocal().toIso8601String()),
      ),
    );
    await prefs.setString(_stageTimestampsKey(orderKey), encoded);
  }

  static String _highestTimelineIndexKey(String orderKey) =>
      'order_highest_tl_idx_$orderKey';

  static String _statusHintKey(String orderKey) => 'order_status_hint_$orderKey';

  @override
  Future<void> saveStatusHint({
    required String status,
    String? orderId,
    String? orderNumber,
    String? transactionId,
  }) async {
    final trimmed = status.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = <String>{
      if (orderId != null) orderId.trim(),
      if (orderNumber != null) orderNumber.trim(),
      if (transactionId != null) transactionId.trim(),
    }..removeWhere((value) => value.isEmpty);

    for (final key in keys) {
      await prefs.setString(_statusHintKey(key), trimmed);
    }
  }

  @override
  Future<List<String>> loadStatusHints(Set<String> lookupKeys) async {
    if (lookupKeys.isEmpty) return const [];

    final prefs = await SharedPreferences.getInstance();
    final hints = <String>{};
    for (final key in lookupKeys) {
      final hint = prefs.getString(_statusHintKey(key))?.trim();
      if (hint != null && hint.isNotEmpty) {
        hints.add(hint);
      }
    }
    return hints.toList(growable: false);
  }

  @override
  Future<int> loadHighestTimelineIndex(String orderKey) async {
    if (orderKey.isEmpty) return -1;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highestTimelineIndexKey(orderKey)) ?? -1;
  }

  @override
  Future<void> saveHighestTimelineIndexIfHigher(
    String orderKey,
    int timelineIndex,
  ) async {
    if (orderKey.isEmpty || timelineIndex < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _highestTimelineIndexKey(orderKey);
    final existing = prefs.getInt(key) ?? -1;
    if (timelineIndex > existing) {
      await prefs.setInt(key, timelineIndex);
    }
  }
}
