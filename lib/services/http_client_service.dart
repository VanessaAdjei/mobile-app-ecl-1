// services/http_client_service.dart
// services/http_client_service.dart
// services/http_client_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

/// Custom HTTP client service that handles SSL certificate validation issues
class HttpClientService {
  static http.Client? _client;
  static bool _isInitialized = false;

  /// Initialize the HTTP client with custom certificate handling
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create a custom HttpClient with relaxed certificate validation
      // This is necessary when the server's certificate chain is incomplete
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // For production, you should validate the certificate properly
          // For now, we'll allow certificates for the specific domain
          if (host.contains('ernestchemists.com.gh') ||
              host.contains('eclcommerce.ernestchemists.com.gh')) {
            if (kDebugMode) {
              debugPrint('🔒 Allowing certificate for: $host');
            }
            return true;
          }
          // For other domains, use default validation
          return false;
        }
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 15);

      _client = IOClient(httpClient);
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ HTTP Client Service initialized');
      }
    } catch (e) {
      debugPrint('❌ Error initializing HTTP Client: $e');
      // Fallback to default client
      _client = http.Client();
      _isInitialized = true;
    }
  }

  /// Get the configured HTTP client
  static http.Client get client {
    if (!_isInitialized || _client == null) {
      // Return default client if initialization failed
      return http.Client();
    }
    return _client!;
  }

  /// Dispose the HTTP client
  static void dispose() {
    _client?.close();
    _client = null;
    _isInitialized = false;
  }

  /// Make a GET request
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    await initialize();
    return client.get(url, headers: headers);
  }

  /// Make a POST request
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await initialize();
    return client.post(url, headers: headers, body: body, encoding: encoding);
  }

  /// Make a PUT request
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await initialize();
    return client.put(url, headers: headers, body: body, encoding: encoding);
  }

  /// Make a DELETE request
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
