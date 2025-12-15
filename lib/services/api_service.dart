// services/api_service.dart
// handles all the api calls and stuff
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclapp/pages/auth_service.dart';

// class to store cached data with a timestamp
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  // check if the cache is too old
  bool get isExpired =>
      DateTime.now().difference(timestamp) > ApiService.cacheExpiry;
}

class ApiService {
  // the base url for all api calls
  static const String baseUrl = 'https://eclpharmacy.com/api';
  // cache expires after 1 hour
  static const Duration cacheExpiry = Duration(hours: 1);
  // requests timeout after 15 seconds (used to be 30 but that was too long)
  static const Duration requestTimeout = Duration(seconds: 15);
  // try 3 times if it fails
  static const int maxRetries = 3;
  // turn this on if you want to see all the api logs (probably dont need it)
  static const bool enableDebugLogs = false;

  // where we store cached responses
  static final Map<String, _CacheEntry> _cache = {};

  // http client thing
  static final http.Client _client = http.Client();

  // cache the connectivity check so we dont check every single time
  static bool? _connectivityCache;
  static DateTime? _connectivityCheckTime;
  // only check connectivity every 5 minutes
  static const Duration _connectivityCacheDuration = Duration(minutes: 5);

  // default headers for requests
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'ECL-Pharmacy-App/1.0',
      };

  // get headers with auth token if we have one
  static Future<Map<String, String>> get _authHeaders async {
    final token = await AuthService.getToken();
    Map<String, String> headers = Map.from(_headers);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // check if we have internet (but cache it so we dont check constantly)
  static Future<bool> _checkConnectivity({bool forceCheck = false}) async {
    // if we checked recently, just use the cached result
    if (!forceCheck &&
        _connectivityCache != null &&
        _connectivityCheckTime != null &&
        DateTime.now().difference(_connectivityCheckTime!) <
            _connectivityCacheDuration) {
      return _connectivityCache!;
    }

    // actually check if we have internet
    try {
      // try to look up google.com (quick way to check internet)
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _connectivityCache = isConnected;
      _connectivityCheckTime = DateTime.now();
      return isConnected;
    } on SocketException catch (_) {
      // no internet
      _connectivityCache = false;
      _connectivityCheckTime = DateTime.now();
      return false;
    } on TimeoutException catch (_) {
      // if it times out, just assume we have internet and let the actual request fail if not
      _connectivityCache = true;
      _connectivityCheckTime = DateTime.now();
      return true;
    }
  }

  // make a GET request (with caching)
  static Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool useCache = true,
    Duration? customCacheExpiry,
    bool skipConnectivityCheck =
        false, // skip the connectivity check to go faster
  }) async {
    final headers = await _authHeaders;
    if (enableDebugLogs) {
      debugPrint('[API] GET $endpoint');
    }
    final url = _buildUrl(endpoint, queryParams);
    final cacheKey = url;

    // check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired) {
        if (enableDebugLogs) {
          debugPrint('[API] Cache hit for $endpoint');
        }
        return entry.data;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // check connectivity (only if not skipped and cache expired)
    if (!skipConnectivityCheck && !await _checkConnectivity()) {
      throw ApiException(
        'No internet connection',
        'Please check your internet connection and try again.',
      );
    }

    // make request with retry logic
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .get(
              Uri.parse(url),
              headers: headers,
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
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  // make a POST request
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool useCache = false,
    Duration? customCacheExpiry,
    bool skipConnectivityCheck = false, // Allow skipping for faster requests
  }) async {
    final headers = await _authHeaders;
    if (enableDebugLogs) {
      debugPrint('[API] POST $endpoint');
    }
    final url = _buildUrl(endpoint, queryParams);

    // Check connectivity (only if not skipped)
    if (!skipConnectivityCheck && !await _checkConnectivity()) {
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
              headers: headers,
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
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  // make a PUT request
  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool skipConnectivityCheck = false, // Allow skipping for faster requests
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    if (enableDebugLogs) {
      debugPrint('[API] PUT $endpoint');
    }

    // Check connectivity (only if not skipped)
    if (!skipConnectivityCheck && !await _checkConnectivity()) {
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
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  // make a DELETE request
  static Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool skipConnectivityCheck = false, // Allow skipping for faster requests
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    if (enableDebugLogs) {
      debugPrint('[API] DELETE $endpoint');
    }

    // Check connectivity (only if not skipped)
    if (!skipConnectivityCheck && !await _checkConnectivity()) {
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
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request timeout',
            'The request took too long to complete. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      } catch (e) {
        if (attempt == maxRetries) {
          throw ApiException(
            'Request failed',
            'An unexpected error occurred. Please try again.',
          );
        }
        // shorter delay: milliseconds instead of seconds
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  // build url with query parameters
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

  // handle response and cache if needed
  static dynamic _handleResponse(
    http.Response response,
    String? cacheKey,
    bool useCache,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);

      // save successful responses to cache
      if (useCache && cacheKey != null) {
        _cache[cacheKey] = _CacheEntry(data, DateTime.now());
      }

      return data;
    } else {
      _handleErrorResponse(response);
    }
  }

  // handle error responses
  static void _handleErrorResponse(http.Response response) {
    String message = 'An error occurred';
    String details = 'Please try again later.';

    try {
      final errorData = json.decode(response.body);
      message = errorData['message'] ?? message;
      details = errorData['details'] ?? details;
    } catch (e) {
      // use default message if json parsing fails
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

  // clear cache
  static void clearCache() {
    _cache.clear();
  }

  // clear expired cache entries
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
