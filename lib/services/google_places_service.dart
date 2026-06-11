import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/category_fetch_result.dart';
import '../models/map_place_suggestion.dart';
import '../repositories/google_places_repository.dart';

class GooglePlacesService {
  GooglePlacesService({GooglePlacesRepository? repository})
      : _repository = repository ?? GooglePlacesRepositoryImpl();

  final GooglePlacesRepository _repository;

  void _logMapsApiStatus(String api, Map<String, dynamic> body) {
    final status = body['status']?.toString() ?? 'UNKNOWN';
    if (status == 'OK' || status == 'ZERO_RESULTS') return;
    final message = body['error_message']?.toString();
    debugPrint(
      '🗺️ [Places] $api status=$status'
      '${message != null && message.isNotEmpty ? ' — $message' : ''}',
    );
    if (status == 'REQUEST_DENIED') {
      debugPrint(
        '🗺️ [Places] Enable Places API, Geocoding API, and use a '
        'Maps web-service key (GOOGLE_MAPS_API_KEY in .env).',
      );
    }
  }

  Future<List<({String description, String placeId})>> autocompletePredictions(
    String query, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (query.length < 2 || !ApiConfig.hasGoogleMapsApiKey) return const [];

    final result = await _repository.autocomplete(
      input: query,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return const [];

    final body = result.body!;
    _logMapsApiStatus('Autocomplete', body);
    if (body['status'] != 'OK' || body['predictions'] is! List) {
      return const [];
    }

    final out = <({String description, String placeId})>[];
    for (final prediction in body['predictions']) {
      if (prediction is! Map) continue;
      final description = prediction['description']?.toString();
      final placeId = prediction['place_id']?.toString();
      if (description == null ||
          description.isEmpty ||
          placeId == null ||
          placeId.isEmpty) {
        continue;
      }
      if (out.any((p) => p.placeId == placeId)) continue;
      out.add((description: description, placeId: placeId));
      if (out.length >= 12) break;
    }
    return out;
  }

  Future<List<MapPlaceSuggestion>> _textSearchSuggestions(
    String query, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!ApiConfig.hasGoogleMapsApiKey) return const [];

    final result = await _repository.textSearch(
      query: query,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return const [];

    final body = result.body!;
    _logMapsApiStatus('TextSearch', body);
    if (body['status'] != 'OK' || body['results'] is! List) return const [];

    final out = <MapPlaceSuggestion>[];
    for (final row in body['results'] as List) {
      if (row is! Map) continue;
      final name = row['name']?.toString();
      final formatted = row['formatted_address']?.toString();
      final placeId = row['place_id']?.toString();
      final geometry = row['geometry'];
      double? lat;
      double? lng;
      if (geometry is Map && geometry['location'] is Map) {
        final loc = geometry['location'] as Map;
        lat = (loc['lat'] as num?)?.toDouble();
        lng = (loc['lng'] as num?)?.toDouble();
      }
      final description = formatted?.isNotEmpty == true
          ? (name != null && name.isNotEmpty && !formatted!.startsWith(name)
              ? '$name, $formatted'
              : formatted!)
          : name;
      if (description == null || description.isEmpty) continue;
      out.add(
        MapPlaceSuggestion(
          description: description,
          placeId: placeId,
          latitude: lat,
          longitude: lng,
        ),
      );
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<MapPlaceSuggestion?> _geocodeSuggestion(
    String address, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!ApiConfig.hasGoogleMapsApiKey) return null;

    final result = await _repository.geocode(
      address: address,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return null;

    final body = result.body!;
    _logMapsApiStatus('Geocode', body);
    if (body['status'] != 'OK' || body['results'] is! List) return null;

    final results = body['results'] as List;
    if (results.isEmpty || results.first is! Map) return null;

    final first = Map<String, dynamic>.from(results.first as Map);
    final formatted = first['formatted_address']?.toString();
    final geometry = first['geometry'];
    if (geometry is! Map || geometry['location'] is! Map) return null;

    final loc = Map<String, dynamic>.from(geometry['location'] as Map);
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return MapPlaceSuggestion(
      description: formatted ?? address,
      placeId: first['place_id']?.toString(),
      latitude: lat,
      longitude: lng,
    );
  }

  /// Combined suggestions for map search (autocomplete + text search + geocode).
  Future<List<MapPlaceSuggestion>> searchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final out = <MapPlaceSuggestion>[];
    final seen = <String>{};

    void add(MapPlaceSuggestion item) {
      final key = item.placeId ?? item.description.toLowerCase();
      if (seen.add(key)) out.add(item);
    }

    try {
      final autocomplete = await autocompletePredictions(trimmed);
      for (final p in autocomplete) {
        add(MapPlaceSuggestion(description: p.description, placeId: p.placeId));
      }
    } catch (e) {
      debugPrint('🗺️ [Places] Autocomplete error: $e');
    }

    if (out.length < 8) {
      try {
        final textQuery = trimmed.toLowerCase().contains('ghana')
            ? trimmed
            : '$trimmed, Ghana';
        final textHits = await _textSearchSuggestions(textQuery);
        for (final hit in textHits) {
          add(hit);
        }
      } catch (e) {
        debugPrint('🗺️ [Places] Text search error: $e');
      }
    }

    if (out.length < 5) {
      final geocodeQueries = [
        if (!trimmed.toLowerCase().contains('ghana')) '$trimmed, Ghana',
        trimmed,
      ];
      for (final q in geocodeQueries) {
        if (out.length >= 10) break;
        try {
          final geo = await _geocodeSuggestion(q);
          if (geo != null) add(geo);
        } catch (e) {
          debugPrint('🗺️ [Places] Geocode error for "$q": $e');
        }
      }
    }

    return out.take(15).toList();
  }

  Future<List<String>> autocompleteDescriptions(
    String query, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final suggestions = await searchSuggestions(query);
    return suggestions.map((s) => s.description).toList();
  }

  Future<String?> findPlaceIdForDescription(
    String query, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final suggestions = await searchSuggestions(query);
    if (suggestions.isEmpty) return null;

    final normalized = query.trim().toLowerCase();
    for (final suggestion in suggestions) {
      final id = suggestion.placeId;
      if (id != null &&
          suggestion.description.trim().toLowerCase() == normalized) {
        return id;
      }
    }
    return suggestions.firstWhere(
      (s) => s.placeId != null,
      orElse: () => suggestions.first,
    ).placeId;
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(
    String placeId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!ApiConfig.hasGoogleMapsApiKey) return null;

    final result = await _repository.placeDetails(
      placeId: placeId,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return null;

    final body = result.body!;
    _logMapsApiStatus('PlaceDetails', body);
    if (body['status'] != 'OK' || body['result'] is! Map) return null;
    return Map<String, dynamic>.from(body['result'] as Map);
  }

  /// Reverse geocode coordinates to a formatted address (Google Geocoding API).
  Future<String?> reverseGeocodeCoordinates(
    double lat,
    double lng, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!ApiConfig.hasGoogleMapsApiKey) return null;

    final result = await _repository.reverseGeocode(
      latitude: lat,
      longitude: lng,
      timeout: timeout,
    );
    if (!result.isHttpOk || result.body == null) return null;

    final body = result.body!;
    _logMapsApiStatus('ReverseGeocode', body);
    if (body['status'] != 'OK' || body['results'] is! List) return null;

    final results = body['results'] as List;
    if (results.isEmpty || results.first is! Map) return null;

    final first = Map<String, dynamic>.from(results.first as Map);
    final formatted = first['formatted_address']?.toString();
    if (formatted == null || formatted.trim().isEmpty) return null;
    return formatted.trim();
  }

  /// Resolves a query or suggestion to coordinates for the map picker.
  Future<({double lat, double lng, String label})?> resolveToCoordinates({
    required String query,
    String? placeId,
    double? latitude,
    double? longitude,
  }) async {
    if (latitude != null && longitude != null) {
      return (lat: latitude, lng: longitude, label: query);
    }

    if (placeId != null) {
      final details = await fetchPlaceDetails(placeId);
      final location = details?['geometry']?['location'];
      if (location is Map) {
        final lat = (location['lat'] as num?)?.toDouble();
        final lng = (location['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final label = details?['name']?.toString() ??
              details?['formatted_address']?.toString() ??
              query;
          return (lat: lat, lng: lng, label: label);
        }
      }
    }

    final trimmed = query.trim();
    final geocodeQueries = [
      if (!trimmed.toLowerCase().contains('ghana')) '$trimmed, Ghana',
      trimmed,
    ];
    for (final q in geocodeQueries) {
      final geo = await _geocodeSuggestion(q);
      if (geo != null && geo.hasCoordinates) {
        return (
          lat: geo.latitude!,
          lng: geo.longitude!,
          label: geo.description,
        );
      }
    }

    final textHits = await _textSearchSuggestions(
      trimmed.toLowerCase().contains('ghana') ? trimmed : '$trimmed, Ghana',
    );
    if (textHits.isNotEmpty && textHits.first.hasCoordinates) {
      final hit = textHits.first;
      return (
        lat: hit.latitude!,
        lng: hit.longitude!,
        label: hit.description,
      );
    }

    return null;
  }

  void rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
