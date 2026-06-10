import 'dart:async';

import '../models/cart_item.dart';
import '../models/order_status_step.dart';
import '../models/order_tracking_model.dart';
import '../models/order_tracking_page_details.dart';
import '../repositories/order_tracking_repository.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../services/guest_local_order_service.dart';
import '../utils/order_steps_api_logger.dart';
import '../utils/order_timestamp_parser.dart';
import '../utils/order_tracking_page_resolver.dart';

class OrderTrackingService {
  OrderTrackingService([OrderTrackingRepository? repository])
      : _repository = repository ?? OrderTrackingRepositoryImpl();

  final OrderTrackingRepository _repository;

  /// In-memory highest step index per order (avoids prefs read every poll).
  static final Map<String, int> _highestTimelineIndexCache = {};

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
    final items = _groupOrderItems(
      purchasedItems
          .map(OrderTrackingItem.fromCartItem)
          .toList(growable: false),
    );
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final total = _parseDouble(paymentParams['amount']);
    final normalizedTotal = total > 0 ? total : subtotal - discount;
    final stage = normalizeStage(initialStatus);
    final createdAt = DateTime.now();

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
      timelineSteps: buildTimeline(
        stage,
        createdAt: createdAt,
        stageTimes: {OrderTrackingStage.orderPlaced.name: createdAt},
      ),
      createdAt: createdAt,
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

  Future<String?> fetchOrderStatus(String orderId) {
    return _repository.fetchOrderStatus(orderId);
  }

  Future<OrderTrackingPageDetails> fetchPageDetails(
    Map<String, dynamic> orderDetails,
  ) {
    return resolveOrderTrackingPageDetails(orderDetails);
  }

  Future<Map<String, dynamic>?> fetchSavedDeliveryInfo() async {
    final result = await DeliveryService.getLastDeliveryInfo();
    if (result['success'] == true && result['data'] is Map) {
      return Map<String, dynamic>.from(result['data'] as Map);
    }
    return null;
  }

