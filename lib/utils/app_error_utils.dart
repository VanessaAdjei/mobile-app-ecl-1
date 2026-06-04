import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/notification_service.dart';
import 'non_ui_error_reporter.dart';

/// Shared failure kinds for product detail and catalog screens.
enum ProductDetailErrorKind {
  offline,
  notFound,
  server,
  unavailable,
  unknown,
}

/// Shared API / UI error helpers for the whole app.
class AppErrorUtils {
  AppErrorUtils._();

  /// User-facing copy when a backend/API request fails (no "server" wording).
  static const String oopsTitle = 'Oops!';
  static const String oopsTryAgainMessage =
      'Oops! Something went wrong. Please try again.';
  static const String oopsTryAgainBody =
      'Something went wrong. Please try again.';

  // ── JSON ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? tryDecodeJsonMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      log('AppErrorUtils.tryDecodeJsonMap', e);
    }
    return null;
  }

  static String messageFromApiBody(
    String body, {
    String fallback = 'Request failed',
  }) {
    final map = tryDecodeJsonMap(body);
    return messageFromMap(map, fallback: fallback);
  }

  static String? firstFieldValidationError(Map<String, dynamic>? map) {
    final errors = map?['errors'];
    if (errors is! Map) return null;
    for (final entry in errors.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        final text = value.first.toString();
        if (text.isNotEmpty) return text;
      } else if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static String messageFromMap(
    Map<String, dynamic>? map, {
    String fallback = 'Request failed',
  }) {
    final fieldError = firstFieldValidationError(map);
    if (fieldError != null) return fieldError;

    final msg = map?['message']?.toString();
    if (msg != null &&
        msg.isNotEmpty &&
        msg.toLowerCase() != 'validation failed' &&
        msg.toLowerCase() != 'validation error') {
      return msg;
    }
    final err = map?['error']?.toString();
    if (err != null && err.isNotEmpty) return err;
    if (msg != null && msg.isNotEmpty) return msg;
    return fallback;
  }

  // ── User-facing copy ───────────────────────────────────────────────────────

  static String userMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (error is SocketException) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (error is http.ClientException) {
      return 'Network error. Please check your connection and try again.';
    }
    if (error is FormatException) {
      return 'Received an unexpected response. Please try again.';
    }

    final text = error.toString();
    if (text.contains('401') || text.toLowerCase().contains('unauthorized')) {
      return 'Session expired. Please sign in again.';
    }
    if (text.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (text.contains('404')) {
      return 'The requested information was not found.';
    }
    if (text.contains('500') || text.contains('502') || text.contains('503')) {
      return oopsTryAgainMessage;
    }

    return fallback;
  }

  /// Standard failure map for services that return `{ success, message }`.
  static Map<String, dynamic> failure(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    return {
      'success': false,
      'message': userMessage(error, fallback: fallback),
    };
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  static void log(String context, Object error, [StackTrace? stackTrace]) {
    NonUiErrorReporter.report(context, error, stackTrace);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _showSnackOnMessenger(messenger, message, isError: isError, duration: duration);
  }

  /// SnackBar via app-wide [NotificationService.messengerKey] (e.g. after leaving confirmation).
  static void showGlobalSnack(
    String message, {
    bool isError = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = NotificationService.messengerKey.currentState;
    if (messenger == null) return;
    _showSnackOnMessenger(messenger, message, isError: isError, duration: duration);
  }

  static void _showSnackOnMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isError,
    required Duration duration,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  static void showErrorSnack(BuildContext context, Object error) {
    showSnack(context, userMessage(error));
  }

  // ── Product detail / catalog ────────────────────────────────────────────────

  /// True for dropped connections, timeouts, and other retryable transport faults.
  static bool isTransientTransportError(Object error) {
    if (error is TimeoutException || error is SocketException) return true;
    if (error is http.ClientException) return true;

    final text = error.toString().toLowerCase();
    return text.contains('connection closed') ||
        text.contains('connection failed') ||
        text.contains('connection reset') ||
        text.contains('clientexception') ||
        text.contains('socketexception') ||
        text.contains('handshake') ||
        text.contains('broken pipe') ||
        text.contains('unable to connect') ||
        text.contains('no internet');
  }

  static ProductDetailErrorKind classifyProductError(Object? error) {
    if (error == null) return ProductDetailErrorKind.unavailable;
    if (error is TimeoutException) return ProductDetailErrorKind.offline;
    if (error is SocketException) return ProductDetailErrorKind.offline;
    if (error is http.ClientException) return ProductDetailErrorKind.offline;

    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('internet') ||
        text.contains('connection') ||
        text.contains('unable to connect')) {
      return ProductDetailErrorKind.offline;
    }
    if (text.contains('404') || text.contains('not found')) {
      return ProductDetailErrorKind.notFound;
    }
    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('server error') ||
        text.contains('server busy')) {
      return ProductDetailErrorKind.server;
    }
    if (text.contains('unavailable') || text.contains('link')) {
      return ProductDetailErrorKind.unavailable;
    }
    return ProductDetailErrorKind.unknown;
  }

  static String productDetailTitle(ProductDetailErrorKind kind) {
    switch (kind) {
      case ProductDetailErrorKind.offline:
        return 'No internet connection';
      case ProductDetailErrorKind.notFound:
        return 'Product not found';
      case ProductDetailErrorKind.server:
        return oopsTitle;
      case ProductDetailErrorKind.unavailable:
        return 'Product unavailable';
      case ProductDetailErrorKind.unknown:
        return 'Couldn\'t load product';
    }
  }

  static String productDetailMessage(
    ProductDetailErrorKind kind, {
    String? productName,
  }) {
    switch (kind) {
      case ProductDetailErrorKind.offline:
        return 'Check your connection and try again.';
      case ProductDetailErrorKind.notFound:
        if (productName != null && productName.trim().isNotEmpty) {
          return '$productName is no longer listed. It may have been removed.';
        }
        return 'This product is no longer listed. It may have been removed.';
      case ProductDetailErrorKind.server:
        return oopsTryAgainBody;
      case ProductDetailErrorKind.unavailable:
        if (productName != null && productName.trim().isNotEmpty) {
          return 'We couldn\'t open $productName. Try again or choose another product.';
        }
        return 'We couldn\'t open this product. Try again or choose another product.';
      case ProductDetailErrorKind.unknown:
        return 'Something went wrong while loading this product. Please try again.';
    }
  }

  static String productDetailMessageFromError(
    Object error, {
    String? productName,
  }) {
    final kind = classifyProductError(error);
    if (kind == ProductDetailErrorKind.unknown) {
      return userMessage(
        error,
        fallback: productDetailMessage(kind, productName: productName),
      );
    }
    return productDetailMessage(kind, productName: productName);
  }

  static IconData productDetailIcon(ProductDetailErrorKind kind) {
    switch (kind) {
      case ProductDetailErrorKind.offline:
        return Icons.wifi_off_rounded;
      case ProductDetailErrorKind.notFound:
        return Icons.search_off_rounded;
      case ProductDetailErrorKind.server:
        return Icons.cloud_off_rounded;
      case ProductDetailErrorKind.unavailable:
        return Icons.inventory_2_outlined;
      case ProductDetailErrorKind.unknown:
        return Icons.error_outline_rounded;
    }
  }

  static String catalogLoadTitle(ProductDetailErrorKind kind) {
    switch (kind) {
      case ProductDetailErrorKind.offline:
        return 'No internet connection';
      case ProductDetailErrorKind.server:
        return oopsTitle;
      case ProductDetailErrorKind.notFound:
        return 'No products found';
      case ProductDetailErrorKind.unavailable:
      case ProductDetailErrorKind.unknown:
        return 'Couldn\'t load products';
    }
  }

  /// [detail] is optional extra copy from the caller (e.g. API handler text).
  static String catalogLoadMessage(
    ProductDetailErrorKind kind, {
    String? detail,
  }) {
    final trimmed = detail?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    switch (kind) {
      case ProductDetailErrorKind.offline:
        return 'Check your connection and tap Try again.';
      case ProductDetailErrorKind.server:
        return oopsTryAgainBody;
      case ProductDetailErrorKind.notFound:
        return 'There are no products in this category right now.';
      case ProductDetailErrorKind.unavailable:
      case ProductDetailErrorKind.unknown:
        return 'We couldn\'t load the product list. Please try again.';
    }
  }
}

extension AppErrorBuildContext on BuildContext {
  void showAppErrorSnack(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    AppErrorUtils.showSnack(
      this,
      AppErrorUtils.userMessage(error, fallback: fallback),
    );
  }

  void showAppMessageSnack(String message, {bool isError = false}) {
    AppErrorUtils.showSnack(this, message, isError: isError);
  }
}
