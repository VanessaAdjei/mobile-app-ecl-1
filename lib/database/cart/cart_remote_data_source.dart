import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class CartRemoteDataSource {
  Future<CategoryFetchResult> fetchCheckoutCart({
    required String hashedLink,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> postCheckAuth({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  });

  Future<CategoryFetchResult> postRemoveFromCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  });

  Future<CategoryFetchResult> deleteCheckoutItem({
    required String itemId,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 3),
  });

  Future<CategoryFetchResult> syncCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  });
}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  Future<CategoryFetchResult> _toResult(
    Future<dynamic> request,
  ) async {
    try {
      final response = await request;
      return CategoryFetchResult.fromResponse(
        response.statusCode as int,
        response.body as String,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> fetchCheckoutCart({
    required String hashedLink,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _toResult(
      HttpClientService.get(
        Uri.parse(ApiConfig.getCheckoutUrl(hashedLink)),
        headers: headers,
      ).timeout(timeout),
    );
  }

  @override
  Future<CategoryFetchResult> postCheckAuth({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  }) {
    return _toResult(
      HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkAuth)),
        headers: headers,
        body: body,
      ).timeout(timeout),
    );
  }

  @override
  Future<CategoryFetchResult> postRemoveFromCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  }) {
    return _toResult(
      HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.removeFromCart)),
        headers: headers,
        body: body,
      ).timeout(timeout),
    );
  }

  @override
  Future<CategoryFetchResult> deleteCheckoutItem({
    required String itemId,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 3),
  }) {
    return _toResult(
      HttpClientService.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.checkout}/$itemId'),
        headers: headers,
      ).timeout(timeout),
    );
  }

  @override
  Future<CategoryFetchResult> syncCart({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _toResult(
      HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.syncCart)),
        headers: headers,
        body: body,
      ).timeout(timeout),
    );
  }
}
