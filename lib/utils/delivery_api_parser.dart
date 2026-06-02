import '../models/store_location_model.dart';

/// Extract list payload from common delivery/location API response shapes.
List<dynamic> extractDeliveryListPayload(dynamic decodedBody) {
  if (decodedBody is List) return decodedBody;
  if (decodedBody is! Map<String, dynamic>) return [];

  final data = decodedBody['data'];
  if (data is List) return data;

  if (data is Map<String, dynamic>) {
    final nested = data['data'];
    if (nested is List) return nested;
  }

  for (final key in const ['regions', 'cities', 'stores', 'results', 'items']) {
    final value = decodedBody[key];
    if (value is List) return value;
  }

  return [];
}

List<Map<String, dynamic>> normalizeDeliveryDescriptionField(
  List<dynamic> items,
) {
  return items
      .whereType<Map>()
      .map((raw) => Map<String, dynamic>.from(raw))
      .map((item) {
        final label = (item['description'] ??
                item['name'] ??
                item['title'] ??
                item['label'] ??
                '')
            .toString();
        if (item['description'] == null && label.isNotEmpty) {
          item['description'] = label;
        }
        return item;
      })
      .toList();
}

List<Map<String, dynamic>> normalizeDeliveryStoreRecords(List<dynamic> items) {
  return items
      .whereType<Map>()
      .map((raw) => normalizeDeliveryStoreMap(Map<String, dynamic>.from(raw)))
      .toList();
}

Map<String, dynamic> normalizeDeliveryStoreMap(Map<String, dynamic> raw) {
  return StoreLocationModel.fromApiJson(raw).toMap();
}
