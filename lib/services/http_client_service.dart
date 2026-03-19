// services/http_client_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

/// HTTP client service. Uses default SSL certificate validation in all builds.
/// Do not disable or relax certificate validation in production.
class HttpClientService {
  static http.Client? _client;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use default certificate validation. Fix server certificate chain
      // if you see SSL errors; do not use badCertificateCallback in production.
      final httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 15);

      _client = IOClient(httpClient);
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ HTTP Client Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing HTTP Client: $e');
      }
      _client = http.Client();
      _isInitialized = true;
    }
  }

  static http.Client get client {
    if (!_isInitialized || _client == null) {
      return http.Client();
    }
    return _client!;
  }

  static void dispose() {
    _client?.close();
    _client = null;
    _isInitialized = false;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    await initialize();
    return client.get(url, headers: headers);
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await initialize();
    return client.post(url, headers: headers, body: body, encoding: encoding);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await initialize();
    return client.put(url, headers: headers, body: body, encoding: encoding);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await initialize();
    return client.delete(url, headers: headers, body: body, encoding: encoding);
  }
}
