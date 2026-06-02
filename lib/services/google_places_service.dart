import '../models/category_fetch_result.dart';
import '../repositories/google_places_repository.dart';

class GooglePlacesService {
  GooglePlacesService({GooglePlacesRepository? repository})
      : _repository = repository ?? GooglePlacesRepositoryImpl();

  final GooglePlacesRepository _repository;

  Future<List<String>> autocompleteDescriptions(
    String query, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (query.length < 2) return const [];

    final result = await _repository.autocomplete(
      input: query,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return const [];

    final body = result.body!;
    if (body['status'] != 'OK' || body['predictions'] is! List) {
      return const [];
    }

    final out = <String>[];
    for (final prediction in body['predictions']) {
      if (prediction is! Map) continue;
      final description = prediction['description']?.toString();
      if (description != null &&
          description.isNotEmpty &&
          !out.contains(description)) {
        out.add(description);
        if (out.length >= 10) break;
      }
    }
    return out;
  }

  Future<String?> findPlaceIdForDescription(
    String query, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await _repository.autocomplete(
      input: query,
      types: '',
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return null;

    final body = result.body!;
    if (body['status'] != 'OK' || body['predictions'] is! List) return null;

    for (final prediction in body['predictions'] as List) {
      if (prediction is! Map) continue;
      if (prediction['description'] == query) {
        return prediction['place_id']?.toString();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(
    String placeId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await _repository.placeDetails(
      placeId: placeId,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return null;

    final body = result.body!;
    if (body['status'] != 'OK' || body['result'] is! Map) return null;
    return Map<String, dynamic>.from(body['result'] as Map);
  }

  void rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
