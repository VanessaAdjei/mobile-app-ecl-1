import '../database/product/product_detail_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class ProductDetailRepository {
  Future<CategoryFetchResult> fetchProductDetails(
    String urlName, {
    Duration timeout,
  });

  Future<CategoryFetchResult> fetchRelatedProducts(
    String urlName, {
    Duration timeout,
  });
}

class ProductDetailRepositoryImpl implements ProductDetailRepository {
  ProductDetailRepositoryImpl([ProductDetailRemoteDataSource? remote])
      : _remote = remote ?? ProductDetailRemoteDataSourceImpl();

  final ProductDetailRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchProductDetails(
    String urlName, {
    Duration timeout = const Duration(seconds: 30),
  }) =>
      _remote.fetchProductDetails(urlName, timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchRelatedProducts(
    String urlName, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _remote.fetchRelatedProducts(urlName, timeout: timeout);
}
