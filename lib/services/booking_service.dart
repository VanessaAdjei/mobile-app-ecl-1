// services/booking_service.dart
// handles pharmacist / consultation bookings
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// GET /bookings/available-sessions?date={date}
  /// Returns available sessions for the given date.
  /// Expected API response: array of { "start": "09:00", "end": "11:00", "available": true }
  static Future<Map<String, dynamic>> getAvailableSessions(String date) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getBookingsAvailableSessionsUrl(date);
      print('═══════════════════════════════════════════════════════');
      print('📤 BOOKINGS API: GET available-sessions');
      print('═══════════════════════════════════════════════════════');
      print('URL: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      print('Status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('═══════════════════════════════════════════════════════');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final err = json.decode(response.body);
        final msg = err is Map ? err['message']?.toString() : null;
        return {
          'success': false,
          'message': msg ?? 'Failed to load available sessions',
        };
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
    } catch (e) {
      print('❌ BOOKINGS API getAvailableSessions error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// POST /bookings/book
  /// Body: { session_date, start_time, end_time, full_name, email, phone, platform, type, reason }
  /// Response: { message: "Booking successful!", booking: { id, user_id, session_date, start_time, end_time, full_name, email, phone, platform, type, reason, created_at, updated_at } }
  static Future<Map<String, dynamic>> book(Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getEndpointUrl(ApiConfig.bookingsBook);
      final bodyEncoded = json.encode(body);
      print('═══════════════════════════════════════════════════════');
      print('📤 BOOKINGS API: POST book');
      print('═══════════════════════════════════════════════════════');
      print('URL: $url');
      print('Request body: $bodyEncoded');
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: bodyEncoded,
          )
          .timeout(const Duration(seconds: 15));
      print('Status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('═══════════════════════════════════════════════════════');
      final data = json.decode(response.body) as Map<String, dynamic>?;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {...?data, 'success': true};
      }
      return {
        'success': false,
        'message': data?['message'] ?? 'Failed to book',
      };
    } catch (e) {
      print('❌ BOOKINGS API book error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// GET /bookings/history
  /// Returns user's booking history.
  /// API response: raw array of items, e.g.:
  /// [ { "id": 11, "user_id": 121, "session_date": "2026-01-28", "start_time": "09:00:00", "end_time": "11:00:00", "full_name": "Samuel Malorm", "email": "sam@gmail.com", "phone": "0202450011", "platform": "Zoom", "type": "videocall", "reason": "big dreams", "created_at": "2026-02-03T12:07:54.000000Z", "updated_at": "2026-02-03T12:07:54.000000Z" }, ... ]
  static Future<Map<String, dynamic>> getHistory() async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getEndpointUrl(ApiConfig.bookingsHistory);
      print('═══════════════════════════════════════════════════════');
      print('📤 BOOKINGS API: GET history');
      print('═══════════════════════════════════════════════════════');
      print('URL: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      print('Status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('═══════════════════════════════════════════════════════');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final err = json.decode(response.body);
        final msg = err is Map ? err['message']?.toString() : null;
        return {
          'success': false,
          'message': msg ?? 'Failed to load booking history',
        };
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
    } catch (e) {
      print('❌ BOOKINGS API getHistory error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// DELETE /bookings/cancel/{id}
  /// Cancels a booking by id.
  static Future<Map<String, dynamic>> cancel(String id) async {
    try {
      final headers = await _headers();
      final url = ApiConfig.getBookingsCancelUrl(id);
      print('═══════════════════════════════════════════════════════');
      print('📤 BOOKINGS API: DELETE cancel/$id');
      print('═══════════════════════════════════════════════════════');
      print('URL: $url');
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      print('Status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('═══════════════════════════════════════════════════════');
      final data = json.decode(response.body) as Map<String, dynamic>?;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data ?? {'success': true};
      }
      return {
        'success': false,
        'message': data?['message'] ?? 'Failed to cancel booking',
      };
    } catch (e) {
      print('❌ BOOKINGS API cancel error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
