import 'package:flutter/foundation.dart';

import '../services/maps_api_key_service.dart';
import '../utils/product_image_url.dart';

class ApiConfig {
  // ==================== BASE URLs ====================

  // main api url
  static const String baseUrl = 'https://eclcommerce.ernestchemists.com.gh/api';

  // admin url for uploading images and stuff
  static const String adminBaseUrl =
      'https://adm-ecommerce.ernestchemists.com.gh';

  // where product images are stored
  static const String productImageBaseUrl = '$adminBaseUrl/uploads/product';

  // app root (no /api) for storage paths
  static const String appBaseUrl = 'https://eclcommerce.ernestchemists.com.gh';

  /// Debug builds use production `/complete` so real devices can load the return URL.
  /// Override with --dart-define=PAYMENT_REDIRECT_URL=http://eclcommerce.test/ for local testing.
  static String get paymentRedirectUrl {
    const env =
        String.fromEnvironment('PAYMENT_REDIRECT_URL', defaultValue: '');
    if (env.isNotEmpty) return env;
    return '$appBaseUrl/complete';
  }

  // ==================== AUTHENTICATION ENDPOINTS ====================
  // login and auth stuff

  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String otpVerification = '/otp-verification';
  static const String resendOtpVerification = '/resend-otp-verification';
  static const String resetPassword =
      '/reset-pwd'; // used by forgot-password flow
  static const String forgotPassword =
      '/forgot-password'; // legacy alias — not used by the app
  static const String guestId = '/guest-id';
  static const String checkAuth = '/check-auth';

  // ==================== USER PROFILE ENDPOINTS ====================
  // user profile & account settings

  static const String getProfile = '/profile';
  /// `POST /profile/update` with body: fname, email, number, addr_1, lat, lng.
  static const String updateProfile = '/profile/update';
  static const String changePassword = '/change-password';

  /// Legacy aliases — prefer [getProfile] / [updateProfile].
  static const String userProfile = getProfile;
  static const String userProfileUpdate = updateProfile;
  static const String getUserProfile = getProfile;

  // ==================== PRODUCT ENDPOINTS ====================
  // getting products and product info

  static const String getAllProducts = '/get-all-products';

  /// Small featured set for fast home first paint (~20 products).
  static const String getHomePriority = '/get-home-priority';
  static const String productDetails =
      '/product-details'; // add the urlName at the end like /product-details/{urlName}
  static const String relatedProducts =
      '/related-products'; // add urlName like /related-products/{urlName}
  static const String popularProducts = '/popular-products';
  static const String searchProducts =
      '/search'; // add search pattern like /search/{pattern}
  static const String topCategories = '/top-categories';

  // ==================== CATEGORY ENDPOINTS ====================
  // categories and category products

  static const String categories = '/categories';
  static const String categoryProducts =
      '/categories'; // add categoryId like /categories/{categoryId}
  static const String productCategories =
      '/product-categories'; // add categoryId like /product-categories/{categoryId}
  static const String subcategoryProducts =
      '/product-categories'; // add subcategoryId like /product-categories/{subcategoryId}

  // ==================== CART ENDPOINTS ====================
  // shopping cart stuff

  static const String addToCart =
      '/check-auth'; // weird but we use check-auth to add stuff
  static const String removeFromCart = '/remove-from-cart';
  static const String getCart = '/cart';
  static const String syncCart = '/sync-cart';
  static const String clearCart = '/clear-cart';

  // ==================== CHECKOUT & ORDER ENDPOINTS ====================
  // checkout and orders

  static const String checkout =
      '/check-out'; // add hashedLink like /check-out/{hashedLink}
  static const String orders = '/orders';
  static const String orderStatus =
      '/orders'; // add orderId like /orders/{orderId}/status
  static const String orderDelivery =
      '/orders'; // add orderId like /orders/{orderId}/delivery
  static const String orderHistory = '/orders';

  // ==================== PAYMENT ENDPOINTS ====================
  // payment stuff

  static const String expressPayment = '/expresspayment';
  static const String checkPayment = '/check-payment';
  static const String paymentStatus = '/payment-status';
  static const String applyCoupon = '/apply-coupon';

  // ==================== PRESCRIPTION ENDPOINTS ====================
  // prescription uploads and stuff

  static const String createPrescription = '/create-precription';
  static const String viewPrescription = '/view-prescription';
  static const String prescriptionHistory = '/prescription-history';

