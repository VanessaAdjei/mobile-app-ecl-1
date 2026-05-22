import 'dart:convert';

import 'package:flutter/services.dart';

/// Native ExpressPay bridge (Android/iOS method channel).
class ExpressPayChannel {
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.expresspay');

  static Future<Map?> startExpressPay(Map<String, String> params) async {
    try {
      final result = await _channel.invokeMethod('startExpressPay', params);
      if (result is String) {
        return Map<String, dynamic>.from(jsonDecode(result));
      } else if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
