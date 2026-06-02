import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

/// Raw HTTP access for product catalog endpoints (homepage, ProductCache).
abstract class ProductRemoteDataSource {
  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 30),
  });

  Future<CategoryFetchResult> fetchPopularProducts({
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 10),
  });
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  ProductRemoteDataSourceImpl();

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
  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getAllProducts)),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchPopularProducts({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.popularProducts)),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _get(Uri.parse(ApiConfig.getSearchUrl(query)), timeout);
  }
}
