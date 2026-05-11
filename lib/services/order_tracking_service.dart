import '../models/cart_item.dart';
import '../models/order_status_step.dart';
import '../models/order_tracking_model.dart';
import '../repositories/order_tracking_repository.dart';

class OrderTrackingService {
  OrderTrackingService([OrderTrackingRepository? repository])
      : _repository = repository ?? OrderTrackingRepositoryImpl();

  final OrderTrackingRepository _repository;

  OrderTrackingModel createInitialOrder({
    required Map<String, dynamic> paymentParams,
    required List<CartItem> purchasedItems,
    required String paymentMethod,
    required String initialTransactionId,
    required String deliveryAddress,
    required String contactNumber,
    required String deliveryOption,
    required String estimatedDeliveryTime,
    double? deliveryFee,
    required double discount,
    String initialStatus = 'pending',
  }) {
    final items = purchasedItems
        .map(OrderTrackingItem.fromCartItem)
        .toList(growable: false);
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final total = _parseDouble(paymentParams['amount']);
    final normalizedTotal = total > 0 ? total : subtotal - discount;
    final stage = normalizeStage(initialStatus);

    return OrderTrackingModel(
      orderId: initialTransactionId,
      orderNumber: initialTransactionId,
      transactionId: initialTransactionId,
      paymentParams: Map<String, dynamic>.from(paymentParams),
      items: items,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      contactNumber: contactNumber,
      deliveryOption: deliveryOption,
      estimatedDeliveryTime: estimatedDeliveryTime,
      subtotal: subtotal,
      // deliveryFee removed
      discount: discount,
      totalAmount: normalizedTotal,
      rawStatus: initialStatus,
      stage: stage,
      stageLabel: stageLabel(stage),
      stageMessage: stageMessage(stage),
      timelineSteps: buildTimeline(stage),
      createdAt: DateTime.now(),
      liveTrackingNote:
          'Live rider tracking will appear here as soon as courier data is available.',
      deliveryOtp: _generateDeliveryOtp(initialTransactionId),
    );
  }

  /// Generates a stable 6-digit OTP for this order. Backend can override via snapshot.
  static String _generateDeliveryOtp(String orderSeed) {
    final code = (orderSeed.hashCode & 0x7FFFFFFF) % 1000000;
    return code.toString().padLeft(6, '0');
  }

  Future<PaymentStatusResult> checkPaymentStatus() {
    return _repository.checkPaymentStatus();
  }

