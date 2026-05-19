// services/order_history_transformer.dart
// Groups and normalizes order rows from [AuthService.getOrders] — same pipeline as Purchases.

import 'package:flutter/foundation.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

/// Shared between [PurchaseScreen] and wallet transaction history.
class OrderHistoryTransformer {
  OrderHistoryTransformer._();

  static bool isCashOnDelivery(String paymentMethod) {
    if (paymentMethod.isEmpty) return false;
    final method = paymentMethod.toLowerCase().trim();
    return method.contains('cash on delivery') ||
        method.contains('cod') ||
        method.contains('cash') ||
        method.contains('delivery') ||
        method == 'cash_on_delivery' ||
        method == 'cash on delivery';
  }

  static bool isValidOrder(dynamic order) {
    if (order == null) {
      debugPrint('🔍 Order validation failed: order is null');
      return false;
    }
    final hasProductName = order['product_name'] != null &&
        order['product_name'].toString().isNotEmpty;
    final hasItems = order['items'] != null &&
        order['items'] is List &&
        (order['items'] as List).isNotEmpty;
    final hasCreatedAt = order['created_at'] != null;
    final hasIds = (order['order_id'] != null &&
            order['order_id'].toString().trim().isNotEmpty) ||
        (order['transaction_id'] != null &&
            order['transaction_id'].toString().trim().isNotEmpty) ||
        (order['delivery_id'] != null &&
            order['delivery_id'].toString().trim().isNotEmpty);
    final hasAmount = order['total_price'] != null ||
        order['price'] != null ||
        order['amount'] != null;
    final isValid =
        hasProductName || hasItems || hasCreatedAt || hasIds || hasAmount;

    if (!isValid) {
      debugPrint(
        '🔍 Order validation failed - product_name: ${order['product_name']}, hasItems: ${order['items'] != null}, created_at: ${order['created_at']}, ids: $hasIds',
      );
    }
    return isValid;
  }

  static String getTransactionId(dynamic order) {
    final paymentMethod =
        order['payment_method'] ?? order['payment_type'] ?? '';
    final cod = isCashOnDelivery(paymentMethod.toString());

    if (cod) {
      return order['delivery_id']?.toString() ??
          order['order_id']?.toString() ??
          order['transaction_id']?.toString() ??
          'cod_${order['created_at'] ?? DateTime.now().toIso8601String()}';
    }
    return order['delivery_id']?.toString() ??
        order['transaction_id']?.toString() ??
        order['order_id']?.toString() ??
        '${order['created_at'] ?? DateTime.now().toIso8601String()}_${order['product_name'] ?? 'unknown'}';
  }

  static Map<String, dynamic> processSingleOrder(
    dynamic order,
    String transactionId,
  ) {
    final base = Map<String, dynamic>.from(order as Map);
    if (order.containsKey('items') && order['items'] is List) {
      final items = order['items'] as List;
      if (items.isNotEmpty) {
        final first = items[0];
        if (first is! Map) {
          return {
            ...base,
            'transaction_id': transactionId,
          };
        }
        final firstItem = Map<String, dynamic>.from(first as Map);
        return {
          ...base,
          'product_name': firstItem['product_name'] ?? 'Unknown Product',
          'product_img': firstItem['product_img'] ?? '',
          'qty': items.length > 1
              ? items.fold<int>(0, (sum, item) {
                  if (item is! Map) return sum;
                  return sum + _asInt(item['qty'] ?? 1);
                })
              : _asInt(firstItem['qty'] ?? 1),
          'price': firstItem['price'] ?? 0.0,
          'total_price': _asDouble(order['total_price']),
          'is_multi_item': items.length > 1,
          'item_count': items.length,
          'order_items': items
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList(),
          'transaction_id': transactionId,
        };
      }
    }

    return {
      ...base,
      'transaction_id': transactionId,
    };
  }

  static Map<String, dynamic> processMultiOrder(
    List<dynamic> orders,
    String transactionId,
  ) {
    final firstOrder = orders.first as Map;
    final paymentMethod =
        firstOrder['payment_type'] ?? firstOrder['payment_method'] ?? '';
    final cod = isCashOnDelivery(paymentMethod.toString());

    if (firstOrder.containsKey('items') && firstOrder['items'] is List) {
      return processMultiOrderWithItems(
        orders,
        transactionId,
        paymentMethod.toString(),
      );
    }
    if (cod) {
      return processCashOnDeliveryOrder(
        orders,
        transactionId,
        paymentMethod.toString(),
      );
    }
    return processServerOrder(orders, transactionId, paymentMethod.toString());
  }

