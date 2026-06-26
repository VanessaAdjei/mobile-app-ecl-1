// services/booking_service.dart
// handles pharmacist / consultation bookings
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_error_utils.dart';

class BookingService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? token;
    String? guestId;
    if (isLoggedIn) {
      token = await AuthService.getToken();
    } else {
      final prefs = await SharedPreferences.getInstance();
      guestId = prefs.getString('guest_id');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (isLoggedIn && token != null) 'Authorization': 'Bearer $token',
      if (!isLoggedIn && guestId != null) 'Authorization': 'Guest $guestId',
    };
  }

  static Map<String, dynamic> _errorResponse(
    http.Response response, {
    required String fallback,
  }) {
    final map = AppErrorUtils.tryDecodeJsonMap(response.body);
    return {
      'success': false,
      'message': AppErrorUtils.messageFromMap(map, fallback: fallback),
    };
  }

  /// GET /bookings/available-sessions?date={date}
  static Future<Map<String, dynamic>> getAvailableSessions(String date) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getBookingsAvailableSessionsUrl(date);
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _errorResponse(
          response,
          fallback: 'Failed to load available sessions',
        );
      }

      final decoded = json.decode(response.body);
      List<dynamic> sessions;
      if (decoded is List) {
        sessions = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        sessions = decoded['data'] as List<dynamic>;
      } else {
        return {'success': false, 'message': 'Invalid response format'};
      }
      return {
        'success': true,
        'data': sessions,
      };
    } catch (e, st) {
      AppErrorUtils.log('BookingService.getAvailableSessions', e, st);
      return AppErrorUtils.failure(
        e,
        fallback: 'Failed to load available sessions',
      );
    }
  }

  /// POST /bookings/book
  static Future<Map<String, dynamic>> book(Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getEndpointUrl(ApiConfig.bookingsBook);
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = AppErrorUtils.tryDecodeJsonMap(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {...?data, 'success': true};
      }
      return {
        'success': false,
        'message': AppErrorUtils.messageFromMap(
          data,
          fallback: 'Failed to book',
        ),
      };
    } catch (e, st) {
      AppErrorUtils.log('BookingService.book', e, st);
      return AppErrorUtils.failure(e, fallback: 'Failed to book');
    }
  }

  /// GET /bookings/history
  static Future<Map<String, dynamic>> getHistory() async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getEndpointUrl(ApiConfig.bookingsHistory);
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _errorResponse(
          response,
          fallback: 'Failed to load booking history',
        );
      }

      final decoded = json.decode(response.body);
      List<dynamic> bookings;
      if (decoded is List) {
        bookings = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        bookings = decoded['data'] as List<dynamic>;
      } else {
        return {'success': false, 'message': 'Invalid response format'};
      }
      return {
        'success': true,
        'data': bookings,
      };
    } catch (e, st) {
      AppErrorUtils.log('BookingService.getHistory', e, st);
      return AppErrorUtils.failure(
        e,
        fallback: 'Failed to load booking history',
      );
    }
  }

  /// DELETE /bookings/cancel/{id}
  static Future<Map<String, dynamic>> cancel(String id) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getBookingsCancelUrl(id);
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      final data = AppErrorUtils.tryDecodeJsonMap(response.body);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return {
          ...?data,
          'success': true,
        };
      }
      return {
        'success': false,
        'message': AppErrorUtils.messageFromMap(
          data,
          fallback: 'Failed to cancel booking',
        ),
      };
    } catch (e, st) {
      AppErrorUtils.log('BookingService.cancel', e, st);
      return AppErrorUtils.failure(e, fallback: 'Failed to cancel booking');
    }
  }
}
