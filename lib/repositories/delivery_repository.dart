import '../database/delivery/delivery_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class DeliveryRepository {
  Future<CategoryFetchResult> fetchRegions({Duration timeout});
  Future<CategoryFetchResult> fetchCitiesByRegion(int regionId, {Duration timeout});
  Future<CategoryFetchResult> fetchStoresByCity(int cityId, {Duration timeout});
  Future<CategoryFetchResult> saveBillingAddress({
    required Map<String, String> headers,
    required String body,
    Duration timeout,
  });
  Future<CategoryFetchResult> getBillingAddress({
    required Map<String, String> headers,
    Duration timeout,
  });
  Future<CategoryFetchResult> calculateDeliveryFee({
    required Map<String, String> headers,
    required String body,
    required bool formEncoded,
    Duration timeout,
  });
  Future<CategoryFetchResult> addXpressFee({
    required Map<String, String> headers,
    Duration timeout,
  });
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl([DeliveryRemoteDataSource? remote])
      : _remote = remote ?? DeliveryRemoteDataSourceImpl();

  final DeliveryRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchRegions({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchRegions(timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchCitiesByRegion(
    int regionId, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchCitiesByRegion(regionId, timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchStoresByCity(
    int cityId, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchStoresByCity(cityId, timeout: timeout);

  @override
  Future<CategoryFetchResult> saveBillingAddress({
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.saveBillingAddress(
        headers: headers,
        body: body,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> getBillingAddress({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.getBillingAddress(headers: headers, timeout: timeout);

  @override
  Future<CategoryFetchResult> calculateDeliveryFee({
    required Map<String, String> headers,
    required String body,
    required bool formEncoded,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.calculateDeliveryFee(
        headers: headers,
        body: body,
        formEncoded: formEncoded,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> addXpressFee({
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.addXpressFee(headers: headers, timeout: timeout);
}
