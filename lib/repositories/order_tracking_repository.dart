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
}
