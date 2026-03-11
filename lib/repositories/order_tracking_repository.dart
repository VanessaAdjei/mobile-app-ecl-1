import '../database/order_tracking/order_tracking_remote_data_source.dart';
import '../models/order_tracking_model.dart';

abstract class OrderTrackingRepository {
  Future<PaymentStatusResult> checkPaymentStatus();

  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
  });
}

class OrderTrackingRepositoryImpl implements OrderTrackingRepository {
  OrderTrackingRepositoryImpl([OrderTrackingRemoteDataSource? remoteDataSource])
      : _remoteDataSource =
            remoteDataSource ?? OrderTrackingRemoteDataSourceImpl();

  final OrderTrackingRemoteDataSource _remoteDataSource;

  @override
  Future<PaymentStatusResult> checkPaymentStatus() {
    return _remoteDataSource.checkPaymentStatus();
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestOrderSnapshot({
    required String orderId,
    required String orderNumber,
    required String transactionId,
  }) {
    return _remoteDataSource.fetchLatestOrderSnapshot(
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
    );
  }
}