  Future<void> handleOrderConfirmed({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) async {
    final isGuestCheckout = !(await AuthService.isLoggedIn());
    await _repository.handleOrderConfirmed(
      order: order,
      initialTransactionId: initialTransactionId,
      isGuestCheckout: isGuestCheckout,
    );
    if (isGuestCheckout) {
      await GuestLocalOrderService.instance.syncFromOrder(order);
    }
  }

  static const List<OrderTrackingStage> _timelineOrder = [
    OrderTrackingStage.orderPlaced,
    OrderTrackingStage.paid,
    OrderTrackingStage.pendingConfirmation,
    OrderTrackingStage.orderConfirmed,
    OrderTrackingStage.orderDispatched,
    OrderTrackingStage.outForDelivery,
    OrderTrackingStage.arrived,
    OrderTrackingStage.delivered,
  ];

  static const Map<String, String> _snapshotKeyToStepId = {
    'placed_at': 'orderPlaced',
    'order_placed_at': 'orderPlaced',
    'paid_at': 'paid',
    'payment_at': 'paid',
    'pending_confirmation_at': 'pendingConfirmation',
    'confirmed_at': 'orderConfirmed',
    'order_confirmed_at': 'orderConfirmed',
    'ready_for_dispatch_at': 'orderDispatched',
    'dispatch_ready_at': 'orderDispatched',
    'dispatched_at': 'orderDispatched',
    'shipped_at': 'outForDelivery',
    'out_for_delivery_at': 'outForDelivery',
    'arrived_at': 'arrived',
    'delivered_at': 'delivered',
    'completed_at': 'delivered',
    'picked_up_at': 'delivered',
  };

  String _orderStorageKey(OrderTrackingModel order) {
    if (order.transactionId.isNotEmpty) return order.transactionId;
    if (order.orderNumber.isNotEmpty) return order.orderNumber;
    return order.orderId;
  }

  OrderTrackingStage _effectiveTimelineStage(OrderTrackingStage stage) {
    if (stage == OrderTrackingStage.pendingPayment) {
      return OrderTrackingStage.orderPlaced;
    }
    return _timelineOrder.contains(stage)
        ? stage
        : OrderTrackingStage.orderPlaced;
  }

  int _timelineIndex(OrderTrackingStage stage) =>
      _timelineOrder.indexOf(_effectiveTimelineStage(stage));

  int stageTimelineIndex(OrderTrackingStage stage) => _timelineIndex(stage);

  /// Avoids treating "unpaid" / "prepaid" as paid via substring match.
  static bool isPaidStatus(String? rawStatus) {
    final status = rawStatus?.toLowerCase().trim() ?? '';
    if (status.isEmpty) return false;
    if (status.contains('unpaid') ||
        status.contains('not paid') ||
        status.contains('not_paid')) {
      return false;
    }
    if (status == 'paid' ||
        status == 'payment received' ||
        status == 'payment verified' ||
        status.startsWith('paid ') ||
        status.endsWith(' paid') ||
        status.contains(' paid ')) {
      return true;
    }
    return RegExp(r'(^|[^a-z])paid([^a-z]|$)').hasMatch(status);
  }

  bool _allowStageRegression(String? rawStatus, OrderTrackingStage stage) {
    if (stage == OrderTrackingStage.failed) return true;
    final status = rawStatus?.toLowerCase().trim() ?? '';
    return status.contains('cancel');
  }

  /// Synchronous monotonic stage (uses [_highestTimelineIndexCache]).
  OrderTrackingStage coalesceMonotonicStageSync(
    String orderKey,
    OrderTrackingStage apiStage, {
    String? rawStatus,
  }) {
    if (orderKey.isEmpty || _allowStageRegression(rawStatus, apiStage)) {
      return apiStage;
    }

    final apiIdx = _timelineIndex(apiStage);
    if (apiIdx < 0) return apiStage;

    final storedIdx = _highestTimelineIndexCache[orderKey] ?? -1;
    if (apiIdx > storedIdx) {
      _highestTimelineIndexCache[orderKey] = apiIdx;
      return apiStage;
    }
    if (storedIdx > apiIdx && storedIdx < _timelineOrder.length) {
      return _timelineOrder[storedIdx];
    }
    return apiStage;
  }

  Future<void> primeMonotonicCache(String orderKey) async {
    if (orderKey.isEmpty) return;
    if (_highestTimelineIndexCache.containsKey(orderKey)) return;
    _highestTimelineIndexCache[orderKey] =
        await _repository.loadHighestTimelineIndex(orderKey);
  }

  void persistMonotonicIndexAsync(
    String orderKey,
    OrderTrackingStage apiStage,
  ) {
    if (orderKey.isEmpty) return;
    final apiIdx = _timelineIndex(apiStage);
    if (apiIdx < 0) return;
    final cached = _highestTimelineIndexCache[orderKey] ?? -1;
    if (apiIdx > cached) {
      _highestTimelineIndexCache[orderKey] = apiIdx;
    }
    final toSave = _highestTimelineIndexCache[orderKey] ?? apiIdx;
    if (toSave >= 0) {
      unawaited(
        _repository.saveHighestTimelineIndexIfHigher(orderKey, toSave),
      );
    }
  }

  /// Keeps timeline from jumping backward when the API briefly returns an older status.
  Future<OrderTrackingStage> coalesceMonotonicStage(
    String orderKey,
    OrderTrackingStage apiStage, {
    String? rawStatus,
  }) async {
    await primeMonotonicCache(orderKey);
    final stage = coalesceMonotonicStageSync(
      orderKey,
      apiStage,
      rawStatus: rawStatus,
    );
    persistMonotonicIndexAsync(orderKey, apiStage);
    return stage;
  }

  Map<String, DateTime> parseStageTimestampsFromSnapshot(
    Map<String, dynamic> snapshot,
  ) {
    final times = <String, DateTime>{};

    DateTime? parseAt(dynamic value) => parseOrderTimestamp(value);

    void putStageTime(String stepId, DateTime at) {
      final existing = times[stepId];
      if (existing == null || at.isAfter(existing)) {
        times[stepId] = at;
      }
    }

    for (final entry in _snapshotKeyToStepId.entries) {
      final at = parseAt(snapshot[entry.key]);
      if (at != null) {
        putStageTime(entry.value, at);
      }
    }

    final createdAt = parseAt(snapshot['created_at']);
    if (createdAt != null) {
      putStageTime(OrderTrackingStage.orderPlaced.name, createdAt);
    }

    final history =
        snapshot['status_history'] ?? snapshot['order_status_history'];
    if (history is List) {
      for (final item in history) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawStatus =
            map['status']?.toString() ?? map['order_status']?.toString();
        if (rawStatus == null || rawStatus.isEmpty) continue;
        final stepId = _effectiveTimelineStage(normalizeStage(rawStatus)).name;
        final at = parseAt(
          map['occurred_at'] ??
              map['at'] ??
              map['timestamp'] ??
              map['created_at'] ??
              map['updated_at'],
        );
        if (at != null) {
          putStageTime(stepId, at);
        }
      }
    }

    final flatStatus = snapshot['status']?.toString() ??
        snapshot['order_status']?.toString();
    if (flatStatus != null && flatStatus.trim().isNotEmpty) {
      final stepId =
          _effectiveTimelineStage(normalizeStage(flatStatus)).name;
      final statusAt = parseAt(
        snapshot['updated_at'] ??
            snapshot['status_updated_at'] ??
            snapshot['modified_at'],
      );
      if (statusAt != null) {
        putStageTime(stepId, statusAt);
      }
    }

    OrderStepsApiLogger.logParsedStageTimes(times);
    return times;
  }

