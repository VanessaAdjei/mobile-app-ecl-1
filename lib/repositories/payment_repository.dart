import '../database/payment/payment_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class PaymentRepository {
  Future<CategoryFetchResult> submitExpressPayment({
    required Map<String, dynamic> params,
    required Map<String, String> headers,
    Duration timeout,
  });

  Future<CategoryFetchResult> checkPayment({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout,
  });

  Future<CategoryFetchResult> applyCoupon({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout,
  });
}

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl([PaymentRemoteDataSource? remote])
      : _remote = remote ?? PaymentRemoteDataSourceImpl();

  final PaymentRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> submitExpressPayment({
    required Map<String, dynamic> params,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 60),
  }) =>
      _remote.submitExpressPayment(
        params: params,
        headers: headers,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> checkPayment({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.checkPayment(headers: headers, body: body, timeout: timeout);

  @override
  Future<CategoryFetchResult> applyCoupon({
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.applyCoupon(headers: headers, body: body, timeout: timeout);
}
