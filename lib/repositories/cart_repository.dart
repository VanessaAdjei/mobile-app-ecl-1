import '../database/cart/cart_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class CartRepository {
  Future<CategoryFetchResult> fetchCheckoutCart({
    required String hashedLink,
    required Map<String, String> headers,
    Duration timeout,
  });

  Future<CategoryFetchResult> postCheckAuth({
    required Map<String, String> headers,
    required String body,
    Duration timeout,
  });

  Future<CategoryFetchResult> postRemoveFromCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout,
  });

  Future<CategoryFetchResult> deleteCheckoutItem({
    required String itemId,
    required Map<String, String> headers,
    Duration timeout,
  });

  Future<CategoryFetchResult> syncCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout,
  });
}

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl([CartRemoteDataSource? remote])
      : _remote = remote ?? CartRemoteDataSourceImpl();

  final CartRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchCheckoutCart({
    required String hashedLink,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.fetchCheckoutCart(
        hashedLink: hashedLink,
        headers: headers,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> postCheckAuth({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _remote.postCheckAuth(
        headers: headers,
        body: body,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> postRemoveFromCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _remote.postRemoveFromCart(
        headers: headers,
        body: body,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> deleteCheckoutItem({
    required String itemId,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 3),
  }) =>
      _remote.deleteCheckoutItem(
        itemId: itemId,
        headers: headers,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> syncCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _remote.syncCart(
        headers: headers,
        body: body,
        timeout: timeout,
      );
}
