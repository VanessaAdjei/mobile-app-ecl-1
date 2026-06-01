import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'non_ui_error_reporter.dart';

/// Shared API / UI error helpers for the whole app.
class AppErrorUtils {
  AppErrorUtils._();

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
      return 'Server error. Please try again later.';
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
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static void showErrorSnack(BuildContext context, Object error) {
    showSnack(context, userMessage(error));
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
