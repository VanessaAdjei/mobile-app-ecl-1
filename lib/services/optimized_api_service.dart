// services/optimized_api_service.dart
// services/optimized_api_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'app_optimization_service.dart';

class OptimizedApiService {
  static final OptimizedApiService _instance = OptimizedApiService._internal();
  factory OptimizedApiService() => _instance;
  OptimizedApiService._internal();

  // HTTP client with optimized settings
  late final http.Client _httpClient;
  late final Dio _dioClient;

  // Base URL
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';

  // Request timeout
  static const Duration _timeout = Duration(seconds: 15);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Initialize the service
  Future<void> initialize() async {
    _httpClient = http.Client();

    _dioClient = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
    ));

    // Add interceptors for logging and error handling
    _dioClient.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
  }

  // Optimized GET request with caching
  Future<T> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    String? cacheKey,
    Duration? cacheExpiry,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final optimizationService = AppOptimizationService();
    final requestKey = cacheKey ?? 'GET_$endpoint';

    optimizationService.startTimer('API_GET_$endpoint');

    try {
      final response = await optimizationService.getCachedResponse(
        requestKey,
        () async {
          final response = await _httpClient
              .get(
                Uri.parse('$_baseUrl$endpoint'),
                headers: headers,
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data;
          } else {
            throw HttpException(
                'HTTP ${response.statusCode}: ${response.reasonPhrase}');
          }
        },
      );

      optimizationService.endTimer('API_GET_$endpoint');

      if (fromJson != null && response is Map<String, dynamic>) {
        return fromJson(response);
      }

      return response as T;
    } catch (e) {
      optimizationService.endTimer('API_GET_$endpoint');
      rethrow;
    }
  }

  // Optimized POST request
  Future<T> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final optimizationService = AppOptimizationService();
    optimizationService.startTimer('API_POST_$endpoint');

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        optimizationService.endTimer('API_POST_$endpoint');

        if (fromJson != null && data is Map<String, dynamic>) {
          return fromJson(data);
        }

        return data as T;
      } else {
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      optimizationService.endTimer('API_POST_$endpoint');
      rethrow;
    }
  }

  // Optimized PUT request
  Future<T> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final optimizationService = AppOptimizationService();
    optimizationService.startTimer('API_PUT_$endpoint');

    try {
      final response = await _httpClient
          .put(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        optimizationService.endTimer('API_PUT_$endpoint');

        if (fromJson != null && data is Map<String, dynamic>) {
          return fromJson(data);
        }

        return data as T;
      } else {
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      optimizationService.endTimer('API_PUT_$endpoint');
      rethrow;
    }
  }

  // Optimized DELETE request
  Future<T> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final optimizationService = AppOptimizationService();
    optimizationService.startTimer('API_DELETE_$endpoint');

    try {
      final response = await _httpClient
          .delete(
            Uri.parse('$_baseUrl$endpoint'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        optimizationService.endTimer('API_DELETE_$endpoint');

        if (response.body.isNotEmpty) {
          final data = json.decode(response.body);
          if (fromJson != null && data is Map<String, dynamic>) {
            return fromJson(data);
          }
          return data as T;
        }

        return {} as T;
      } else {
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      optimizationService.endTimer('API_DELETE_$endpoint');
      rethrow;
    }
  }

  // Retry mechanism for failed requests
  Future<T> _retryRequest<T>(
    Future<T> Function() requestFunction,
    int retryCount,
  ) async {
    try {
      return await requestFunction();
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(_retryDelay * (retryCount + 1));
        return _retryRequest(requestFunction, retryCount + 1);
      }
      rethrow;
    }
  }

  // Clear API cache
  Future<void> clearCache() async {
    final optimizationService = AppOptimizationService();
    await optimizationService.clearAllCaches();
  }

  // Get API statistics
  Map<String, dynamic> getApiStats() {
    final optimizationService = AppOptimizationService();
    return optimizationService.getCacheStats();
  }

  // Dispose resources
  void dispose() {
    _httpClient.close();
    _dioClient.close();
  }
}

// Custom HTTP exception
class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}

// API response wrapper
class ApiResponse<T> {
  final T data;
  final bool success;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.data,
    required this.success,
    this.message,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse(
      data: data,
      success: true,
      message: message,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse(
      data: null as T,
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }
}
