import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

/// Raw HTTP access for product catalog endpoints (homepage, ProductCache).
/// Raw HTTP result for large catalog payloads (parse on a background isolate).
class CatalogRawHttpResult {
  const CatalogRawHttpResult({
    required this.statusCode,
    required this.body,
    this.error,
  });

  final int statusCode;
  final String body;
  final Object? error;

  bool get isHttpOk => statusCode == 200 && body.trim().isNotEmpty;
}

abstract class ProductRemoteDataSource {
  Future<CatalogRawHttpResult> fetchAllProductsRaw({
    Duration timeout = const Duration(seconds: 30),
  });

  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 30),
  });

  Future<CategoryFetchResult> fetchHomePriorityProducts({
    Duration timeout = const Duration(seconds: 8),
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
  Future<CatalogRawHttpResult> fetchAllProductsRaw({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getAllProducts));
    try {
      final response = await HttpClientService.get(uri).timeout(timeout);
      return CatalogRawHttpResult(
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (e) {
      return CatalogRawHttpResult(statusCode: 0, body: '', error: e);
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
  Future<CategoryFetchResult> fetchHomePriorityProducts({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getHomePriority)),
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