  Future<void> handleOrderConfirmed({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) {
    return _repository.handleOrderConfirmed(
      order: order,
      initialTransactionId: initialTransactionId,
    );
  }

  Future<OrderTrackingModel> refreshOrder(
      OrderTrackingModel currentOrder) async {
    final snapshot = await _repository.fetchLatestOrderSnapshot(
      orderId: currentOrder.orderId,
      orderNumber: currentOrder.orderNumber,
      transactionId: currentOrder.transactionId,
    );

    if (snapshot == null) {
      return currentOrder;
    }

    final mergedStatus =
        snapshot['status']?.toString() ?? snapshot['order_status']?.toString();
    final rawStatus = (mergedStatus != null && mergedStatus.isNotEmpty)
        ? mergedStatus
        : currentOrder.rawStatus;
    final stage = normalizeStage(rawStatus);

    final refreshedItems = _extractItems(snapshot, currentOrder.items);
    final subtotal =
        refreshedItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    // deliveryFee removed
    final discount = _extractDiscount(snapshot, currentOrder.discount);
    final totalAmount = _extractTotal(
      snapshot: snapshot,
      fallback: currentOrder.totalAmount,
      subtotal: subtotal,
      discount: discount,
    );

    final orderId = snapshot['delivery_id']?.toString() ??
        snapshot['id']?.toString() ??
        currentOrder.orderId;
    final orderNumber = snapshot['order_number']?.toString() ??
        snapshot['transaction_id']?.toString() ??
        currentOrder.orderNumber;
    final transactionId =
        snapshot['transaction_id']?.toString() ?? currentOrder.transactionId;

    return currentOrder.copyWith(
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
      items: refreshedItems,
      subtotal: subtotal,
      // deliveryFee removed
      discount: discount,
      totalAmount: totalAmount,
      rawStatus: rawStatus,
      stage: stage,
      stageLabel: stageLabel(stage),
      stageMessage: stageMessage(stage),
      timelineSteps: buildTimeline(stage),
      courierName: snapshot['courier_name']?.toString(),
      courierPhone: snapshot['courier_phone']?.toString(),
      courierVehicle: snapshot['courier_vehicle']?.toString(),
      liveTrackingNote: _buildLiveTrackingNote(snapshot),
      deliveryOtp: snapshot['delivery_otp']?.toString() ??
          snapshot['otp']?.toString() ??
          currentOrder.deliveryOtp,
    );
  }

  OrderTrackingModel applyPaymentStatus(
    OrderTrackingModel currentOrder,
    PaymentStatusResult result,
  ) {
    final resolvedStatus = result.status == 'success'
        ? 'order placed'
        : result.status == 'failed'
            ? 'failed'
            : currentOrder.rawStatus;
    final stage = result.status == 'pending'
        ? OrderTrackingStage.pendingPayment
        : normalizeStage(resolvedStatus);

    final nextTransactionId = result.transactionId?.isNotEmpty == true
        ? result.transactionId!
        : currentOrder.transactionId;

    return currentOrder.copyWith(
      orderId: nextTransactionId,
      orderNumber: nextTransactionId,
      transactionId: nextTransactionId,
      rawStatus: resolvedStatus,
      stage: stage,
      stageLabel: result.status == 'pending'
          ? 'Confirming your payment'
          : stageLabel(stage),
      stageMessage:
          result.message.isNotEmpty ? result.message : stageMessage(stage),
      timelineSteps: buildTimeline(stage),
    );
  }

  OrderTrackingStage normalizeStage(String? rawStatus) {
    final status = rawStatus?.toLowerCase().trim() ?? '';

    if (status.isEmpty || status == 'pending') {
      return OrderTrackingStage.pendingPayment;
    }
    if (status.contains('failed') ||
        status.contains('declined') ||
        status.contains('cancel') ||
        status.contains('reject')) {
      return OrderTrackingStage.failed;
    }
    // Check "out for delivery" / "shipped" BEFORE "delivered" (since "out for delivery" contains "deliver")
    if (status.contains('out for delivery') ||
        status.contains('out_for_delivery') ||
        status == 'shipped' ||
        status.contains('shipped') ||
        status.contains('out for')) {
      return OrderTrackingStage.outForDelivery;
    }
    if (status == 'delivered' ||
        status.contains('delivered') ||
        status == 'completed') {
      return OrderTrackingStage.delivered;
    }
    if (status.contains('pending confirmation') ||
        status.contains('pending_confirmation') ||
        status == 'confirming') {
      return OrderTrackingStage.pendingConfirmation;
    }
    if (status.contains('confirmed') ||
        status == 'confirmed' ||
        status == 'processing' ||
        status.contains('preparing') ||
        status.contains('packing')) {
      return OrderTrackingStage.orderConfirmed;
    }
    if (status.contains('paid') ||
        status == 'payment received' ||
        status == 'payment verified') {
      return OrderTrackingStage.paid;
    }
    if (status == 'success' ||
        status.contains('order placed') ||
        status == 'placed') {
      return OrderTrackingStage.orderPlaced;
    }

    return OrderTrackingStage.orderPlaced;
  }

  String stageLabel(OrderTrackingStage stage) {
    switch (stage) {
      case OrderTrackingStage.pendingPayment:
        return 'Confirming your payment';
      case OrderTrackingStage.orderPlaced:
        return 'Order Placed';
      case OrderTrackingStage.paid:
        return 'Paid';
      case OrderTrackingStage.pendingConfirmation:
        return 'Pending Confirmation';
      case OrderTrackingStage.orderConfirmed:
        return 'Order Confirmed';
      case OrderTrackingStage.outForDelivery:
        return 'Out for Delivery';
      case OrderTrackingStage.delivered:
        return 'Delivered';
      case OrderTrackingStage.failed:
        return 'Payment failed';
    }
  }

  String stageMessage(OrderTrackingStage stage) {
    switch (stage) {
      case OrderTrackingStage.pendingPayment:
        return 'We are waiting for the payment provider to confirm your order.';
      case OrderTrackingStage.orderPlaced:
        return 'Your order has been placed and is in the queue.';
      case OrderTrackingStage.paid:
        return 'Payment has been received. Your order is being processed.';
      case OrderTrackingStage.pendingConfirmation:
        return 'Your order is awaiting confirmation from the store.';
      case OrderTrackingStage.orderConfirmed:
        return 'Your order has been confirmed and is being prepared!';
      case OrderTrackingStage.outForDelivery:
        return 'Your order is on its way to you.';
      case OrderTrackingStage.delivered:
        return 'Your order has been delivered successfully.';
      case OrderTrackingStage.failed:
        return 'Your payment could not be completed. Please try again.';
    }
  }

  List<OrderStatusStep> buildTimeline(OrderTrackingStage stage) {
    const order = <OrderTrackingStage>[
      OrderTrackingStage.orderPlaced,
      OrderTrackingStage.paid,
      OrderTrackingStage.pendingConfirmation,
      OrderTrackingStage.orderConfirmed,
      OrderTrackingStage.outForDelivery,
      OrderTrackingStage.delivered,
    ];
    const titles = <OrderTrackingStage, String>{
      OrderTrackingStage.orderPlaced: 'Order Placed',
      OrderTrackingStage.paid: 'Paid',
      OrderTrackingStage.pendingConfirmation: 'Pending Confirmation',
      OrderTrackingStage.orderConfirmed: 'Order Confirmed',
      OrderTrackingStage.outForDelivery: 'Out for Delivery',
      OrderTrackingStage.delivered: 'Delivered',
    };

    final effectiveStage = stage == OrderTrackingStage.pendingPayment
        ? OrderTrackingStage.orderPlaced
        : (order.contains(stage) ? stage : OrderTrackingStage.orderPlaced);
    final currentIndex = order.indexOf(effectiveStage);

    return order.asMap().entries.map((entry) {
      final stepStage = entry.value;
      final stepIndex = entry.key;
      return OrderStatusStep(
        id: stepStage.name,
        title: titles[stepStage]!,
        isCompleted: currentIndex > stepIndex,
        isCurrent: currentIndex == stepIndex,
      );
    }).toList(growable: false);
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  List<OrderTrackingItem> _extractItems(
    Map<String, dynamic> snapshot,
    List<OrderTrackingItem> fallback,
  ) {
    final orderItems = snapshot['order_items'];
    if (orderItems is List && orderItems.isNotEmpty) {
      return orderItems
          .whereType<Map>()
          .map((item) =>
              OrderTrackingItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    if (snapshot['product_name'] != null || snapshot['name'] != null) {
      return [
        OrderTrackingItem.fromMap(snapshot),
      ];
    }

    return fallback;
  }

  double _extractDiscount(Map<String, dynamic> snapshot, double fallback) {
    final discount = snapshot['discount'] ?? snapshot['discount_amount'];
    final parsed = _parseDouble(discount);
    return parsed > 0 ? parsed : fallback;
  }

  double _extractTotal({
    required Map<String, dynamic> snapshot,
    required double fallback,
    required double subtotal,
    required double discount,
  }) {
    final amount = snapshot['total_price'] ??
        snapshot['total_amount'] ??
        snapshot['amount'];
    final parsed = _parseDouble(amount);
    if (parsed > 0) {
      return parsed;
    }
    final computed = subtotal - discount;
    return computed > 0 ? computed : fallback;
  }

  String _buildLiveTrackingNote(Map<String, dynamic> snapshot) {
    final hasCourierDetails = snapshot['courier_name'] != null ||
        snapshot['courier_phone'] != null ||
        snapshot['courier_vehicle'] != null;
    if (hasCourierDetails) {
      return 'Courier details are available for this order.';
    }
    return 'Live rider tracking will appear here once courier details and location updates are available from the backend.';
  }
}
