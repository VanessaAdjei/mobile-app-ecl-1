// services/promotional_event_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/promotional_event.dart';
import '../pages/auth_service.dart';

class PromotionalEventService {
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const String _eventsEndpoint = '/promotional-events';
  static const String _offersEndpoint = '/promotional-offers';
  static const String _applyOfferEndpoint = '/apply-promotional-offer';

  // Cache keys
  static const String _eventsCacheKey = 'promotional_events_cache';
  static const String _activeEventCacheKey = 'active_event_cache';
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Get all promotional events
  static Future<List<PromotionalEvent>> getPromotionalEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_eventsEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final events = (data['data'] as List)
              .map((e) => PromotionalEvent.fromJson(e))
              .toList();

          await _cacheEvents(events);
          return events;
        } else {
          throw Exception(
              data['message'] ?? 'Failed to fetch promotional events');
        }
      } else {
        throw Exception(
            'Failed to fetch promotional events: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching promotional events: $e',
          name: 'PromotionalEventService');

      // Return cached events if available
      final cachedEvents = await _getCachedEvents();
      if (cachedEvents.isNotEmpty) {
        return cachedEvents;
      }

      rethrow;
    }
  }

  // Get currently active promotional event
  static Future<PromotionalEvent?> getActiveEvent() async {
    try {
      final events = await getPromotionalEvents();
      final activeEvent = events.where((e) => e.isCurrentlyActive).firstOrNull;

      if (activeEvent != null) {
        await _cacheActiveEvent(activeEvent);
        return activeEvent;
      }

      return null;
    } catch (e) {
      developer.log('Error getting active event: $e',
          name: 'PromotionalEventService');

      // Return cached active event if available
      return await _getCachedActiveEvent();
    }
  }

  // Get upcoming promotional event
  static Future<PromotionalEvent?> getUpcomingEvent() async {
    try {
      final events = await getPromotionalEvents();
      final upcomingEvent = events.where((e) => e.isComingSoon).firstOrNull;
      return upcomingEvent;
    } catch (e) {
      developer.log('Error getting upcoming event: $e',
          name: 'PromotionalEventService');
      return null;
    }
  }

  // Apply promotional offer to cart
  static Future<Map<String, dynamic>> applyPromotionalOffer({
    required String offerId,
    required String promoCode,
    required double cartTotal,
    required List<String> cartCategories,
    required List<String> cartProductIds,
  }) async {
    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getCurrentUserID();

      if (token == null || userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_applyOfferEndpoint'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'offer_id': offerId,
              'promo_code': promoCode,
              'cart_total': cartTotal,
              'cart_categories': cartCategories,
              'cart_product_ids': cartProductIds,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Offer applied successfully',
            'data': data['data'],
            'discount_amount': data['discount_amount'] ?? 0.0,
            'cashback_amount': data['cashback_amount'] ?? 0.0,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to apply offer');
        }
      } else {
        throw Exception(
            data['message'] ?? 'Failed to apply offer: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error applying promotional offer: $e',
          name: 'PromotionalEventService');
      rethrow;
    }
  }

  // Validate promotional code
  static Future<Map<String, dynamic>> validatePromoCode({
    required String promoCode,
    required double cartTotal,
    required List<String> cartCategories,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$_offersEndpoint/validate'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'promo_code': promoCode,
              'cart_total': cartTotal,
              'cart_categories': cartCategories,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Promo code is valid',
            'data': data['data'],
            'offer': data['offer'] != null
                ? PromotionalOffer.fromJson(data['offer'])
                : null,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Invalid promo code',
          };
        }
      } else {
        throw Exception(data['message'] ??
            'Failed to validate promo code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error validating promo code: $e',
          name: 'PromotionalEventService');
      rethrow;
    }
  }

  // Get Ernest Friday specific event
  static Future<PromotionalEvent?> getErnestFridayEvent() async {
    try {
      final events = await getPromotionalEvents();
      return events
          .where((e) =>
              e.name.toLowerCase().contains('ernest friday') ||
              e.name.toLowerCase().contains('ernest') ||
              e.eventType == 'black_friday')
          .firstOrNull;
    } catch (e) {
      developer.log('Error getting Ernest Friday event: $e',
          name: 'PromotionalEventService');
      return null;
    }
  }

  // Check if Ernest Friday is currently active
  static Future<bool> isErnestFridayActive() async {
    try {
      // Check if today is Friday (Friday = 5 in DateTime.weekday)
      final now = DateTime.now();
      final isFriday = now.weekday == DateTime.friday;

      // Ernest Friday is active every Friday
      // return isFriday; // COMMENTED OUT - Will activate when ready
      return false; // Temporarily disabled
    } catch (e) {
      return false;
    }
  }

  // Get Ernest Friday offers
  static Future<List<PromotionalOffer>> getErnestFridayOffers() async {
    try {
      final ernestFridayEvent = await getErnestFridayEvent();
      if (ernestFridayEvent != null) {
        return ernestFridayEvent.offers
            .where((o) => o.isCurrentlyValid)
            .toList();
      }
      return [];
    } catch (e) {
      developer.log('Error getting Ernest Friday offers: $e',
          name: 'PromotionalEventService');
      return [];
    }
  }

  // Cache management
  static Future<void> _cacheEvents(List<PromotionalEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': events.map((e) => e.toJson()).toList(),
      };
      await prefs.setString(_eventsCacheKey, json.encode(cacheData));
    } catch (e) {
      developer.log('Error caching events: $e',
          name: 'PromotionalEventService');
    }
  }

  static Future<List<PromotionalEvent>> _getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_eventsCacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return (data['data'] as List)
              .map((e) => PromotionalEvent.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      developer.log('Error reading cached events: $e',
          name: 'PromotionalEventService');
    }
    return [];
  }

  static Future<void> _cacheActiveEvent(PromotionalEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': event.toJson(),
      };
      await prefs.setString(_activeEventCacheKey, json.encode(cacheData));
    } catch (e) {
      developer.log('Error caching active event: $e',
          name: 'PromotionalEventService');
    }
  }

  static Future<PromotionalEvent?> _getCachedActiveEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_activeEventCacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          return PromotionalEvent.fromJson(data['data']);
        }
      }
    } catch (e) {
      developer.log('Error reading cached active event: $e',
          name: 'PromotionalEventService');
    }
    return null;
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsCacheKey);
      await prefs.remove(_activeEventCacheKey);
    } catch (e) {
      developer.log('Error clearing cache: $e',
          name: 'PromotionalEventService');
    }
  }
}
