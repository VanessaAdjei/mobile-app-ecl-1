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
  });

  Future<Map<String, DateTime>> loadStageTimestamps(String orderKey);

  Future<void> recordStageTimestampIfAbsent(
    String orderKey,
    String stageId,
    DateTime occurredAt,
  );
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
  }) async {
    await _localDataSource.storeOrderAmounts(
      order: order,
      initialTransactionId: initialTransactionId,
    );
    await _localDataSource.createOrderPlacedNotification(order);
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
}