  // ==================== REFILL ENDPOINTS ====================
  // medicine refills

  static const String refill = '/refill';
  static const String refillCart = '/refill-cart';

  // ==================== DELIVERY & BILLING ENDPOINTS ====================
  // addresses and delivery

  static const String saveBillingAddress = '/save-billing-add';
  static const String getBillingAddress = '/get-billing-add';
  static const String calculateDeliveryFee =
      '/calculate-delivery-fee'; // POST { distance_text } → distance, delivery_fee, xpress_fee
  static const String deliveryGeofence = '/delivery-geofence';
  static const String validateGeofence = '/validate-geofence';
  static const String regions = '/regions';
  static const String regionCities =
      '/regions'; // add regionId like /regions/{regionId}/cities
  static const String cityStores =
      '/cities'; // add cityId like /cities/{cityId}/stores

  // ==================== BOOKINGS ENDPOINTS ====================
  // pharmacist / consultation bookings

  static const String bookingsAvailableSessions =
      '/bookings/available-sessions';
  static const String bookingsBook = '/bookings/book';
  static const String bookingsHistory = '/bookings/history';
  static const String bookingsCancel = '/bookings/cancel';

  // ==================== WALLET ENDPOINTS ====================
  // wallet stuff

  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletTopUp = '/wallet/top-up';
  static const String walletUse = '/wallet/use';
  static const String walletRefund = '/wallet/refund';
  static const String walletCashback = '/wallet/cashback';

  // ==================== NOTIFICATION ENDPOINTS ====================
  // notifications

  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/read';
  static const String markAllNotificationsRead = '/notifications/read-all';

  // ==================== BANNER & PROMOTIONAL ENDPOINTS ====================
  // banners and promotions

  static const String banners = '/banner';
  static const String promotionalEvents = '/promotional-events';
  static const String ernestFriday = '/ernest-friday';

  // ==================== HOME PAGE ENDPOINTS ====================
  // homepage data

  static const String homepage = '/homepage';

  // ==================== WISHLIST ENDPOINTS ====================
  // wishlist stuff

  static const String getWishlist = '/get-wishlist';
  static const String addToWishlist = '/add-to-wishlist';
  static const String removeFromWishlist =
      '/remove-from-wishlist'; // add {id} at the end

  // ==================== HEALTH TIPS ENDPOINTS ====================
  // health tips from external api

  static const String healthTips =
      'https://health.gov/myhealthfinder/api/v4/topicsearch.json';

  // ==================== EXTERNAL SERVICES ====================
  // third party services

  // google gemini api for the ai pharmacist thing
  static const String googleGeminiApi =
      'https://makersuite.google.com/app/apikey';

  // google maps web geocoding api (used for map search)
  static const String googleMapsGeocodingUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  /// Google Maps API key for web-service REST calls (Places, geocoding).
  ///
  /// Resolved in this order (see [initializeMapsApiKey]):
  /// 1. `--dart-define=GOOGLE_MAPS_API_KEY=...` or `--dart-define-from-file=.env`
  /// 2. Native config: `GMSApiKey` (iOS Info.plist) / `com.google.android.geo.API_KEY` (Android manifest)
  ///
  /// NOTE: web-service keys are sent as a query parameter. Restrict by API in
  /// Google Cloud Console (Places API, Geocoding API, Maps SDK).
  static String _googleMapsApiKeyResolved =
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static bool _mapsApiKeyInitialized = false;

  /// Call once at startup so Dart Places/Geocoding can use the same key as the native map.
  static Future<void> initializeMapsApiKey() async {
    if (_mapsApiKeyInitialized) return;
    _mapsApiKeyInitialized = true;

    if (_googleMapsApiKeyResolved.isNotEmpty) {
      debugPrint('🗺️ Maps API key loaded from dart-define');
      return;
    }

    final nativeKey = await MapsApiKeyService.loadFromNative();
    if (nativeKey.isNotEmpty) {
      _googleMapsApiKeyResolved = nativeKey;
      debugPrint(
          '🗺️ Maps API key loaded from native config (Info.plist / manifest)');
    } else {
      debugPrint(
        '🗺️ No Maps API key — add GMSApiKey (iOS), MAPS_API_KEY (Android), '
        'or run with --dart-define=GOOGLE_MAPS_API_KEY=...',
      );
    }
  }

  static String get googleMapsApiKey => _googleMapsApiKeyResolved;