  /// When GET /orders returns multiple rows for one checkout, keep the furthest status.
  String pickFurthestRawStatus(
    Iterable<Map<String, dynamic>> snapshots, {
    String? fallback,
    Iterable<String> extraStatuses = const [],
  }) {
    String? bestRaw = fallback?.trim().isNotEmpty == true ? fallback!.trim() : null;
    var bestIdx = bestRaw == null ? -1 : _timelineIndex(normalizeStage(bestRaw));

    void consider(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final trimmed = raw.trim();
      final idx = _timelineIndex(normalizeStage(trimmed));
      if (idx > bestIdx) {
        bestIdx = idx;
        bestRaw = trimmed;
      }
    }

    for (final snapshot in snapshots) {
      final resolved = resolveAuthoritativeRawStatus(snapshot);
      consider(resolved);
    }
    for (final raw in extraStatuses) {
      consider(raw);
    }

    return bestRaw ?? fallback ?? '';
  }

  Set<String> _orderLookupKeys(OrderTrackingModel order) {
    return <String>{
      order.transactionId,
      order.orderNumber,
      order.orderId,
      order.paymentParams['order_id']?.toString() ?? '',
    }..removeWhere((value) => value.isEmpty);
  }

  Future<OrderTrackingModel> applyKnownStatus(
    OrderTrackingModel order,
    String rawStatus, {
    OrderTrackingStage? previousStage,
  }) async {
    if (rawStatus.trim().isEmpty) return order;

    final orderKey = _orderStorageKey(order);
    final previous = previousStage ?? order.stage;
    await primeMonotonicCache(orderKey);

    final apiStage = normalizeStage(rawStatus);
    final stage = coalesceMonotonicStageSync(
      orderKey,
      apiStage,
      rawStatus: rawStatus,
    );
    persistMonotonicIndexAsync(orderKey, apiStage);

    if (previous != stage) {
      await _recordStageAdvance(orderKey, previous, stage);
    }

    final stageTimes = await _resolveStageTimes(
      orderKey: orderKey,
      createdAt: order.createdAt,
      currentStage: stage,
    );
    final timelineSteps = buildTimeline(
      stage,
      createdAt: order.createdAt,
      stageTimes: stageTimes,
    );

    return order.copyWith(
      rawStatus: rawStatus,
      stage: stage,
      stageLabel: stageLabel(stage),
      stageMessage: stageMessage(stage),
      timelineSteps: timelineSteps,
    );
  }