  static Map<String, dynamic> processMultiOrderWithItems(
    List<dynamic> orders,
    String transactionId,
    String paymentMethod,
  ) {
    double totalAmount = 0.0;
    int totalQuantity = 0;
    final allItems = <Map<String, dynamic>>[];

    for (final order in orders) {
      final o = order as Map;
      if (o.containsKey('items') && o['items'] is List) {
        final items = o['items'] as List;
        for (final item in items) {
          final im = item as Map;
          allItems.add(Map<String, dynamic>.from(im));
          totalAmount += _asDouble(im['price']) * _asDouble(im['qty'] ?? 1);
          totalQuantity += _asInt(im['qty'] ?? 1);
        }
      }
    }

    final firstItem = allItems.isNotEmpty ? allItems.first : <String, dynamic>{};

    return {
      ...Map<String, dynamic>.from(orders.first as Map),
      'product_name': firstItem['product_name'] ?? 'Unknown Product',
      'product_img': firstItem['product_img'] ?? '',
      'qty': totalQuantity,
      'price': firstItem['price'] ?? 0.0,
      'total_price': totalAmount,
      'is_multi_item': true,
      'item_count': allItems.length,
      'order_items': allItems,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
    };
  }

  static Map<String, dynamic> processCashOnDeliveryOrder(
    List<dynamic> orders,
    String transactionId,
    String paymentMethod,
  ) {
    final orderItems = orders
        .map((order) {
          final o = order as Map;
          return {
            'product_name': o['product_name'] ?? 'Unknown Product',
            'product_img': o['product_img'] ?? '',
            'qty': o['qty'] ?? 1,
            'price': o['price'] ?? 0.0,
            'batch_no': o['batch_no'] ?? '',
          };
        })
        .toList();

    final totalQuantity = orders.fold<int>(0, (sum, order) {
      final o = order as Map;
      return sum + _asInt(o['qty'] ?? 1);
    });
    final totalAmount = orders.fold<double>(0.0, (sum, order) {
      final o = order as Map;
      return sum + _asDouble(o['price']) * _asDouble(o['qty'] ?? 1);
    });

    return {
      ...Map<String, dynamic>.from(orders.first as Map),
      'order_items': orderItems,
      'qty': totalQuantity,
      'total_price': totalAmount,
      'is_multi_item': true,
      'item_count': orders.length,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
    };
  }

  static Map<String, dynamic> processServerOrder(
    List<dynamic> orders,
    String transactionId,
    String paymentMethod,
  ) {
    final orderItems = orders
        .map((order) {
          final o = order as Map;
          return {
            'product_name': o['product_name'] ?? 'Unknown Product',
            'product_img': o['product_img'] ?? '',
            'qty': o['qty'] ?? 1,
            'price': o['price'] ?? 0.0,
            'batch_no': o['batch_no'] ?? '',
          };
        })
        .toList();

    final totalQuantity = orders.fold<int>(0, (sum, order) {
      final o = order as Map;
      return sum + _asInt(o['qty'] ?? 1);
    });
    final totalAmount = orders.fold<double>(0.0, (sum, order) {
      final o = order as Map;
      return sum + _asDouble(o['price']) * _asDouble(o['qty'] ?? 1);
    });

    return {
      ...Map<String, dynamic>.from(orders.first as Map),
      'order_items': orderItems,
      'qty': totalQuantity,
      'total_price': totalAmount,
      'is_multi_item': true,
      'item_count': orders.length,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
    };
  }

  static bool shouldReplaceOrderWithData(
    dynamic existingOrder,
    dynamic newOrder,
    String existingStatus,
    String newStatus,
  ) {
    final eo = existingOrder as Map;
    final no = newOrder as Map;
    final existingHasProduct = eo['product_name'] != null &&
        eo['product_name'].toString().isNotEmpty;
    final newHasProduct =
        no['product_name'] != null && no['product_name'].toString().isNotEmpty;

    if (newHasProduct && !existingHasProduct) return true;
    if (existingHasProduct && !newHasProduct) return false;

    const statusPriority = ['cancelled', 'pending', 'processing', 'completed'];
    final existingIndex = statusPriority.indexWhere(
      (status) => existingStatus.toLowerCase().contains(status),
    );
    final newIndex = statusPriority.indexWhere(
      (status) => newStatus.toLowerCase().contains(status),
    );

    return newIndex > existingIndex;
  }

