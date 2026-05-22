import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_tracking_model.dart';
import '../providers/cart_provider.dart';
import '../utils/non_ui_error_reporter.dart';
import 'native_notification_service.dart';
import 'order_tracking_service.dart';

/// Keeps polling payment status after the user leaves [PostCheckoutOrderPage].
class PendingPaymentPollingService {
  PendingPaymentPollingService._();

  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _manualRefreshDelay = Duration(seconds: 10);
  static const int _maxEmptyResponses = 36;
  static const int _maxEmptyResponseMinutes = 3;
  static const String _prefsActiveKey = 'pending_payment_check_active';

  static final OrderTrackingService _service = OrderTrackingService();
  static Timer? _pollTimer;
  static Timer? _manualRefreshTimer;
  static OrderTrackingModel? _order;
  static String? _initialTransactionId;
  static DateTime? _firstEmptyResponseTime;
  static int _emptyResponseCount = 0;
  static bool _didHandleSuccessfulOrder = false;

  static bool get isActive => _pollTimer != null;

  static String? get activeTransactionId => _order?.transactionId;

  static OrderTrackingModel? get orderSnapshot => _order;

  /// Human-readable status while background polling runs.
  static String get statusLabel => 'Checking payment';

  static Future<bool> isActiveForOrder(String? transactionId) async {
    if (transactionId == null || transactionId.isEmpty) return false;
    if (isActive && _order?.transactionId == transactionId) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsActiveKey) == transactionId;
  }

  /// Hand off from confirmation page when user navigates away during payment check.
  static void start({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) {
    if (order.stage != OrderTrackingStage.pendingPayment) return;

    stop();
    _order = order;
    _initialTransactionId = initialTransactionId;
    _firstEmptyResponseTime = null;
    _emptyResponseCount = 0;
    _didHandleSuccessfulOrder = false;

    unawaited(_persistActive(true));
    unawaited(_pollOnce());
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollOnce());
    });
    _manualRefreshTimer = Timer(_manualRefreshDelay, () {
      // No UI; polling already running.
    });

    debugPrint(
      '📦 PendingPaymentPollingService: started for ${order.transactionId}',
    );
  }

  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _manualRefreshTimer?.cancel();
    _manualRefreshTimer = null;
    _order = null;
    _initialTransactionId = null;
    _firstEmptyResponseTime = null;
    _emptyResponseCount = 0;
    unawaited(_persistActive(false));
    debugPrint('📦 PendingPaymentPollingService: stopped');
  }

  static Future<void> _persistActive(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!active) {
        await prefs.remove(_prefsActiveKey);
        return;
      }
      final id = _order?.transactionId ?? '';
      if (id.isNotEmpty) {
        await prefs.setString(_prefsActiveKey, id);
      }
    } catch (e, st) {
      NonUiErrorReporter.report(
        'PendingPaymentPollingService._persistActive',
        e,
        st,
      );
    }
  }

  static Future<void> _pollOnce() async {
    if (_order == null) return;
    try {
      final result = await _service.checkPaymentStatus();
      if (_order == null) return;

      _handleEmptyResponses(result);
      _order = _service.applyPaymentStatus(_order!, result);

      if (result.status == 'success') {
        await _handleSuccessfulOrder();
      } else if (result.status == 'failed' ||
          _order!.stage == OrderTrackingStage.failed) {
        stop();
      }
    } catch (e, st) {
      NonUiErrorReporter.report(
        'PendingPaymentPollingService._pollOnce',
        e,
        st,
      );
    }
  }

  static void _handleEmptyResponses(PaymentStatusResult result) {
    if (_order == null) return;
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
      _order = _order!.copyWith(
        rawStatus: 'failed',
        stage: OrderTrackingStage.failed,
        stageLabel: _service.stageLabel(OrderTrackingStage.failed),
        stageMessage:
            'Payment verification timed out. Please try again or contact support.',
        timelineSteps:
            _service.buildTimeline(OrderTrackingStage.orderPlaced),
      );
      stop();
    }
  }

  static Future<void> _handleSuccessfulOrder() async {
    if (_order == null) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _manualRefreshTimer?.cancel();
    _manualRefreshTimer = null;

    try {
      _order = await _service.refreshOrder(_order!);
    } catch (e, st) {
      NonUiErrorReporter.report(
        'PendingPaymentPollingService._handleSuccessfulOrder.refresh',
        e,
        st,
      );
    }
    if (_order == null) return;

    if (!_didHandleSuccessfulOrder) {
      _didHandleSuccessfulOrder = true;
      try {
        await _service.handleOrderConfirmed(
          order: _order!,
          initialTransactionId: _initialTransactionId,
        );
      } catch (e, st) {
        NonUiErrorReporter.report(
          'PendingPaymentPollingService.handleOrderConfirmed',
          e,
          st,
        );
      }

      _clearCartIfPossible();
    }

    await _persistActive(false);
    _order = null;
    _initialTransactionId = null;
    debugPrint('📦 PendingPaymentPollingService: payment confirmed');
  }

  static void _clearCartIfPossible() {
    try {
      final context = NativeNotificationService.globalNavigatorKey.currentContext;
      if (context == null) return;
      Provider.of<CartProvider>(context, listen: false).clearCart();
    } catch (e, st) {
      NonUiErrorReporter.report(
        'PendingPaymentPollingService._clearCartIfPossible',
        e,
        st,
      );
    }
  }
}