  Future<Map<String, DateTime>> _resolveStageTimes({
    required String orderKey,
    required DateTime createdAt,
    Map<String, dynamic>? snapshot,
    OrderTrackingStage? currentStage,
    Map<String, DateTime>? cachedLocal,
  }) async {
    final local = cachedLocal ?? await _repository.loadStageTimestamps(orderKey);
    final fromApi = snapshot == null
        ? <String, DateTime>{}
        : parseStageTimestampsFromSnapshot(snapshot);

    // API timestamps win; device-only fallbacks fill gaps.
    final merged = Map<String, DateTime>.from(fromApi);
    for (final entry in local.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }
    merged.putIfAbsent(
      OrderTrackingStage.orderPlaced.name,
      () => parseOrderTimestamp(createdAt) ?? createdAt.toLocal(),
    );

    if (currentStage != null && currentStage != OrderTrackingStage.failed) {
      final stepId = _effectiveTimelineStage(currentStage).name;
      merged.putIfAbsent(stepId, () => DateTime.now());
    }

    unawaited(_repository.saveStageTimestamps(orderKey, merged));

    return merged;
  }

  Future<void> _recordStageAdvance(
    String orderKey,
    OrderTrackingStage previous,
    OrderTrackingStage current,
  ) async {
    final prevIdx = _timelineIndex(previous);
    final curIdx = _timelineIndex(current);
    if (curIdx <= prevIdx) return;

    final now = DateTime.now();
    for (var i = prevIdx + 1; i <= curIdx; i++) {
      await _repository.recordStageTimestampIfAbsent(
        orderKey,
        _timelineOrder[i].name,
        now,
      );
    }
  }

  Future<OrderTrackingModel> syncTimelineWithTimestamps(
    OrderTrackingModel order, {
    OrderTrackingStage? previousStage,
  }) async {
    final orderKey = _orderStorageKey(order);
    await primeMonotonicCache(orderKey);
    final displayStage = coalesceMonotonicStageSync(
      orderKey,
      order.stage,
      rawStatus: order.rawStatus,
    );
    persistMonotonicIndexAsync(orderKey, order.stage);
    final orderForTimeline = displayStage == order.stage
        ? order
        : order.copyWith(
            stage: displayStage,
            stageLabel: stageLabel(displayStage),
            stageMessage: stageMessage(displayStage),
          );

    final previous = previousStage ?? orderForTimeline.stage;
    if (previous != orderForTimeline.stage) {
      await _recordStageAdvance(orderKey, previous, orderForTimeline.stage);
    }

    final stageTimes = await _resolveStageTimes(
      orderKey: orderKey,
      createdAt: orderForTimeline.createdAt,
      currentStage: orderForTimeline.stage,
    );

    final timelineSteps = buildTimeline(
      orderForTimeline.stage,
      createdAt: order.createdAt,
      stageTimes: stageTimes,
    );
    OrderStepsApiLogger.logParsedStageTimes(stageTimes);
    OrderStepsApiLogger.logBuiltTimeline(
      source: 'syncTimelineWithTimestamps',
      rawStatus: order.rawStatus,
      stage: order.stage,
      steps: timelineSteps,
    );

    return orderForTimeline.copyWith(timelineSteps: timelineSteps);
  }