  /// Whether a Maps web-service key is configured for this build.
  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;

  // ==================== HELPER METHODS ====================
  // functions to build full urls from endpoints

  /// Encodes product / upload image URLs for HTTP (spaces, `'`, `(`, `+`, etc.).
  static String _encodeProductImageUrl(String value) =>
      encodeProductImageUrl(value);

  // build the full url for a product image
  static String getProductImageUrl(String? imagePath) {
    final normalized = coerceProductImageSource(imagePath);
    if (normalized.isEmpty) {
      return '';
    }

    // if its already a full url, just return it
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return _encodeProductImageUrl(normalized);
    }

    // if it starts with /, use the admin base url
    if (normalized.startsWith('/')) {
      return _encodeProductImageUrl('$adminBaseUrl$normalized');
    }

    // otherwise assume its just a filename and add it to the product image url
    return _encodeProductImageUrl('$productImageBaseUrl/$normalized');
  }

  /// Build URL for image or storage path (uploads/, storage/, or product filename).
  static String getImageOrStorageUrl(String url) {
    final normalized = coerceProductImageSource(url);
    if (normalized.isEmpty) return '';
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return _encodeProductImageUrl(normalized);
    }
    if (normalized.startsWith('/uploads/')) {
      return _encodeProductImageUrl('$adminBaseUrl$normalized');
    }
    if (normalized.startsWith('/storage/')) {
      return _encodeProductImageUrl('$appBaseUrl$normalized');
    }
    return _encodeProductImageUrl('$productImageBaseUrl/$normalized');
  }

  /// Build URL for storage path (e.g. categories, banners).
  static String getStorageUrl(String path) {
    final encoded = path.contains('/') ? path : Uri.encodeComponent(path);
    return '$appBaseUrl/storage/$encoded';
  }

  // build full url for any endpoint
  static String getEndpointUrl(String endpoint) {
    // remove the / at the start if it has one
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$baseUrl/$cleanEndpoint';
  }

  // build url for product details
  static String getProductDetailsUrl(String urlName) {
    return '$baseUrl$productDetails/$urlName';
  }

  // build url for related products
  static String getRelatedProductsUrl(String urlName) {
    return '$baseUrl$relatedProducts/$urlName';
  }

  // build url for category products
  static String getCategoryProductsUrl(String categoryId) {
    return '$baseUrl$categoryProducts/$categoryId';
  }

  // build url for subcategory products
  static String getSubcategoryProductsUrl(String subcategoryId) {
    return '$baseUrl$productCategories/$subcategoryId';
  }

  // build url for checkout
  static String getCheckoutUrl(String hashedLink) {
    return '$baseUrl$checkout/$hashedLink';
  }

  // build url for order status
  static String getOrderStatusUrl(String orderId) {
    return '$baseUrl$orders/$orderId/status';
  }

  // build url for order delivery info
  static String getOrderDeliveryUrl(String orderId) {
    return '$baseUrl$orders/$orderId/delivery';
  }

  // build url for cities in a region
  static String getRegionCitiesUrl(String regionId) {
    return '$baseUrl$regions/$regionId/cities';
  }

  // build url for stores in a city
  static String getCityStoresUrl(String cityId) {
    return '$baseUrl$cityStores/$cityId/stores';
  }

  // build url for search
  static String getSearchUrl(String pattern) {
    return '$baseUrl$searchProducts/$pattern';
  }

  // build url for product by id
  static String getProductByIdUrl(String productId) {
    return '$baseUrl/products/$productId';
  }

  // build url for removing wishlist item
  static String getRemoveWishlistItemUrl(int wishlistItemId) {
    return '$baseUrl$removeFromWishlist/$wishlistItemId';
  }

  // build url for available booking sessions: /bookings/available-sessions?date={date}
  static String getBookingsAvailableSessionsUrl(String date) {
    final path = bookingsAvailableSessions.startsWith('/')
        ? bookingsAvailableSessions.substring(1)
        : bookingsAvailableSessions;
    return '$baseUrl/$path?date=${Uri.encodeComponent(date)}';
  }

  // build url for cancel booking: /bookings/cancel/{id}
  static String getBookingsCancelUrl(String id) {
    final path = bookingsCancel.startsWith('/')
        ? bookingsCancel.substring(1)
        : bookingsCancel;
    return '$baseUrl/$path/$id';
  }
}
