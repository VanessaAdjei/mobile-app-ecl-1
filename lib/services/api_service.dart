// services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Cache entry class
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) > ApiService.cacheExpiry;
}

class ApiService {
  static const String baseUrl = 'https://eclpharmacy.com/api';
  static const Duration cacheExpiry = Duration(hours: 1);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;

  // Cache storage
  static final Map<String, _CacheEntry> _cache = {};

  // HTTP client with timeout
  static final http.Client _client = http.Client();

  // Headers
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'ECL-Pharmacy-App/1.0',
      };

  // Add auth token if available
  static Future<Map<String, String>> get _authHeaders async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    Map<String, String> headers = Map.from(_headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Check connectivity (simplified without external dependency)
  static Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Generic GET request with caching
  static Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool useCache = true,
    Duration? customCacheExpiry,
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    final cacheKey = url;

    // Check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired) {
        return entry.data;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // Check connectivity
    if (!await _checkConnectivity()) {
      throw ApiException(
        'No internet connection',
        'Please check your internet connection and try again.',
      );
    }

    // Make request with retry logic
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .get(
              Uri.parse(url),
              headers: await _authHeaders,
            )
            .timeout(requestTimeout);

        return _handleResponse(response, cacheKey, useCache);
      } on SocketException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Connection failed',
            'Unable to connect to server. Please try again later.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // Generic POST request
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    final url = _buildUrl(endpoint, queryParams);

    if (!await _checkConnectivity()) {
      throw ApiException(
        'No internet connection',
        'Please check your internet connection and try again.',
      );
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(url),
              headers: await _authHeaders,
              body: body != null ? json.encode(body) : null,
            )
            .timeout(requestTimeout);

        return _handleResponse(response, null, false);
      } on SocketException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Connection failed',
            'Unable to connect to server. Please try again later.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // Generic PUT request
  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    final url = _buildUrl(endpoint, queryParams);

    if (!await _checkConnectivity()) {
      throw ApiException(
        'No internet connection',
        'Please check your internet connection and try again.',
      );
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .put(
              Uri.parse(url),
              headers: await _authHeaders,
              body: body != null ? json.encode(body) : null,
            )
            .timeout(requestTimeout);

        return _handleResponse(response, null, false);
      } on SocketException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Connection failed',
            'Unable to connect to server. Please try again later.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // Generic DELETE request
  static Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    final url = _buildUrl(endpoint, queryParams);

    if (!await _checkConnectivity()) {
      throw ApiException(
        'No internet connection',
        'Please check your internet connection and try again.',
      );
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .delete(
              Uri.parse(url),
              headers: await _authHeaders,
            )
            .timeout(requestTimeout);

        return _handleResponse(response, null, false);
      } on SocketException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Connection failed',
            'Unable to connect to server. Please try again later.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // Build URL with query parameters
  static String _buildUrl(String endpoint, Map<String, dynamic>? queryParams) {
    String url = '$baseUrl/$endpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url += '?$queryString';
    }

    return url;
  }

  // Handle response and cache if needed
  static dynamic _handleResponse(
    http.Response response,
    String? cacheKey,
    bool useCache,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);

      // Cache successful responses
      if (useCache && cacheKey != null) {
        _cache[cacheKey] = _CacheEntry(data, DateTime.now());
      }

      return data;
    } else {
      _handleErrorResponse(response);
    }
  }

  // Handle error responses
  static void _handleErrorResponse(http.Response response) {
    String message = 'An error occurred';
    String details = 'Please try again later.';

    try {
      final errorData = json.decode(response.body);
      message = errorData['message'] ?? message;
      details = errorData['details'] ?? details;
    } catch (e) {
      // Use default message if JSON parsing fails
    }

    switch (response.statusCode) {
      case 400:
        throw ApiException('Bad Request', message);
      case 401:
        throw ApiException('Unauthorized', 'Please log in again.');
      case 403:
        throw ApiException(
            'Forbidden', 'You don\'t have permission to access this resource.');
      case 404:
        throw ApiException(
            'Not Found', 'The requested resource was not found.');
      case 422:
        throw ApiException('Validation Error', message);
      case 429:
        throw ApiException(
            'Too Many Requests', 'Please wait a moment before trying again.');
      case 500:
        throw ApiException('Server Error',
            'Something went wrong on our end. Please try again later.');
      case 502:
        throw ApiException('Bad Gateway',
            'The server is temporarily unavailable. Please try again later.');
      case 503:
        throw ApiException('Service Unavailable',
            'The service is temporarily unavailable. Please try again later.');
      default:
        throw ApiException('Request Failed',
            'An unexpected error occurred. Please try again.');
    }
  }

  // Clear cache
  static void clearCache() {
    _cache.clear();
  }

  // Clear expired cache entries
  static void clearExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  // Get cache size
  static int get cacheSize => _cache.length;

  // Dispose resources
  static void dispose() {
    _client.close();
    _cache.clear();
  }
}

// Custom exception class
class ApiException implements Exception {
  final String title;
  final String message;

  ApiException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}

// Timeout exception
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
