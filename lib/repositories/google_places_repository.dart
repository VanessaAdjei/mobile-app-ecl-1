import '../database/maps/google_places_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class GooglePlacesRepository {
  Future<CategoryFetchResult> autocomplete({
    required String input,
    String types,
    Duration timeout,
  });

  Future<CategoryFetchResult> placeDetails({
    required String placeId,
    String fields,
    Duration timeout,
  });

  Future<CategoryFetchResult> textSearch({
    required String query,
    Duration timeout,
  });

  Future<CategoryFetchResult> geocode({
    required String address,
    Duration timeout,
  });
}

class GooglePlacesRepositoryImpl implements GooglePlacesRepository {
  GooglePlacesRepositoryImpl([GooglePlacesRemoteDataSource? remote])
      : _remote = remote ?? GooglePlacesRemoteDataSourceImpl();

  final GooglePlacesRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> autocomplete({
    required String input,
    String types = '',
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _remote.autocomplete(input: input, types: types, timeout: timeout);

  @override
  Future<CategoryFetchResult> placeDetails({
    required String placeId,
    String fields = 'geometry,formatted_address,name',
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _remote.placeDetails(
        placeId: placeId,
        fields: fields,
        timeout: timeout,
      );

  @override
  Future<CategoryFetchResult> textSearch({
    required String query,
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.textSearch(query: query, timeout: timeout);

  @override
  Future<CategoryFetchResult> geocode({
    required String address,
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.geocode(address: address, timeout: timeout);
}
