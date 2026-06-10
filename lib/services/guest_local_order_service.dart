import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/guest_recent_order.dart';
import '../models/order_tracking_model.dart';
import 'auth_service.dart';
import 'guest_recent_order_service.dart';

/// Guest workaround while GET /orders does not support guest auth on the backend.
/// Serves order rows from device storage only (checkout snapshot + payment state).
class GuestLocalOrderService {
  GuestLocalOrderService._();

  static final GuestLocalOrderService instance = GuestLocalOrderService._();

  static const String _userOrdersKey = 'user_orders';

  static Future<bool> isGuestSession() => AuthService.isLoggedIn().then((v) => !v);

  Future<Map<String, dynamic>> buildOrdersResponse() async {
    final rows = await loadAllOrderRows();
    return {
      'status': 'success',
      'data': rows,
      'message': 'Guest orders loaded from this device',
      'guest_orders_local_only': true,
    };
  }

  Future<List<Map<String, dynamic>>> loadAllOrderRows() async {
    final byKey = <String, Map<String, dynamic>>{};

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userOrdersKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final row = Map<String, dynamic>.from(item);
            final key = _rowKey(row);
            if (key.isNotEmpty) byKey[key] = row;
          }
        }
      }
    } catch (e, st) {
      debugPrint('GuestLocalOrderService.loadAllOrderRows prefs: $e\n$st');
    }

    final recent = await GuestRecentOrderService.instance.loadRecentOrder();
    if (recent != null && recent.initialTransactionId.isNotEmpty) {
      final key = recent.initialTransactionId;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = recent.toOrderSnapshot();
      } else {
        byKey[key] = {
          ...recent.toOrderSnapshot(
            status: existing['status']?.toString() ?? recent.initialStatus,
          ),
          ...existing,
        };
      }
    }

    final rows = byKey.values.toList();
    rows.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final dateB =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    return rows;
  }

  Future<Map<String, dynamic>?> findMatchingSnapshot(
    Set<String> requestedIds,
  ) async {
    if (requestedIds.isEmpty) return null;

    for (final row in await loadAllOrderRows()) {
      final candidateIds = <String>{
        row['delivery_id']?.toString() ?? '',
        row['transaction_id']?.toString() ?? '',
        row['id']?.toString() ?? '',
        row['order_number']?.toString() ?? '',
        row['order_id']?.toString() ?? '',
      }..removeWhere((value) => value.isEmpty);

      if (candidateIds.intersection(requestedIds).isNotEmpty) {
        return row;
      }
    }
    return null;
  }

  Future<void> syncFromOrder(OrderTrackingModel order) async {
    final txId = order.transactionId.trim();
    if (txId.isEmpty) return;

    await _upsertRow({
      'id': order.orderId.isNotEmpty ? order.orderId : txId,
      'delivery_id': txId,
      'transaction_id': txId,
      'order_number':
          order.orderNumber.isNotEmpty ? order.orderNumber : txId,
      'status': order.rawStatus,
      'order_status': order.rawStatus,
      'total_amount': order.totalAmount.toStringAsFixed(2),
      'total': order.totalAmount,
      'payment_method': order.paymentMethod,
      'contact_number': order.contactNumber,
      'phone': order.contactNumber,
      'email': _emailFromPaymentParams(order.paymentParams),
      'delivery_address': order.deliveryAddress,
      'delivery_option': order.deliveryOption,
      'estimated_delivery_time': order.estimatedDeliveryTime,
      'discount': order.discount,
      'delivery_fee': order.deliveryFee,
      'created_at': order.createdAt.toIso8601String(),
      'items': order.items.map((item) => item.toMap()).toList(),
      'order_items': order.items.map((item) => item.toMap()).toList(),
    });

    await GuestRecentOrderService.instance.saveFromOrderTracking(order: order);
  }

  Future<void> _upsertRow(Map<String, dynamic> row) async {
    final key = _rowKey(row);
    if (key.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final byId = <String, Map<String, dynamic>>{};
      final raw = prefs.getString(_userOrdersKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final existing = Map<String, dynamic>.from(item);
            final existingKey = _rowKey(existing);
            if (existingKey.isNotEmpty) byId[existingKey] = existing;
          }
        }
      }

      byId[key] = {...?byId[key], ...row};
      await prefs.setString(
        _userOrdersKey,
        json.encode(byId.values.toList()),
      );
    } catch (e, st) {
      debugPrint('GuestLocalOrderService._upsertRow failed: $e\n$st');
    }
  }

  static String _rowKey(Map<String, dynamic> row) {
    return row['delivery_id']?.toString() ??
        row['transaction_id']?.toString() ??
        row['id']?.toString() ??
        row['order_number']?.toString() ??
        '';
  }
}

String? _emailFromPaymentParams(Map<String, dynamic> params) {
  for (final key in ['email', 'user_email', 'guest_email', 'customer_email']) {
    final value = params[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

extension GuestRecentOrderSnapshot on GuestRecentOrder {
  Map<String, dynamic> toOrderSnapshot({String? status}) {
    final txId = initialTransactionId;
    final resolvedStatus = status ?? initialStatus;
    return {
      'id': txId,
      'delivery_id': txId,
      'transaction_id': txId,
      'order_number': txId,
      'status': resolvedStatus,
      'order_status': resolvedStatus,
      'payment_method': paymentMethod,
      'contact_number': contactNumber,
      'phone': contactNumber,
      'email': _emailFromPaymentParams(paymentParams),
      'delivery_address': deliveryAddress,
      'delivery_option': deliveryOption,
      'estimated_delivery_time': estimatedDeliveryTime,
      'total_amount': paymentParams['amount']?.toString() ?? '',
      'total': paymentParams['amount'],
      'discount': discount,
      'delivery_fee': deliveryFee,
      'guest_id': guestId,
      'created_at':
          DateTime.fromMillisecondsSinceEpoch(savedAtMs).toIso8601String(),
      'items': purchasedItems,
      'order_items': purchasedItems,
    };
  }
}
