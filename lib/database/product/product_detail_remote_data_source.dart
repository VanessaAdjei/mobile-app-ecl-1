import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class ProductDetailRemoteDataSource {
  Future<CategoryFetchResult> fetchProductDetails(
    String urlName, {
    Duration timeout = const Duration(seconds: 10),
  });

  Future<CategoryFetchResult> fetchRelatedProducts(
    String urlName, {
    Duration timeout = const Duration(seconds: 8),
  });
}

class ProductDetailRemoteDataSourceImpl implements ProductDetailRemoteDataSource {
  ProductDetailRemoteDataSourceImpl();

  Future<CategoryFetchResult> _get(Uri uri, Duration timeout) async {
    try {
      final response = await HttpClientService.get(uri).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> fetchProductDetails(
    String urlName, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _get(Uri.parse(ApiConfig.getProductDetailsUrl(urlName)), timeout);
  }

  @override
  Future<CategoryFetchResult> fetchRelatedProducts(
    String urlName, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(Uri.parse(ApiConfig.getRelatedProductsUrl(urlName)), timeout);
  }
}