  static List<Map<String, dynamic>> removeDuplicates(List<dynamic> orders) {
    debugPrint('🔍 Removing duplicates from ${orders.length} orders...');
    final uniqueOrders = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      final o = Map<String, dynamic>.from(order as Map);
      final paymentMethod =
          o['payment_method'] ?? o['payment_type'] ?? '';
      final cod = isCashOnDelivery(paymentMethod.toString());

      String baseTransactionId;
      if (cod) {
        baseTransactionId = o['delivery_id']?.toString() ??
            o['order_id']?.toString() ??
            o['transaction_id']?.toString() ??
            '';
      } else {
        final deliveryId = o['delivery_id']?.toString() ?? '';
        baseTransactionId = deliveryId.isNotEmpty
            ? deliveryId
            : (o['transaction_id'] ?? o['order_id'] ?? '').toString();
      }

      if (baseTransactionId.isEmpty) {
        debugPrint(
          '🔍 Warning: Order has no transaction ID, skipping: ${o['product_name'] ?? 'Unknown'}',
        );
        continue;
      }

      if (!uniqueOrders.containsKey(baseTransactionId)) {
        uniqueOrders[baseTransactionId] = o;
        debugPrint(
          '🔍 Added unique order: $baseTransactionId - ${o['product_name'] ?? 'Unknown'}',
        );
      } else {
        final existingOrder = uniqueOrders[baseTransactionId]!;
        final existingStatus = existingOrder['status']?.toString() ?? '';
        final newStatus = o['status']?.toString() ?? '';

        debugPrint(
          '🔍 Duplicate found: $baseTransactionId - existing: $existingStatus, new: $newStatus',
        );
        if (shouldReplaceOrderWithData(
          existingOrder,
          o,
          existingStatus,
          newStatus,
        )) {
          uniqueOrders[baseTransactionId] = o;
          debugPrint('🔍 Replaced order with newer data: $baseTransactionId');
        } else {
          debugPrint('🔍 Kept existing order: $baseTransactionId');
        }
      }
    }

    debugPrint(
      '🔍 After removing duplicates: ${uniqueOrders.length} unique orders',
    );
    return uniqueOrders.values.toList();
  }

  /// Same output shape as the former [PurchaseScreenState._processOrdersInBackground].
  static List<Map<String, dynamic>> processRawOrders(List<dynamic> rawOrders) {
    debugPrint('🔍 Starting background order processing...');
    debugPrint('🔍 Total raw orders received: ${rawOrders.length}');
    final groupedOrders = <String, List<dynamic>>{};

    var validCount = 0;
    var invalidCount = 0;
    for (final order in rawOrders) {
      if (!isValidOrder(order)) {
        invalidCount++;
        final s = order.toString();
        debugPrint(
          '🔍 Invalid order filtered out: ${s.substring(0, s.length > 200 ? 200 : s.length)}',
        );
        continue;
      }
      validCount++;

      final transactionId = getTransactionId(order);
      groupedOrders.putIfAbsent(transactionId, () => []).add(order);
    }
    debugPrint('🔍 Valid orders: $validCount, Invalid orders: $invalidCount');

    debugPrint('🔍 Processing ${groupedOrders.length} grouped orders...');
    final combinedOrders = groupedOrders.entries.map((entry) {
      final orders = entry.value;
      final transactionId = entry.key;

      if (orders.length == 1) {
        return processSingleOrder(orders.first, transactionId);
      }
      return processMultiOrder(orders, transactionId);
    }).toList();

    debugPrint('🔍 Removing duplicates and sorting orders...');
    final uniqueOrders = removeDuplicates(combinedOrders);
    uniqueOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime(1970);
      return dateB.compareTo(dateA);
    });

    debugPrint('🔍 Final processed orders: ${uniqueOrders.length}');
    return uniqueOrders;
  }
}
