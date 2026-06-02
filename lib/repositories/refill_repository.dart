import '../database/refill/refill_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class RefillRepository {
  Future<CategoryFetchResult> fetchRefillList({
    required String authToken,
    Duration timeout,
  });

  Future<CategoryFetchResult> addToCart({
    required String authToken,
    required Map<String, dynamic> body,
    Duration timeout,
  });
}

class RefillRepositoryImpl implements RefillRepository {
  RefillRepositoryImpl([RefillRemoteDataSource? remote])
      : _remote = remote ?? RefillRemoteDataSourceImpl();

  final RefillRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchRefillList({
    required String authToken,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _remote.fetchRefillList(authToken: authToken, timeout: timeout);

  @override
  Future<CategoryFetchResult> addToCart({
    required String authToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.addToCart(
        authToken: authToken,
        body: body,
        timeout: timeout,
      );
}
