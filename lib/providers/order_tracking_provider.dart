import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order_tracking_model.dart';
import '../services/order_notification_service.dart';
import '../services/order_tracking_service.dart';
import '../utils/non_ui_error_reporter.dart';
import '../utils/order_status_notification_copy.dart';

class OrderTrackingProvider extends ChangeNotifier {
  OrderTrackingProvider({
    required OrderTrackingModel initialOrder,
    OrderTrackingService? service,
    String? initialTransactionId,
    Future<void> Function(OrderTrackingModel order)? onOrderConfirmed,
  })  : _order = initialOrder,
        _service = service ?? OrderTrackingService(),
        _initialTransactionId = initialTransactionId,
        _onOrderConfirmed = onOrderConfirmed;

  static const Duration _paymentPollInterval = Duration(seconds: 5);
  /// Poll periodically; status comes from GET /orders (no per-order /status route).
  static const Duration _trackingPollInterval = Duration(seconds: 8);

  /// Callback for push-driven refresh (e.g. order_status / delivery notification). Set by the tracking screen.
  static void Function()? onOrderStatusUpdateFromPush;

  static final Set<void Function()> _pushRefreshListeners = {};

  /// Callback when order reaches [OrderTrackingStage.orderConfirmed] (defer SnackBar until user leaves confirmation).
  static void Function(OrderTrackingModel order)? onOrderConfirmedStageUi;

  static void registerPushRefresh(void Function() listener) {
    _pushRefreshListeners.add(listener);
  }

  static void unregisterPushRefresh(void Function() listener) {
    _pushRefreshListeners.remove(listener);
  }

  /// Call when a push notification indicates order status changed; refreshes immediately if tracking is active.
  static void notifyOrderStatusChanged() {
    onOrderStatusUpdateFromPush?.call();
    for (final listener in List<void Function()>.from(_pushRefreshListeners)) {
      listener();
    }
  }
  static const Duration _manualRefreshDelay = Duration(seconds: 10);
  static const int _maxEmptyResponses = 36;
  static const int _maxEmptyResponseMinutes = 3;

  final OrderTrackingService _service;
  final String? _initialTransactionId;
  final Future<void> Function(OrderTrackingModel order)? _onOrderConfirmed;

