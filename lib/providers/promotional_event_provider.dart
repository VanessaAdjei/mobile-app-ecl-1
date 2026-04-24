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
  bool _isDisposed = false;

  // getters to access the data
  PromotionalEvent? get activeEvent => _activeEvent;
  PromotionalEvent? get upcomingEvent => _upcomingEvent;
  List<PromotionalOffer> get availableOffers => _availableOffers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // check if ernest friday is happening
  bool get isErnestFridayActive =>
      _activeEvent?.name.toLowerCase().contains('ernest friday') ?? false;
  bool get isErnestFridayComingSoon =>
      _upcomingEvent?.name.toLowerCase().contains('ernest friday') ?? false;

  // check if theres an active promo event
  bool get hasActiveEvent => _activeEvent != null;

  // how many offers are available
  int get activeOffersCount => _availableOffers.length;

  // get offers by what type they are
  List<PromotionalOffer> get discountOffers =>
      _availableOffers.where((o) => o.type == 'discount').toList();

  List<PromotionalOffer> get cashbackOffers =>
      _availableOffers.where((o) => o.type == 'cashback').toList();

  List<PromotionalOffer> get freeShippingOffers =>
      _availableOffers.where((o) => o.type == 'free_shipping').toList();

  // set up the provider
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

  // load promo events from the api
  Future<void> _loadPromotionalEvents() async {
    try {
      // using demo data for now
      // when backend is ready, uncomment the api calls below

      // demo data
      _activeEvent = DemoPromotionalData.activeEvent;
      _upcomingEvent = DemoPromotionalData.upcomingEvent;

      // real api calls (uncomment when backend is ready)
      // _activeEvent = await PromotionalEventService.getActiveEvent();
      // _upcomingEvent = await PromotionalEventService.getUpcomingEvent();

      // get the offers from the active event
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

  // reload promo events from the api
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

  // use a promo code/offer
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
        // reload events to get the latest offers
        await refreshPromotionalEvents();
      }

      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // check if a promo code is valid
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

  // get the ernest friday event if theres one
  Future<PromotionalEvent?> getErnestFridayEvent() async {
    try {
      return await PromotionalEventService.getErnestFridayEvent();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // check if ernest friday is active (async version)
  Future<bool> checkErnestFridayActive() async {
    try {
      return await PromotionalEventService.isErnestFridayActive();
    } catch (e) {
      return false;
    }
  }

  // get all the ernest friday offers
  Future<List<PromotionalOffer>> getErnestFridayOffers() async {
    try {
      return await PromotionalEventService.getErnestFridayOffers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // find an offer by its id
  PromotionalOffer? getOfferById(String offerId) {
    try {
      return _availableOffers.firstWhere((o) => o.id == offerId);
    } catch (e) {
      return null;
    }
  }

  // get offers for a specific category
  List<PromotionalOffer> getOffersForCategory(String category) {
    return _availableOffers
        .where((o) =>
            o.applicableCategories.contains(category) ||
            o.applicableCategories.isEmpty)
        .toList();
  }

  // get offers for a specific product
  List<PromotionalOffer> getOffersForProduct(String productId) {
    return _availableOffers
        .where((o) => !o.excludedProducts.contains(productId))
        .toList();
  }

  // find the best offer for their cart
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

  // clear the error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // clear all the data
  void clear() {
    _activeEvent = null;
    _upcomingEvent = null;
    _availableOffers = [];
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  // clean up when done
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
