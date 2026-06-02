import '../database/product/product_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class ProductRepository {
  Future<CategoryFetchResult> fetchAllProducts({Duration timeout});
  Future<CategoryFetchResult> fetchHomePriorityProducts({Duration timeout});
  Future<CategoryFetchResult> fetchPopularProducts({Duration timeout});
  Future<CategoryFetchResult> searchProducts(String query, {Duration timeout});
}

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl([ProductRemoteDataSource? remote])
      : _remote = remote ?? ProductRemoteDataSourceImpl();

  final ProductRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 30),
  }) =>
      _remote.fetchAllProducts(timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchHomePriorityProducts({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchHomePriorityProducts(timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchPopularProducts({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchPopularProducts(timeout: timeout);

  @override
  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _remote.searchProducts(query, timeout: timeout);
}
