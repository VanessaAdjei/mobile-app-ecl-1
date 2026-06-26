class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.region,
    this.city,
    this.lat,
    this.lng,
    this.avatar,
    this.hashedLink,
  });

  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? region;
  final String? city;
  final double? lat;
  final double? lng;
  final String? avatar;
  final String? hashedLink;

  factory UserProfile.fromApiMap(Map<String, dynamic> map) {
    final data = _mergeProfilePayload(map);

    final phone = _readString(data, 'number') ??
        _readString(data, 'phone') ??
        _readString(data, 'phone_number') ??
        _readString(data, 'mobile');

    return UserProfile(
      id: _readString(data, 'id') ?? _readString(data, 'user_id'),
      name: _readString(data, 'fname') ??
          _readString(data, 'name') ??
          'User',
      email: _readString(data, 'email') ?? '',
      phone: phone,
      address: _formatAddress(data),
      region: _readString(data, 'region'),
      city: _readString(data, 'city'),
      lat: _readDouble(data, 'lat') ?? _readDouble(data, 'latitude'),
      lng: _readDouble(data, 'lng') ?? _readDouble(data, 'longitude'),
      avatar: _readString(data, 'avatar') ??
          _readString(data, 'profile_image') ??
          _readString(data, 'image'),
      hashedLink: _readString(data, 'hashed_link') ??
          _readString(data, 'hashedLink'),
    );
  }

  /// Merges `data.user` + `data.billing_address` (and legacy flat shapes).
  static Map<String, dynamic> mergeProfilePayload(Map<String, dynamic> map) =>
      _mergeProfilePayload(map);

  static Map<String, dynamic> _mergeProfilePayload(Map<String, dynamic> map) {
    Map<String, dynamic>? envelope;

    final data = map['data'];
    if (data is Map) {
      envelope = Map<String, dynamic>.from(data);
    } else if (map['user'] is Map || map['billing_address'] is Map) {
      envelope = map;
    }

    if (envelope != null) {
      final merged = <String, dynamic>{};

      void absorb(Map<String, dynamic> source) {
        for (final entry in source.entries) {
          final value = entry.value;
          if (value == null) continue;
          if (value is String && value.trim().isEmpty) continue;
          final key = entry.key;
          if (!merged.containsKey(key) || merged[key] == null) {
            merged[key] = value;
          }
        }
      }

      final profile = envelope['profile'];
      final user = envelope['user'];
      final billing =
          envelope['billing_address'] ?? envelope['billingAddress'];

      if (profile is Map) {
        absorb(Map<String, dynamic>.from(profile));
      }
      if (user is Map) {
        absorb(Map<String, dynamic>.from(user));
      }
      if (billing is Map) {
        const billingPreferredKeys = <String>{
          'fname',
          'lname',
          'email',
          'phone',
          'number',
          'addr_1',
          'addr_2',
          'address',
          'region',
          'city',
          'lat',
          'lng',
          'landmark',
        };
        for (final entry in billing.entries) {
          final key = entry.key;
          if (!billingPreferredKeys.contains(key)) continue;
          final value = entry.value;
          if (value == null) continue;
          if (value is String && value.trim().isEmpty) continue;
          merged[key] = value;
        }
      }

      if (merged.isNotEmpty) return merged;
      return envelope;
    }

    final profile = map['profile'];
    if (profile is Map) return Map<String, dynamic>.from(profile);
    final user = map['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    return map;
  }

  static String? _formatAddress(Map<String, dynamic> map) {
    final street = _readString(map, 'addr_1') ?? _readString(map, 'address');
    final city = _readString(map, 'city');
    final region = _readString(map, 'region');

    final parts = <String>[
      if (street != null) street,
      if (city != null) city,
      if (region != null) region,
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// Builds a profile from locally cached auth data when the API is unavailable.
  factory UserProfile.fromLocalMap(Map<String, dynamic> map) =>
      UserProfile.fromApiMap(map);

  static String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString().trim());
    return parsed;
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'fname': name,
        'name': name,
        'email': email,
        if (phone != null) ...{
          'number': phone,
          'phone': phone,
        },
        if (address != null) 'addr_1': _streetLine(address),
        if (region != null) 'region': region,
        if (city != null) 'city': city,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (avatar != null) 'avatar': avatar,
        if (hashedLink != null) 'hashed_link': hashedLink,
      };

  static String? _streetLine(String? formatted) {
    if (formatted == null) return null;
    final trimmed = formatted.trim();
    if (trimmed.isEmpty) return null;
    final first = trimmed.split(',').first.trim();
    return first.isEmpty ? trimmed : first;
  }

  Map<String, dynamic> toAuthStorageMap() => toJson();

  /// JSON body for `POST /profile/update`.
  Map<String, dynamic> toUpdateRequestBody() => {
        'fname': name,
        'email': email,
        'number': phone ?? '',
        'addr_1': _streetLine(address) ?? address ?? '',
        'lat': lat?.toString() ?? '',
        'lng': lng?.toString() ?? '',
      };

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? region,
    String? city,
    double? lat,
    double? lng,
    String? avatar,
    String? hashedLink,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      region: region ?? this.region,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      avatar: avatar ?? this.avatar,
      hashedLink: hashedLink ?? this.hashedLink,
    );
  }
}
