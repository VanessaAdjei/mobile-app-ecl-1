import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class DeliveryRemoteDataSource {
  Future<CategoryFetchResult> fetchRegions({
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> fetchCitiesByRegion(
    int regionId, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> fetchStoresByCity(
    int cityId, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> saveBillingAddress({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> getBillingAddress({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> calculateDeliveryFee({
    required Map<String, String> headers,
    required String body,
    required bool formEncoded,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> fetchDeliveryGeofence({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> validateGeofence({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 8),
  });
}

class DeliveryRemoteDataSourceImpl implements DeliveryRemoteDataSource {
  Future<CategoryFetchResult> _get(Uri uri, Duration timeout) async {
    try {
      final response = await HttpClientService.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  Future<CategoryFetchResult> _post(
    Uri uri,
    Map<String, String> headers,
    String body,
    Duration timeout,
  ) async {
    try {
      final response = await HttpClientService.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> fetchRegions({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.regions)), timeout);
  }

  @override
  Future<CategoryFetchResult> fetchCitiesByRegion(
    int regionId, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getRegionCitiesUrl(regionId.toString())),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchStoresByCity(
    int cityId, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getCityStoresUrl(cityId.toString())),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> saveBillingAddress({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _post(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.saveBillingAddress)),
      headers,
      body,
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> getBillingAddress({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await HttpClientService.get(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getBillingAddress)),
        headers: headers,
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> calculateDeliveryFee({
    required Map<String, String> headers,
    required String body,
    required bool formEncoded,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final uri =
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.calculateDeliveryFee));
    if (formEncoded) {
      final formHeaders = <String, String>{
        ...headers,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      return _post(uri, formHeaders, body, timeout);
    }
    final jsonHeaders = <String, String>{
      ...headers,
      'Content-Type': 'application/json',
    };
    return _post(uri, jsonHeaders, body, timeout);
  }

  @override
  Future<CategoryFetchResult> fetchDeliveryGeofence({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final response = await HttpClientService.get(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.deliveryGeofence)),
        headers: headers,
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> validateGeofence({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _post(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.validateGeofence)),
      headers,
      body,
      timeout,
    );
  }
}
