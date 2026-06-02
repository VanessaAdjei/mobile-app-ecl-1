/// A place row for map search (autocomplete, text search, or geocode).
class MapPlaceSuggestion {
  const MapPlaceSuggestion({
    required this.description,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  final String description;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}