  OrderTrackingModel _order;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _showManualRefresh = false;
  String? _errorMessage;
  bool _didHandleSuccessfulOrder = false;
  bool _didNotifyOrderConfirmed = false;
  final Set<OrderTrackingStage> _notifiedStages = {};
  Timer? _paymentPollTimer;
  Timer? _trackingPollTimer;
  Timer? _manualRefreshTimer;
  DateTime? _firstEmptyResponseTime;
  int _emptyResponseCount = 0;
  bool _isDisposed = false;

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
    _order = await _service.syncTimelineWithTimestamps(_order);
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
    if (_isDisposed) return;
    try {
      final previousStage = _order.stage;
      _isRefreshing = true;
      _notifyListenersSafely();
      _order = await _service.refreshOrder(
        _order,
        previousStage: previousStage,
      );
      if (_isDisposed) return;
      _errorMessage = null;
      await _notifyImportantStageChanges(previousStage);
    } catch (e, st) {
      NonUiErrorReporter.report('OrderTrackingProvider.refreshTracking', e, st);
    } finally {
      if (_isDisposed) return;
      _isLoading = false;
      _isRefreshing = false;
      _notifyListenersSafely();
    }
  }

  Future<void> _checkPaymentStatus({bool isInitialLoad = false}) async {
    if (_isDisposed) return;
    try {
      if (isInitialLoad) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _notifyListenersSafely();

      final result = await _service.checkPaymentStatus();
      if (_isDisposed) return;
      _handleEmptyResponses(result);
      final previousStage = _order.stage;
      _order = _service.applyPaymentStatus(_order, result);
      _order = await _service.syncTimelineWithTimestamps(
        _order,
        previousStage: previousStage,
      );
      _errorMessage = null;

      if (result.status == 'success') {
        await _handleSuccessfulOrder();
      } else if (result.status == 'failed') {
        _stopPaymentPolling();
      }
    } catch (e, st) {
      NonUiErrorReporter.report(
        'OrderTrackingProvider._checkPaymentStatus',
        e,
        st,
      );
    } finally {
      if (_isDisposed) return;
      _isLoading = false;
      _isRefreshing = false;
      _notifyListenersSafely();
    }
  }

  Future<void> _handleSuccessfulOrder() async {
    if (_isDisposed) return;
    _stopPaymentPolling();
    _showManualRefresh = false;

    // Backend first: authoritative snapshot before any local backup or UI side effects.
    try {
      final previousStage = _order.stage;
      _order = await _service.refreshOrder(
        _order,
        previousStage: previousStage,
      );
      if (!_isDisposed) {
        await _notifyImportantStageChanges(previousStage);
      }
    } catch (e, st) {
      NonUiErrorReporter.report(
        'OrderTrackingProvider._handleSuccessfulOrder.refreshOrder',
        e,
        st,
      );
    }
    if (_isDisposed) return;

    if (!_didHandleSuccessfulOrder) {
      _didHandleSuccessfulOrder = true;
      try {
        await _service.handleOrderConfirmed(
          order: _order,
          initialTransactionId: _initialTransactionId,
        );
      } catch (e, st) {
        NonUiErrorReporter.report(
          'OrderTrackingProvider._handleSuccessfulOrder.handleOrderConfirmed',
          e,
          st,
        );
      }
      if (_isDisposed) return;
      final onOrderConfirmed = _onOrderConfirmed;
      if (onOrderConfirmed != null) {
        try {
          await onOrderConfirmed(_order);
        } catch (e, st) {
          NonUiErrorReporter.report(
            'OrderTrackingProvider._handleSuccessfulOrder.onOrderConfirmed',
            e,
            st,
          );
        }
        if (_isDisposed) return;
      }
    }

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
        timelineSteps: _service.buildTimeline(
          OrderTrackingStage.orderPlaced,
          createdAt: _order.createdAt,
        ),
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
      if (_isDisposed) return;
      _showManualRefresh = true;
      _notifyListenersSafely();
    });
  }

  void _notifyListenersSafely() {
    if (_isDisposed) return;
    notifyListeners();
  }

  Future<void> _notifyImportantStageChanges(
    OrderTrackingStage previousStage,
  ) async {
    if (_isDisposed) return;
    final current = _order.stage;
    if (previousStage == current ||
        current == OrderTrackingStage.pendingPayment ||
        current == OrderTrackingStage.failed ||
        _notifiedStages.contains(current)) {
      return;
    }
    _notifiedStages.add(current);

    if (current == OrderTrackingStage.orderConfirmed &&
        !_didNotifyOrderConfirmed) {
      _didNotifyOrderConfirmed = true;
      try {
        await OrderNotificationService.createOrderConfirmedNotification(
          orderId: _order.orderId.isNotEmpty
              ? _order.orderId
              : _order.transactionId,
          orderNumber: _order.orderNumber.isNotEmpty
              ? _order.orderNumber
              : _order.transactionId,
          totalAmount: _order.totalAmount.toStringAsFixed(2),
          items: _order.items.map((e) => e.toMap()).toList(),
        );
      } catch (e, st) {
        NonUiErrorReporter.report(
          'OrderTrackingProvider.createOrderConfirmedNotification',
          e,
          st,
        );
      }
      if (_isDisposed) return;
      try {
        onOrderConfirmedStageUi?.call(_order);
      } catch (e, st) {
        NonUiErrorReporter.report(
          'OrderTrackingProvider.onOrderConfirmedStageUi',
          e,
          st,
        );
      }
      return;
    }

    final orderNumber = _order.orderNumber.isNotEmpty
        ? _order.orderNumber
        : _order.transactionId;
    final (title, message) = orderStatusNotificationContent(
      orderNumber,
      _order.rawStatus,
    );
    try {
      await OrderNotificationService.createOrderStatusNotification(
        orderId: _order.orderId.isNotEmpty
            ? _order.orderId
            : _order.transactionId,
        orderNumber: orderNumber,
        status: _order.rawStatus,
        title: title,
        message: message,
        totalAmount: _order.totalAmount.toStringAsFixed(2),
        items: _order.items.map((e) => e.toMap()).toList(),
      );
    } catch (e, st) {
      NonUiErrorReporter.report(
        'OrderTrackingProvider.createOrderStatusNotification',
        e,
        st,
      );
    }
  }

  void _stopPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _manualRefreshTimer?.cancel();
    _manualRefreshTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _paymentPollTimer?.cancel();
    _trackingPollTimer?.cancel();
    _manualRefreshTimer?.cancel();
    super.dispose();
  }
}
