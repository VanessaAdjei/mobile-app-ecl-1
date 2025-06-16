// services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  static Future<void> setToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }
}
