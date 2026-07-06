import '../database/order_tracking/order_tracking_local_data_source.dart';
import '../database/order_tracking/order_tracking_remote_data_source.dart';
import '../models/order_tracking_model.dart';

abstract class OrderTrackingRepository {
  Future<PaymentStatusResult> checkPaymentStatus();

  Future<String?> fetchOrderStatus(String orderId);

  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
    String? checkoutOrderId,
  });

  Future<void> handleOrderConfirmed({
    required OrderTrackingModel order,
    String? initialTransactionId,
    bool isGuestCheckout = false,
  });

  Future<void> persistCheckoutBilling({
    required OrderTrackingModel order,
    String? initialTransactionId,
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

class OrderTrackingRepositoryImpl implements OrderTrackingRepository {
  OrderTrackingRepositoryImpl([
    OrderTrackingRemoteDataSource? remoteDataSource,
    OrderTrackingLocalDataSource? localDataSource,
  ])
      : _remoteDataSource =
            remoteDataSource ?? OrderTrackingRemoteDataSourceImpl(),
        _localDataSource = localDataSource ?? OrderTrackingLocalDataSourceImpl();

  final OrderTrackingRemoteDataSource _remoteDataSource;
  final OrderTrackingLocalDataSource _localDataSource;

  @override
  Future<PaymentStatusResult> checkPaymentStatus() {
    return _remoteDataSource.checkPaymentStatus();
  }

  @override
  Future<String?> fetchOrderStatus(String orderId) {
    return _remoteDataSource.fetchOrderStatus(orderId);
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
    String? checkoutOrderId,
  }) {
    return _remoteDataSource.fetchLatestOrderSnapshot(
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
      checkoutOrderId: checkoutOrderId,
    );
  }

  @override
  Future<void> handleOrderConfirmed({
    required OrderTrackingModel order,
    String? initialTransactionId,
    bool isGuestCheckout = false,
  }) async {
    await _localDataSource.storeOrderAmounts(
      order: order,
      initialTransactionId: initialTransactionId,
    );
    await _localDataSource.createOrderPlacedNotification(
      order,
      isGuestCheckout: isGuestCheckout,
    );
  }

  @override
  Future<void> persistCheckoutBilling({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) {
    return _localDataSource.storeOrderAmounts(
      order: order,
      initialTransactionId: initialTransactionId,
    );
  }

  @override
  Future<Map<String, DateTime>> loadStageTimestamps(String orderKey) {
    return _localDataSource.loadStageTimestamps(orderKey);
  }

  @override
  Future<void> recordStageTimestampIfAbsent(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  ) {
    return _localDataSource.recordStageTimestampIfAbsent(
      orderKey,
      stageId,
      occurredAt,
    );
  }

  @override
  Future<int> loadHighestTimelineIndex(String orderKey) {
    return _localDataSource.loadHighestTimelineIndex(orderKey);
  }

  @override
  Future<void> upsertStageTimestamp(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  ) {
    return _localDataSource.upsertStageTimestamp(
      orderKey,
      stageId,
      occurredAt,
    );
  }

  @override
  Future<void> saveStageTimestamps(
    String orderKey,
    Map<String, DateTime> timestamps,
  ) {
    return _localDataSource.saveStageTimestamps(orderKey, timestamps);
  }

  @override
  Future<void> saveHighestTimelineIndexIfHigher(
    String orderKey,
    int timelineIndex,
  ) {
    return _localDataSource.saveHighestTimelineIndexIfHigher(
      orderKey,
      timelineIndex,
    );
  }

  @override
  Future<void> saveStatusHint({
    required String status,
    String? orderId,
    String? orderNumber,
    String? transactionId,
  }) {
    return _localDataSource.saveStatusHint(
      status: status,
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
    );
  }

  @override
  Future<List<String>> loadStatusHints(Set<String> lookupKeys) {
    return _localDataSource.loadStatusHints(lookupKeys);
  }
}
