// providers/promotional_event_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/promotional_event.dart';
import '../services/promotional_event_service.dart';
import '../services/demo_promotional_data.dart';

class PromotionalEventProvider extends ChangeNotifier {
  PromotionalEvent? _activeEvent;
  PromotionalEvent? _upcomingEvent;
  List<PromotionalOffer> _availableOffers = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  PromotionalEvent? get activeEvent => _activeEvent;
  PromotionalEvent? get upcomingEvent => _upcomingEvent;
  List<PromotionalOffer> get availableOffers => _availableOffers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Ernest Friday specific getters
  bool get isErnestFridayActive =>
      _activeEvent?.name.toLowerCase().contains('ernest friday') ?? false;
  bool get isErnestFridayComingSoon =>
      _upcomingEvent?.name.toLowerCase().contains('ernest friday') ?? false;

  // Check if any promotional event is active
  bool get hasActiveEvent => _activeEvent != null;

  // Get active offers count
  int get activeOffersCount => _availableOffers.length;

  // Get offers by type
  List<PromotionalOffer> get discountOffers =>
      _availableOffers.where((o) => o.type == 'discount').toList();

  List<PromotionalOffer> get cashbackOffers =>
      _availableOffers.where((o) => o.type == 'cashback').toList();

  List<PromotionalOffer> get freeShippingOffers =>
      _availableOffers.where((o) => o.type == 'free_shipping').toList();

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadPromotionalEvents();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load promotional events
  Future<void> _loadPromotionalEvents() async {
    try {
      // For demo purposes, use demo data
      // In production, uncomment the API calls below

      // Demo data
      _activeEvent = DemoPromotionalData.activeEvent;
      _upcomingEvent = DemoPromotionalData.upcomingEvent;

      // Production API calls (uncomment when backend is ready)
      // _activeEvent = await PromotionalEventService.getActiveEvent();
      // _upcomingEvent = await PromotionalEventService.getUpcomingEvent();

      // Load available offers from active event
      if (_activeEvent != null) {
        _availableOffers =
            _activeEvent!.offers.where((o) => o.isCurrentlyValid).toList();
      } else {
        _availableOffers = [];
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Refresh promotional events
  Future<void> refreshPromotionalEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadPromotionalEvents();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Apply promotional offer
  Future<Map<String, dynamic>> applyPromotionalOffer({
    required String offerId,
    required String promoCode,
    required double cartTotal,
    required List<String> cartCategories,
    required List<String> cartProductIds,
  }) async {
    try {
      final result = await PromotionalEventService.applyPromotionalOffer(
        offerId: offerId,
        promoCode: promoCode,
        cartTotal: cartTotal,
        cartCategories: cartCategories,
        cartProductIds: cartProductIds,
      );

      if (result['success'] == true) {
        // Refresh events to get updated offers
        await refreshPromotionalEvents();
      }

      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Validate promotional code
  Future<Map<String, dynamic>> validatePromoCode({
    required String promoCode,
    required double cartTotal,
    required List<String> cartCategories,
  }) async {
    try {
      return await PromotionalEventService.validatePromoCode(
        promoCode: promoCode,
        cartTotal: cartTotal,
        cartCategories: cartCategories,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get Ernest Friday specific event
  Future<PromotionalEvent?> getErnestFridayEvent() async {
    try {
      return await PromotionalEventService.getErnestFridayEvent();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Check if Ernest Friday is active (async version)
  Future<bool> checkErnestFridayActive() async {
    try {
      return await PromotionalEventService.isErnestFridayActive();
    } catch (e) {
      return false;
    }
  }

  // Get Ernest Friday offers
  Future<List<PromotionalOffer>> getErnestFridayOffers() async {
    try {
      return await PromotionalEventService.getErnestFridayOffers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Get offer by ID
  PromotionalOffer? getOfferById(String offerId) {
    try {
      return _availableOffers.firstWhere((o) => o.id == offerId);
    } catch (e) {
      return null;
    }
  }

  // Get offers for specific category
  List<PromotionalOffer> getOffersForCategory(String category) {
    return _availableOffers
        .where((o) =>
            o.applicableCategories.contains(category) ||
            o.applicableCategories.isEmpty)
        .toList();
  }

  // Get offers for specific product
  List<PromotionalOffer> getOffersForProduct(String productId) {
    return _availableOffers
        .where((o) => !o.excludedProducts.contains(productId))
        .toList();
  }

  // Get best offer for cart
  PromotionalOffer? getBestOfferForCart({
    required double cartTotal,
    required List<String> cartCategories,
  }) {
    if (_availableOffers.isEmpty) return null;

    PromotionalOffer? bestOffer;
    double bestValue = 0.0;

    for (final offer in _availableOffers) {
      if (offer.minimumOrderAmount <= cartTotal) {
        final discount = offer.calculateDiscount(cartTotal);
        if (discount > bestValue) {
          bestValue = discount;
          bestOffer = offer;
        }
      }
    }

    return bestOffer;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _activeEvent = null;
    _upcomingEvent = null;
    _availableOffers = [];
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    super.dispose();
  }
}
