// services/background_order_checker.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'order_notification_service.dart';

class BackgroundOrderChecker {
  static Timer? _timer;
  static const Duration _checkInterval =
      Duration(minutes: 5); // Check every 5 minutes
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';

  /// Start periodic checking for order updates
  static void startPeriodicChecking() {
    debugPrint('🔄 Starting background order checking...');

    // Stop any existing timer
    _timer?.cancel();

    // Start new timer
    _timer = Timer.periodic(_checkInterval, (timer) {
      _checkForOrderUpdates();
    });

    // Also check immediately on startup
    _checkForOrderUpdates();
  }

  /// Stop periodic checking
  static void stopPeriodicChecking() {
    debugPrint('🔄 Stopping background order checking...');
    _timer?.cancel();
    _timer = null;
  }

  /// Check for order updates
  static Future<void> _checkForOrderUpdates() async {
    try {
      debugPrint('🔄 Checking for order updates...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        debugPrint('🔄 No auth token found, skipping order check');
        return;
      }

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(
            Uri.parse('$_baseUrl/orders'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> ordersData = responseData['data'];
          final List<Map<String, dynamic>> orders = ordersData
              .map((order) => Map<String, dynamic>.from(order))
              .toList();

          // Track order status changes and create notifications
          // await OrderNotificationService.trackOrderStatusChanges(orders);

          debugPrint(
              '🔄 Order check completed - processed ${orders.length} orders');
        } else {
          debugPrint('🔄 No orders found or invalid response format');
        }
      } else {
        debugPrint('🔄 Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔄 Error checking for order updates: $e');
    }
  }

  /// Manually trigger an order check
  static Future<void> checkNow() async {
    debugPrint('🔄 Manual order check triggered');
    await _checkForOrderUpdates();
  }

  /// Check if the service is running
  static bool get isRunning => _timer != null && _timer!.isActive;
}
