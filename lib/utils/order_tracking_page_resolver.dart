import '../models/order_tracking_page_details.dart';
import '../services/auth_service.dart';
import '../services/order_history_transformer.dart';
import '../services/order_tracking_service.dart';
import 'order_steps_api_logger.dart';
import 'order_timestamp_parser.dart';

/// Resolves order list + status API data for the legacy order tracking page.
Future<OrderTrackingPageDetails> resolveOrderTrackingPageDetails(
  Map<String, dynamic> orderDetails,
) async {
  final orderId = orderDetails['id']?.toString();
  final orderNumber = orderDetails['order_number']?.toString();

  if (orderId == null && orderNumber == null) {
    return const OrderTrackingPageDetails();
  }

  final notificationDeliveryId =
      orderDetails['delivery_id']?.toString() ??
          orderDetails['transaction_id']?.toString() ??
          orderDetails['id']?.toString() ??
          orderDetails['order_number']?.toString();

  final result = await AuthService.getOrders();
  if (result['status'] != 'success' || result['data'] is! List) {
    return const OrderTrackingPageDetails();
  }

  final orders = result['data'] as List;
  final requestedIds = <String>{
    if (orderId != null) orderId,
    if (orderNumber != null) orderNumber,
    if (notificationDeliveryId != null) notificationDeliveryId,
  }..removeWhere((value) => value.isEmpty);

  final matchedRows = <Map<String, dynamic>>[];
  for (final order in orders) {
    if (order is! Map) continue;
    final o = Map<String, dynamic>.from(order);
    final candidateIds = <String>{
      o['delivery_id']?.toString() ?? '',
      o['transaction_id']?.toString() ?? '',
      o['id']?.toString() ?? '',
      o['order_number']?.toString() ?? '',
      o['order_id']?.toString() ?? '',
    }..removeWhere((value) => value.isEmpty);

    if (candidateIds.intersection(requestedIds).isNotEmpty) {
      matchedRows.add(o);
    }
  }

  if (matchedRows.isEmpty && orderId != null && orderId.startsWith('ORDER_')) {
    final numericId = orderId.replaceFirst('ORDER_', '');
    for (final order in orders) {
      if (order is! Map) continue;
      final o = Map<String, dynamic>.from(order);
      if (o['id']?.toString() == numericId ||
          o['id'] == int.tryParse(numericId)) {
        matchedRows.add(o);
      }
    }
  }

  if (matchedRows.isEmpty) {
    return const OrderTrackingPageDetails();
  }

  final orderItems = _mergeMatchedOrderRows(matchedRows);
  final targetOrder = matchedRows.first;

  double? actualDeliveryFee;
  double? actualTotalAmount;
  final deliveryId = targetOrder['delivery_id']?.toString();
  if (deliveryId != null) {
    final groupedOrders = orders
        .where((o) => o is Map && o['delivery_id']?.toString() == deliveryId)
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();

    if (groupedOrders.isNotEmpty) {
      var actualSubtotal = 0.0;
      for (final order in groupedOrders) {
        final price = (order['price'] ?? 0.0).toDouble();
        final qty = (order['qty'] ?? 1).toInt();
        actualSubtotal += price * qty;
      }

      for (final order in groupedOrders) {
        final fee = order['delivery_fee'] ?? order['deliveryFee'];
        if (fee != null) {
          final parsed =
              fee is num ? fee.toDouble() : (double.tryParse(fee.toString()) ?? 0.0);
          if (parsed > 0) {
            actualDeliveryFee = parsed;
            actualTotalAmount = actualSubtotal + parsed;
            break;
          }
        }
      }
    }
  }

  final deliveryAddress = targetOrder['delivery_address']?.toString() ??
      targetOrder['shipping_address']?.toString() ??
      targetOrder['address']?.toString() ??
      targetOrder['addr_1']?.toString();
  final contactNumber = targetOrder['contact_number']?.toString() ??
      targetOrder['phone']?.toString() ??
      targetOrder['user_phone']?.toString();
  final deliveryOption = targetOrder['delivery_option']?.toString() ??
      targetOrder['shipping_method']?.toString() ??
      targetOrder['delivery_method']?.toString() ??
      targetOrder['shipping_type']?.toString();

  final trackingService = OrderTrackingService();
  var orderStatus = trackingService.resolveAuthoritativeRawStatus(targetOrder);
  if (orderStatus.isEmpty) {
    orderStatus = targetOrder['status']?.toString() ??
        targetOrder['order_status']?.toString() ??
        '';
  }
  if (orderStatus.isEmpty) {
    final dId = targetOrder['delivery_id']?.toString();
    if (dId != null) {
      final candidates = <String>[];
      for (final o in orders) {
        if (o is! Map) continue;
        if (o['delivery_id']?.toString() != dId) continue;
        final s = o['status']?.toString() ?? o['order_status']?.toString();
        if (s != null && s.isNotEmpty) candidates.add(s);
      }
      if (candidates.isNotEmpty) {
        var best = candidates.first;
        var bestStage = trackingService.normalizeStage(best);
        for (final s in candidates.skip(1)) {
          final stage = trackingService.normalizeStage(s);
          if (trackingService.stageTimelineIndex(stage) >
              trackingService.stageTimelineIndex(bestStage)) {
            bestStage = stage;
            best = s;
          }
        }
        orderStatus = best;
      }
    }
  }

  OrderStepsApiLogger.logSnapshotStageFields(
    'track-order page (GET /orders match)',
    snapshot: targetOrder,
  );

  final stageTimes =
      trackingService.parseStageTimestampsFromSnapshot(targetOrder);
  final placedAt = parseOrderTimestamp(targetOrder['created_at']);

  return OrderTrackingPageDetails(
    orderStatus: orderStatus,
    deliveryAddress: deliveryAddress,
    contactNumber: contactNumber,
    deliveryOption: deliveryOption,
    actualDeliveryFee: actualDeliveryFee,
    actualTotalAmount: actualTotalAmount,
    orderItems: orderItems,
    foundInOrdersList: true,
    stageTimes: stageTimes,
    placedAt: placedAt,
  );
}

List<Map<String, dynamic>> _mergeMatchedOrderRows(
  List<Map<String, dynamic>> matchedRows,
) {
  if (matchedRows.isEmpty) return const [];
  final mergeKey = OrderHistoryTransformer.getTransactionId(matchedRows.first);
  final merged = matchedRows.length == 1
      ? OrderHistoryTransformer.processSingleOrder(matchedRows.first, mergeKey)
      : OrderHistoryTransformer.processMultiOrder(matchedRows, mergeKey);
  return extractOrderItemsList(merged);
}

int parseOrderItemCount(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> extractOrderItemsList(Map<String, dynamic> source) {
  for (final key in ['order_items', 'items']) {
    final raw = source[key];
    if (raw is List && raw.isNotEmpty) {
      final items = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (items.isNotEmpty) return items;
    }
  }

  final itemCount = parseOrderItemCount(source['item_count']);
  final isMultiItem = source['is_multi_item'] == true || itemCount > 1;
  if (!isMultiItem &&
      (source['product_name'] != null || source['name'] != null)) {
    return [
      {
        'product_name':
            source['product_name'] ?? source['name'] ?? 'Unknown Product',
        'product_img': source['product_img'] ??
            source['image'] ??
            source['imageUrl'] ??
            '',
        'qty': source['qty'] ?? source['quantity'] ?? 1,
        'price': source['price'] ?? 0.0,
        'batch_no': source['batch_no'] ?? source['batchNo'] ?? '',
      },
    ];
  }

  return const [];
}