  Future<OrderTrackingModel> refreshOrder(
    OrderTrackingModel currentOrder, {
    OrderTrackingStage? previousStage,
  }) async {
    final checkoutOrderId =
        currentOrder.paymentParams['order_id']?.toString() ?? '';
    final orderKey = _orderStorageKey(currentOrder);
    final previous = previousStage ?? currentOrder.stage;

    final snapshotFuture = _repository.fetchLatestOrderSnapshot(
      orderId: currentOrder.orderId,
      orderNumber: currentOrder.orderNumber,
      transactionId: currentOrder.transactionId,
      checkoutOrderId: checkoutOrderId,
    );
    final localFuture = _repository.loadStageTimestamps(orderKey);
    final hintsFuture =
        _repository.loadStatusHints(_orderLookupKeys(currentOrder));
    final primeFuture = primeMonotonicCache(orderKey);

    final snapshot = await snapshotFuture;
    final local = await localFuture;
    final hints = await hintsFuture;
    await primeFuture;

    if (snapshot == null) {
      final hintedStatus = pickFurthestRawStatus(
        const [],
        fallback: currentOrder.rawStatus,
        extraStatuses: hints,
      );
      if (hintedStatus.isNotEmpty &&
          hintedStatus.toLowerCase() != currentOrder.rawStatus.toLowerCase()) {
        return applyKnownStatus(
          currentOrder,
          hintedStatus,
          previousStage: previous,
        );
      }
      if (previous != currentOrder.stage) {
        await _recordStageAdvance(orderKey, previous, currentOrder.stage);
      }
      final stageTimes = await _resolveStageTimes(
        orderKey: orderKey,
        createdAt: currentOrder.createdAt,
        currentStage: currentOrder.stage,
      );
      return currentOrder.copyWith(
        timelineSteps: buildTimeline(
          currentOrder.stage,
          createdAt: currentOrder.createdAt,
          stageTimes: stageTimes,
        ),
      );
    }

    final resolved = pickFurthestRawStatus(
      [snapshot],
      fallback: currentOrder.rawStatus,
      extraStatuses: hints,
    );
    final rawStatus = resolved.isNotEmpty ? resolved : currentOrder.rawStatus;
    final apiStage = normalizeStage(rawStatus);
    final stage = coalesceMonotonicStageSync(
      orderKey,
      apiStage,
      rawStatus: rawStatus,
    );
    persistMonotonicIndexAsync(orderKey, apiStage);

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

    if (previous != stage) {
      unawaited(_recordStageAdvance(orderKey, previous, stage));
    }

    final createdAt = parseOrderTimestamp(snapshot['created_at']) ??
        currentOrder.createdAt.toLocal();
    final stageTimes = await _resolveStageTimes(
      orderKey: orderKey,
      createdAt: createdAt,
      snapshot: snapshot,
      currentStage: stage,
      cachedLocal: local,
    );

    final timelineSteps = buildTimeline(
      stage,
      createdAt: createdAt,
      stageTimes: stageTimes,
    );
    OrderStepsApiLogger.logSnapshotStageFields(
      'refreshOrder',
      snapshot: snapshot,
    );
    OrderStepsApiLogger.logBuiltTimeline(
      source: 'refreshOrder',
      rawStatus: rawStatus,
      stage: stage,
      steps: timelineSteps,
    );

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
      createdAt: createdAt,
      timelineSteps: timelineSteps,
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
      timelineSteps: buildTimeline(
        stage,
        createdAt: currentOrder.createdAt,
      ),
    );
  }

  /// Picks the furthest-along status when the API sends conflicting values.
  String resolveAuthoritativeRawStatus(Map<String, dynamic> snapshot) {
    String? bestRaw;
    var bestIdx = -1;

    void consider(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final trimmed = raw.trim();
      final idx = _timelineIndex(normalizeStage(trimmed));
      if (idx > bestIdx) {
        bestIdx = idx;
        bestRaw = trimmed;
      }
    }

    consider(snapshot['status']?.toString());
    consider(snapshot['order_status']?.toString());
    consider(snapshot['delivery_status']?.toString());

    final history =
        snapshot['status_history'] ?? snapshot['order_status_history'];
    if (history is List) {
      for (final item in history) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        consider(map['status']?.toString());
        consider(map['order_status']?.toString());
      }
    }

    return bestRaw ?? '';
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
    if (status.contains('ready for pickup') ||
        status.contains('ready_for_pickup') ||
        status.contains('ready to be picked')) {
      return OrderTrackingStage.outForDelivery;
    }
    // Check "out for delivery" / "shipped" BEFORE "delivered" (since "out for delivery" contains "deliver")
    if (status.contains('out for delivery') ||
        status.contains('out_for_delivery') ||
        status == 'shipped' ||
        status.contains('shipped') ||
        status.contains('out for') ||
        status.contains('in transit') ||
        status.contains('in_transit') ||
        status.contains('on the way') ||
        status.contains('on_the_way') ||
        status.contains('en route') ||
        status.contains('en_route') ||
        status.contains('on route') ||
        status.contains('on_route') ||
        status.contains('with courier') ||
        status.contains('with_courier') ||
        status.contains('delivery in progress')) {
      return OrderTrackingStage.outForDelivery;
    }
    if (status.contains('ready for dispatch') ||
        status.contains('ready_for_dispatch') ||
        status.contains('ready to dispatch')) {
      return OrderTrackingStage.orderDispatched;
    }
    if (status.contains('dispatched') ||
        (status.contains('dispatch') && !status.contains('confirmation'))) {
      return OrderTrackingStage.orderDispatched;
    }
    if (status == 'arrived' || status.contains('arrived')) {
      return OrderTrackingStage.arrived;
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
    if (isPaidStatus(status)) {
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
      case OrderTrackingStage.orderDispatched:
        return 'Ready for Dispatch';
      case OrderTrackingStage.outForDelivery:
        return 'Out for Delivery';
      case OrderTrackingStage.arrived:
        return 'Arrived';
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
      case OrderTrackingStage.orderDispatched:
        return 'Your order is packed and ready to be dispatched.';
      case OrderTrackingStage.outForDelivery:
        return 'Your order is on its way to you.';
      case OrderTrackingStage.arrived:
        return 'Your order has arrived at your delivery location.';
      case OrderTrackingStage.delivered:
        return 'Your order has been delivered successfully.';
      case OrderTrackingStage.failed:
        return 'Your payment could not be completed. Please try again.';
    }
  }

  List<OrderStatusStep> buildTimeline(
    OrderTrackingStage stage, {
    required DateTime createdAt,
    Map<String, DateTime> stageTimes = const {},
  }) {
    const titles = <OrderTrackingStage, String>{
      OrderTrackingStage.orderPlaced: 'Order Placed',
      OrderTrackingStage.paid: 'Paid',
      OrderTrackingStage.pendingConfirmation: 'Pending Confirmation',
      OrderTrackingStage.orderConfirmed: 'Order Confirmed',
      OrderTrackingStage.orderDispatched: 'Ready for Dispatch',
      OrderTrackingStage.outForDelivery: 'Out for Delivery',
      OrderTrackingStage.arrived: 'Arrived',
      OrderTrackingStage.delivered: 'Delivered',
    };

    final effectiveStage = _effectiveTimelineStage(stage);
    final currentIndex = _timelineOrder.indexOf(effectiveStage);

    return _timelineOrder.asMap().entries.map((entry) {
      final stepStage = entry.value;
      final stepIndex = entry.key;
      final stepId = stepStage.name;
      final isCurrent = currentIndex >= 0 && currentIndex == stepIndex;
      final isCompleted = currentIndex >= 0 && stepIndex < currentIndex;

      DateTime? occurredAt;
      if (isCompleted || isCurrent) {
        occurredAt = stageTimes[stepId];
        if (occurredAt == null && stepStage == OrderTrackingStage.orderPlaced) {
          occurredAt = parseOrderTimestamp(createdAt) ?? createdAt.toLocal();
        }
        if (occurredAt != null) {
          occurredAt = occurredAt.toLocal();
        }
      }

      return OrderStatusStep(
        id: stepId,
        title: titles[stepStage]!,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
        occurredAt: occurredAt,
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
    final parsed = _parseItemsFromSnapshot(snapshot);
    List<OrderTrackingItem> result;
    if (parsed.isEmpty) {
      result = fallback;
    } else if (fallback.isEmpty) {
      result = parsed;
    } else {
      final merged = _mergeItemsWithCartQuantities(parsed, fallback);
      if (merged.isNotEmpty) {
        result = merged;
      } else {
        final parsedTotal = parsed.fold<int>(0, (s, i) => s + i.quantity);
        final fallbackTotal = fallback.fold<int>(0, (s, i) => s + i.quantity);
        result =
            (fallback.length > parsed.length || fallbackTotal > parsedTotal)
                ? fallback
                : parsed;
      }
    }
    return _groupOrderItems(result);
  }

  /// One row per product (name + batch); sums qty when API returns duplicate lines.
  List<OrderTrackingItem> _groupOrderItems(List<OrderTrackingItem> items) {
    if (items.length <= 1) return items;

    final grouped = <String, OrderTrackingItem>{};
    for (final item in items) {
      final nameKey = item.name.toLowerCase().trim();
      final batchKey = item.batchNo.trim().toLowerCase();
      final key = '$nameKey|$batchKey';

      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = item;
        continue;
      }

      grouped[key] = OrderTrackingItem(
        name: existing.name,
        price: existing.price > 0 ? existing.price : item.price,
        quantity: existing.quantity + (item.quantity > 0 ? item.quantity : 1),
        imageUrl:
            existing.imageUrl.isNotEmpty ? existing.imageUrl : item.imageUrl,
        batchNo: existing.batchNo.isNotEmpty ? existing.batchNo : item.batchNo,
      );
    }
    return grouped.values.toList(growable: false);
  }

  bool _orderItemsMatch(OrderTrackingItem a, OrderTrackingItem b) {
    final nameA = a.name.toLowerCase().trim();
    final nameB = b.name.toLowerCase().trim();
    if (nameA.isEmpty || nameB.isEmpty || nameA != nameB) {
      return false;
    }
    if (a.batchNo.isNotEmpty && b.batchNo.isNotEmpty) {
      return a.batchNo == b.batchNo;
    }
    return true;
  }

  OrderTrackingItem? _findMatchingCartItem(
    OrderTrackingItem apiItem,
    List<OrderTrackingItem> cartItems,
  ) {
    for (final cart in cartItems) {
      if (_orderItemsMatch(apiItem, cart)) {
        return cart;
      }
    }
    if (cartItems.length == 1) {
      return cartItems.first;
    }
    return null;
  }

  int _resolveItemQuantity(int apiQty, int cartQty) {
    if (apiQty <= 0 && cartQty > 0) return cartQty;
    if (cartQty > apiQty) return cartQty;
    if (apiQty > 0) return apiQty;
    return cartQty > 0 ? cartQty : 1;
  }

  /// Keeps API names/prices but cart quantities when orders API omits or under-reports qty.
  List<OrderTrackingItem> _mergeItemsWithCartQuantities(
    List<OrderTrackingItem> apiItems,
    List<OrderTrackingItem> cartItems,
  ) {
    if (apiItems.length == cartItems.length) {
      return List<OrderTrackingItem>.generate(apiItems.length, (index) {
        final api = apiItems[index];
        final cart = cartItems[index];
        final match = _orderItemsMatch(api, cart)
            ? cart
            : _findMatchingCartItem(api, cartItems);
        final qty = _resolveItemQuantity(
            api.quantity, match?.quantity ?? cart.quantity);
        return OrderTrackingItem(
          name: api.name.isNotEmpty ? api.name : (match?.name ?? cart.name),
          price: api.price > 0 ? api.price : (match?.price ?? cart.price),
          quantity: qty,
          imageUrl: api.imageUrl.isNotEmpty
              ? api.imageUrl
              : (match?.imageUrl ?? cart.imageUrl),
          batchNo: api.batchNo.isNotEmpty
              ? api.batchNo
              : (match?.batchNo ?? cart.batchNo),
        );
      });
    }

    return apiItems.map((api) {
      final match = _findMatchingCartItem(api, cartItems);
      final qty = _resolveItemQuantity(api.quantity, match?.quantity ?? 0);
      return OrderTrackingItem(
        name: api.name.isNotEmpty ? api.name : (match?.name ?? api.name),
        price: api.price > 0 ? api.price : (match?.price ?? api.price),
        quantity: qty,
        imageUrl:
            api.imageUrl.isNotEmpty ? api.imageUrl : (match?.imageUrl ?? ''),
        batchNo: api.batchNo.isNotEmpty ? api.batchNo : (match?.batchNo ?? ''),
      );
    }).toList();
  }

  List<OrderTrackingItem> _parseItemsFromSnapshot(
      Map<String, dynamic> snapshot) {
    for (final key in ['order_items', 'items']) {
      final raw = snapshot[key];
      if (raw is! List || raw.isEmpty) {
        continue;
      }
      final items = raw
          .whereType<Map>()
          .map((item) =>
              OrderTrackingItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      if (items.isNotEmpty) {
        return _groupOrderItems(items);
      }
    }

    final itemCount = _parseInt(snapshot['item_count']);
    final isMultiItem = snapshot['is_multi_item'] == true || itemCount > 1;
    if (!isMultiItem &&
        (snapshot['product_name'] != null || snapshot['name'] != null)) {
      final single = OrderTrackingItem.fromMap(snapshot);
      // Top-level merged snapshot often carries summed qty; prefer explicit line qty.
      if (single.quantity <= 1 && snapshot['order_items'] is List) {
        final nested = snapshot['order_items'] as List;
        if (nested.length == 1 && nested.first is Map) {
          return [
            OrderTrackingItem.fromMap(
              Map<String, dynamic>.from(nested.first as Map),
            ),
          ];
        }
      }
      return [single];
    }

    return const [];
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
