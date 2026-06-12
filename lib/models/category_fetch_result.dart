import 'dart:convert';

import '../utils/product_catalog_parser.dart';

/// Result of a category/catalog HTTP call (decoded JSON body + status).
class CategoryFetchResult {
  final int statusCode;
  final Map<String, dynamic>? body;
  final String? rawBody;
  final Object? error;

  const CategoryFetchResult({
    required this.statusCode,
    this.body,
    this.rawBody,
    this.error,
  });

  bool get isHttpOk => statusCode == 200 && body != null;

  bool get isApiSuccess =>
      isHttpOk && body != null && isCatalogApiBodySuccess(body!);

  List<dynamic> get data => extractDataList(body);

  /// Supports `data: [...]` and nested `data: { products: [...] }` shapes.
  static List<dynamic> extractDataList(Map<String, dynamic>? body) {
    if (body == null) return const [];

    final data = body['data'];
    if (data is List) return List<dynamic>.from(data);

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in [
        'products',
        'subcategories',
        'categories',
        'items',
        'list',
        'data',
      ]) {
        final value = map[key];
        if (value is List) return List<dynamic>.from(value);
      }
    }

    return const [];
  }

  Map<String, dynamic>? get dataMap =>
      body?['data'] is Map ? Map<String, dynamic>.from(body!['data'] as Map) : null;

  factory CategoryFetchResult.fromResponse(
    int statusCode,
    String rawBody, {
    String? rawBodyOverride,
  }) {
    final storedRaw = rawBodyOverride ?? rawBody;
    if (statusCode != 200 || rawBody.trim().isEmpty) {
      return CategoryFetchResult(
        statusCode: statusCode,
        rawBody: storedRaw,
      );
    }
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return CategoryFetchResult(
          statusCode: statusCode,
          body: decoded,
          rawBody: storedRaw,
        );
      }
      if (decoded is Map) {
        return CategoryFetchResult(
          statusCode: statusCode,
          body: Map<String, dynamic>.from(decoded),
          rawBody: storedRaw,
        );
      }
    } catch (_) {}
    return CategoryFetchResult(statusCode: statusCode, rawBody: storedRaw);
  }
}
