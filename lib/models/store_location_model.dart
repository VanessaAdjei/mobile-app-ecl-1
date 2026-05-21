/// Store row from `GET /cities/{cityId}/stores` (ECL commerce API).
class StoreLocationModel {
  const StoreLocationModel({
    required this.id,
    required this.cityId,
    required this.description,
    this.lat,
    this.lng,
    this.status,
    this.openingTime,
    this.closingTime,
    this.createdAt,
    this.updatedAt,
    this.regionName,
    this.cityName,
  });

  final int id;
  final int cityId;
  final String description;
  final double? lat;
  final double? lng;
  final String? status;
  final String? openingTime;
  final String? closingTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? regionName;
  final String? cityName;

  static const _openingKeys = [
    'opening_time',
    'openingTime',
    'open_time',
    'openTime',
    'opens_at',
    'opening_hour',
    'opening_hours',
    'open',
  ];

  static const _closingKeys = [
    'closing_time',
    'closingTime',
    'close_time',
    'closeTime',
    'closes_at',
    'closing_hour',
    'closing_hours',
    'close',
  ];

  static double? _parseCoord(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _readTimeField(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final formatted = _formatTimeValue(json[key]);
      if (formatted != null) return formatted;
    }

    final hours = json['hours'];
    if (hours is Map) {
      final nested = Map<String, dynamic>.from(hours);
      for (final key in keys) {
        if (!nested.containsKey(key)) continue;
        final formatted = _formatTimeValue(nested[key]);
        if (formatted != null) return formatted;
      }
    }

    return null;
  }

  static String? _formatTimeValue(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      for (final key in ['formatted', 'display', 'label', 'time', 'value']) {
        if (value[key] != null) {
          final inner = _formatTimeValue(value[key]);
          if (inner != null) return inner;
        }
      }
      return null;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    if (raw.contains('T')) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return _formatHourMinute(dt.hour, dt.minute);
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(raw);
    if (match != null) {
      final hour = int.tryParse(match.group(1)!) ?? -1;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      if (hour >= 0 && hour < 24) {
        return _formatHourMinute(hour, minute);
      }
    }

    return raw;
  }

  static String _formatHourMinute(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minutePart =
        minute == 0 ? '' : ':${minute.toString().padLeft(2, '0')}';
    return '$displayHour$minutePart $period';
  }

  factory StoreLocationModel.fromApiJson(Map<String, dynamic> json) {
    final description = (json['description'] ??
            json['name'] ??
            json['address'] ??
            '')
        .toString()
        .trim();

    return StoreLocationModel(
      id: _parseInt(json['id']),
      cityId: _parseInt(json['city_id']),
      description: description,
      lat: _parseCoord(json['lat'] ?? json['latitude']),
      lng: _parseCoord(json['lng'] ?? json['longitude']),
      status: json['status']?.toString(),
      openingTime: _readTimeField(json, _openingKeys),
      closingTime: _readTimeField(json, _closingKeys),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      regionName: json['region_name']?.toString(),
      cityName: json['city_name']?.toString(),
    );
  }

  /// Hours label for any store map (raw API or normalized).
  static String hoursLabelFromMap(Map<String, dynamic> json) {
    return StoreLocationModel.fromApiJson(json).hoursDisplay;
  }

  Map<String, dynamic> toMap() {
    final latStr = lat?.toString();
    final lngStr = lng?.toString();
    return {
      'id': id,
      'city_id': cityId,
      'description': description,
      'address': description,
      if (latStr != null) 'lat': latStr,
      if (lngStr != null) 'lng': lngStr,
      if (latStr != null) 'latitude': latStr,
      if (lngStr != null) 'longitude': lngStr,
      if (status != null) 'status': status,
      'opening_time': openingTime ?? '',
      'closing_time': closingTime ?? '',
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (regionName != null) 'region_name': regionName,
      if (cityName != null) 'city_name': cityName,
    };
  }

  StoreLocationModel copyWith({
    String? regionName,
    String? cityName,
  }) {
    return StoreLocationModel(
      id: id,
      cityId: cityId,
      description: description,
      lat: lat,
      lng: lng,
      status: status,
      openingTime: openingTime,
      closingTime: closingTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
      regionName: regionName ?? this.regionName,
      cityName: cityName ?? this.cityName,
    );
  }

  String get hoursDisplay {
    final open = openingTime?.trim();
    final close = closingTime?.trim();
    if (open != null &&
        open.isNotEmpty &&
        close != null &&
        close.isNotEmpty) {
      return '$open – $close';
    }
    if (open != null && open.isNotEmpty) return 'Opens $open';
    if (close != null && close.isNotEmpty) return 'Closes $close';
    return 'Hours not listed';
  }

  bool get hasCoordinates =>
      lat != null && lng != null && lat != 0 && lng != 0;
}
