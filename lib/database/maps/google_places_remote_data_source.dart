import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class GooglePlacesRemoteDataSource {
  Future<CategoryFetchResult> autocomplete({
    required String input,
    String types = 'establishment',
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> placeDetails({
    required String placeId,
    String fields = 'geometry,formatted_address,name',
    Duration timeout = const Duration(seconds: 10),
  });
}

class GooglePlacesRemoteDataSourceImpl implements GooglePlacesRemoteDataSource {
  static const _autocompleteBase =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsBase =
      'https://maps.googleapis.com/maps/api/place/details/json';

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
  Future<CategoryFetchResult> autocomplete({
    required String input,
    String types = 'establishment',
    Duration timeout = const Duration(seconds: 5),
  }) {
    final uri = Uri.parse(_autocompleteBase).replace(
      queryParameters: {
        'input': input,
        'key': ApiConfig.googleMapsApiKey,
        'components': 'country:gh',
        if (types.isNotEmpty) 'types': types,
      },
    );
    return _get(uri, timeout);
  }

  @override
  Future<CategoryFetchResult> placeDetails({
    required String placeId,
    String fields = 'geometry,formatted_address,name',
    Duration timeout = const Duration(seconds: 10),
  }) {
    final uri = Uri.parse(_detailsBase).replace(
      queryParameters: {
        'place_id': placeId,
        'key': ApiConfig.googleMapsApiKey,
        'fields': fields,
      },
    );
    return _get(uri, timeout);
  }
}
