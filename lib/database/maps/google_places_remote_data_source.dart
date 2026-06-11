import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class GooglePlacesRemoteDataSource {
  Future<CategoryFetchResult> autocomplete({
    required String input,
    String types = '',
    Duration timeout = const Duration(seconds: 5),
  });

  Future<CategoryFetchResult> placeDetails({
    required String placeId,
    String fields = 'geometry,formatted_address,name',
    Duration timeout = const Duration(seconds: 10),
  });

  Future<CategoryFetchResult> textSearch({
    required String query,
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> geocode({
    required String address,
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> reverseGeocode({
    required double latitude,
    required double longitude,
    Duration timeout = const Duration(seconds: 8),
  });
}

class GooglePlacesRemoteDataSourceImpl implements GooglePlacesRemoteDataSource {
  static const _autocompleteBase =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsBase =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const _textSearchBase =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';

  /// Bias autocomplete toward Ghana (Accra centroid).
  static const _biasLat = '5.6037';
  static const _biasLng = '-0.1870';
  static const _biasRadiusMeters = '500000';

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
    String types = '',
    Duration timeout = const Duration(seconds: 5),
  }) {
    final params = <String, String>{
      'input': input,
      'key': ApiConfig.googleMapsApiKey,
      'components': 'country:gh',
      'language': 'en',
      'location': '$_biasLat,$_biasLng',
      'radius': _biasRadiusMeters,
    };
    if (types.isNotEmpty) params['types'] = types;

    final uri = Uri.parse(_autocompleteBase).replace(queryParameters: params);
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
        'language': 'en',
      },
    );
    return _get(uri, timeout);
  }

  @override
  Future<CategoryFetchResult> textSearch({
    required String query,
    Duration timeout = const Duration(seconds: 8),
  }) {
    final uri = Uri.parse(_textSearchBase).replace(
      queryParameters: {
        'query': query,
        'key': ApiConfig.googleMapsApiKey,
        'region': 'gh',
        'language': 'en',
      },
    );
    return _get(uri, timeout);
  }

  @override
  Future<CategoryFetchResult> geocode({
    required String address,
    Duration timeout = const Duration(seconds: 8),
  }) {
    final uri = Uri.parse(ApiConfig.googleMapsGeocodingUrl).replace(
      queryParameters: {
        'address': address,
        'key': ApiConfig.googleMapsApiKey,
        'components': 'country:GH',
        'language': 'en',
      },
    );
    return _get(uri, timeout);
  }

  @override
  Future<CategoryFetchResult> reverseGeocode({
    required double latitude,
    required double longitude,
    Duration timeout = const Duration(seconds: 8),
  }) {
    final uri = Uri.parse(ApiConfig.googleMapsGeocodingUrl).replace(
      queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': ApiConfig.googleMapsApiKey,
        'language': 'en',
        'result_type': 'street_address|route|neighborhood|locality',
      },
    );
    return _get(uri, timeout);
  }
}
