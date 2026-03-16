import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order_tracking_model.dart';
import '../services/order_notification_service.dart';
import '../services/order_tracking_service.dart';

class OrderTrackingProvider extends ChangeNotifier {
  OrderTrackingProvider({
    required OrderTrackingModel initialOrder,
    OrderTrackingService? service,
    Future<void> Function(OrderTrackingModel order)? onOrderConfirmed,
  })  : _order = initialOrder,
        _service = service ?? OrderTrackingService(),
        _onOrderConfirmed = onOrderConfirmed;

  static const Duration _paymentPollInterval = Duration(seconds: 5);
  /// Poll every 2s so the UI updates as soon as the backend changes (no manual refresh).
  static const Duration _trackingPollInterval = Duration(seconds: 2);

  /// Callback for push-driven refresh (e.g. order_status / delivery notification). Set by the tracking screen.
  static void Function()? onOrderStatusUpdateFromPush;

  /// Call when a push notification indicates order status changed; refreshes immediately if tracking is active.
  static void notifyOrderStatusChanged() {
    onOrderStatusUpdateFromPush?.call();
  }
  static const Duration _manualRefreshDelay = Duration(seconds: 10);
  static const int _maxEmptyResponses = 36;
  static const int _maxEmptyResponseMinutes = 3;

  final OrderTrackingService _service;
  final Future<void> Function(OrderTrackingModel order)? _onOrderConfirmed;

  OrderTrackingModel _order;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _showManualRefresh = false;
  String? _errorMessage;
  bool _didHandleSuccessfulOrder = false;
  Timer? _paymentPollTimer;
  Timer? _trackingPollTimer;
  Timer? _manualRefreshTimer;
  DateTime? _firstEmptyResponseTime;
  int _emptyResponseCount = 0;

  OrderTrackingModel get order => _order;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get showManualRefresh => _showManualRefresh;
  String? get errorMessage => _errorMessage;

  bool get isAwaitingPaymentConfirmation =>
      _order.stage == OrderTrackingStage.pendingPayment;

  Future<void> initialize() async {
    _showManualRefresh = false;
    _scheduleManualRefresh();
    await _checkPaymentStatus(isInitialLoad: true);
    if (isAwaitingPaymentConfirmation) {
      _startPaymentPolling();
    } else {
      _startTrackingPolling();
    }
  }

  Future<void> retry() async {
    await _checkPaymentStatus();
  }

  Future<void> refreshTracking() async {
    try {
      final previousStage = _order.stage;
      _isRefreshing = true;
      notifyListeners();
      _order = await _service.refreshOrder(_order);
      _errorMessage = null;
      if (previousStage != OrderTrackingStage.delivered &&
          _order.stage == OrderTrackingStage.delivered) {
        await OrderNotificationService.createOrderStatusNotification(
          orderId: _order.orderId,
          orderNumber: _order.orderNumber,
          status: _order.rawStatus,
          title: 'Order Delivered',
          message:
              'Your order #${_order.orderNumber} has been delivered. Thank you for shopping with us!',
          totalAmount: _order.totalAmount.toString(),
          items: _order.items.map((e) => e.toMap()).toList(),
        );
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _checkPaymentStatus({bool isInitialLoad = false}) async {
    try {
      if (isInitialLoad) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      notifyListeners();

      final result = await _service.checkPaymentStatus();
      _handleEmptyResponses(result);
      _order = _service.applyPaymentStatus(_order, result);
      _errorMessage = null;

      if (result.status == 'success') {
        await _handleSuccessfulOrder();
      } else if (result.status == 'failed') {
        _stopPaymentPolling();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _handleSuccessfulOrder() async {
    _stopPaymentPolling();
    _showManualRefresh = false;

    if (!_didHandleSuccessfulOrder) {
      _didHandleSuccessfulOrder = true;
      final onOrderConfirmed = _onOrderConfirmed;
      if (onOrderConfirmed != null) {
        await onOrderConfirmed(_order);
      }
    }

    _order = await _service.refreshOrder(_order);
    _startTrackingPolling();
  }

  void _handleEmptyResponses(PaymentStatusResult result) {
    if (!result.isEmptyResponse) {
      _firstEmptyResponseTime = null;
      _emptyResponseCount = 0;
      return;
    }

    _emptyResponseCount += 1;
    _firstEmptyResponseTime ??= DateTime.now();

    final emptyDuration =
        DateTime.now().difference(_firstEmptyResponseTime!).inMinutes;
    if (_emptyResponseCount >= _maxEmptyResponses ||
        emptyDuration >= _maxEmptyResponseMinutes) {
      _order = _order.copyWith(
        rawStatus: 'failed',
        stage: OrderTrackingStage.failed,
        stageLabel: _service.stageLabel(OrderTrackingStage.failed),
        stageMessage:
            'Payment verification timed out. Please try again or contact support.',
        timelineSteps: _service.buildTimeline(OrderTrackingStage.orderPlaced),
      );
      _stopPaymentPolling();
    }
  }

  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = Timer.periodic(_paymentPollInterval, (_) {
      unawaited(_checkPaymentStatus());
    });
  }

  void _startTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = Timer.periodic(_trackingPollInterval, (_) {
      unawaited(refreshTracking());
    });
  }

  void _scheduleManualRefresh() {
    _manualRefreshTimer?.cancel();
    _manualRefreshTimer = Timer(_manualRefreshDelay, () {
      _showManualRefresh = true;
      notifyListeners();
    });
  }

  void _stopPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _manualRefreshTimer?.cancel();
    _manualRefreshTimer = null;
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    _trackingPollTimer?.cancel();
    _manualRefreshTimer?.cancel();
    super.dispose();
  }
}
