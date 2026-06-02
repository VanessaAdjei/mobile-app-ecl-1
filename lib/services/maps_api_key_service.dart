import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads the Google Maps API key from native app config (Info.plist / manifest).
class MapsApiKeyService {
  MapsApiKeyService._();

  static const MethodChannel _channel =
      MethodChannel('com.ecl.ecl_commerce/maps_config');

  static Future<String> loadFromNative() async {
    try {
      final key = await _channel.invokeMethod<String>('getGoogleMapsApiKey');
      return key?.trim() ?? '';
    } catch (e, st) {
      debugPrint('🗺️ MapsApiKeyService: native key unavailable: $e');
      debugPrint('$st');
      return '';
    }
  }
}
