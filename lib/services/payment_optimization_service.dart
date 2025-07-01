// services/payment_optimization_service.dart
// services/payment_optimization_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../pages/auth_service.dart';
import '../pages/cartprovider.dart';
import '../pages/CartItem.dart';
import 'performance_service.dart';

class PaymentOptimizationService {
  static final PaymentOptimizationService _instance =
      PaymentOptimizationService._internal();
  factory PaymentOptimizationService() => _instance;
  PaymentOptimizationService._internal();

  // Cache configuration
  static const String _cacheKey = 'payment_cache';
  static const String _promoCacheKey = 'promo_cache';
  static const String _userDataCacheKey = 'user_data_cache';
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _promoCacheDuration = Duration(minutes: 5);
  static const Duration _userDataCacheDuration = Duration(minutes: 15);

  // API endpoints
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const String _expressPaymentEndpoint = '/expresspayment';
  static const String _checkPaymentEndpoint = '/check-payment';
  static const String _codEndpoint = '/pay-on-delivery';

  // Performance tracking
  final PerformanceService _performanceService = PerformanceService();
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _isProcessing = {};

  // Cache storage
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _performanceService.startTimer('payment_service_init');

    try {
      _prefs = await SharedPreferences.getInstance();
      await _cleanupExpiredCache();
      _isInitialized = true;

      _performanceService.stopTimer('payment_service_init');
      developer.log('Payment optimization service initialized',
          name: 'PaymentService');
    } catch (e) {
      _performanceService.stopTimer('payment_service_init');
      developer.log('Failed to initialize payment service: $e',
          name: 'PaymentService');
    }
  }

  // User data caching
  Future<Map<String, dynamic>> getCachedUserData() async {
    await _ensureInitialized();

    final cached = _prefs.getString(_userDataCacheKey);
    if (cached != null) {
      try {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _userDataCacheDuration) {
          _performanceService.trackUserInteraction('user_data_cache_hit');
          return Map<String, dynamic>.from(data['data']);
        }
      } catch (e) {
        developer.log('Failed to parse cached user data: $e',
            name: 'PaymentService');
      }
    }

    // Fetch fresh data
    _performanceService.startTimer('user_data_fetch');
    try {
      final userData = await AuthService.getCurrentUser();
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': userData ?? {},
      };

      await _prefs.setString(_userDataCacheKey, json.encode(dataToCache));
      _performanceService.stopTimer('user_data_fetch');

      return userData ?? {};
    } catch (e) {
      _performanceService.stopTimer('user_data_fetch');
      developer.log('Failed to fetch user data: $e', name: 'PaymentService');
      return {};
    }
  }

  // Promo code optimization with caching
  Future<Map<String, dynamic>> validatePromoCode(
      String promoCode, double subtotal) async {
    await _ensureInitialized();

    // Check cache first
    final cacheKey = '${_promoCacheKey}_${promoCode.toLowerCase()}';
    final cached = _prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final data = json.decode(cached);
        final timestamp = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(timestamp) < _promoCacheDuration) {
          _performanceService.trackUserInteraction('promo_cache_hit');
          return Map<String, dynamic>.from(data['result']);
        }
      } catch (e) {
        developer.log('Failed to parse cached promo data: $e',
            name: 'PaymentService');
      }
    }

    // Validate promo code
    _performanceService.startTimer('promo_validation');
    try {
      // Simulate API call for promo code validation
      await Future.delayed(Duration(milliseconds: 500));

      Map<String, dynamic> result;
      if (promoCode.toLowerCase() == 'save10' ||
          promoCode.toLowerCase() == 'discount20') {
        final discountPercentage =
            promoCode.toLowerCase() == 'save10' ? 0.10 : 0.20;
        final discountAmount = subtotal * discountPercentage;

        result = {
          'success': true,
          'discountAmount': discountAmount,
          'discountPercentage': discountPercentage,
          'message': 'Promo code applied successfully!',
        };
      } else {
        result = {
          'success': false,
          'message': 'Invalid promo code. Please try again.',
        };
      }

      // Cache the result
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'result': result,
      };
      await _prefs.setString(cacheKey, json.encode(dataToCache));

      _performanceService.stopTimer('promo_validation');
      return result;
    } catch (e) {
      _performanceService.stopTimer('promo_validation');
      developer.log('Promo validation failed: $e', name: 'PaymentService');
      return {
        'success': false,
        'message': 'Failed to validate promo code. Please try again.',
      };
    }
  }

  // Optimized payment processing
  Future<Map<String, dynamic>> processPayment({
    required CartProvider cart,
    required String paymentMethod,
    required String contactNumber,
    String? promoCode,
    double discountAmount = 0.0,
  }) async {
    await _ensureInitialized();

    // Prevent duplicate payment processing
    if (_isProcessing['payment'] == true) {
      return {
        'success': false,
        'message': 'Payment already in progress. Please wait.',
      };
    }

    _isProcessing['payment'] = true;
    _performanceService.startTimer('payment_processing');

    try {
      // Validate cart
      if (cart.cartItems.isEmpty) {
        throw Exception(
            'Your cart is empty. Please add items before proceeding with payment.');
      }

      final subtotal = cart.calculateSubtotal();
      if (subtotal <= 0) {
        throw Exception('Invalid order amount. Please check your cart items.');
      }

      // Get cached user data
      final userData = await getCachedUserData();
      final userEmail = userData['email'] ?? '';
      final userName = userData['name'] ?? 'User';

      if (userEmail.isEmpty || userEmail == "No email available") {
        throw Exception(
            'Please update your email address in your profile before making a payment.');
      }

      if (contactNumber.isEmpty) {
        throw Exception('Please provide a valid contact number for delivery.');
      }

      final deliveryFee = 0.00;
      final total = subtotal + deliveryFee - discountAmount;

      // Create order description
      String orderDesc = cart.cartItems
          .map((item) => '${item.quantity}x ${item.name}')
          .join(', ');
      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

      if (promoCode != null) {
        orderDesc += ' (Promo: $promoCode)';
      }

      final nameParts = userName.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Customer';

      final params = {
        'request': 'submit',
        'order_id': 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        'currency': 'GHS',
        'amount': total.toStringAsFixed(2),
        'order_desc': orderDesc,
        'user_name': userEmail,
        'first_name': firstName,
        'last_name': lastName,
        'email': userEmail,
        'phone_number': contactNumber,
        'account_number': contactNumber,
        'redirect_url': 'http://eclcommerce.test/complete'
      };

      final purchasedItems = List<CartItem>.from(cart.cartItems);
      final transactionId = params['order_id'];

      // Handle different payment methods
      if (paymentMethod == 'Cash on Delivery') {
        return await _processCODPayment(
          firstName: firstName,
          email: userEmail,
          phone: contactNumber,
          amount: total,
          cart: cart,
          transactionId: transactionId!,
          purchasedItems: purchasedItems,
          paymentMethod: paymentMethod,
          promoCode: promoCode,
        );
      } else {
        return await _processOnlinePayment(
          params: params,
          purchasedItems: purchasedItems,
          transactionId: transactionId!,
          paymentMethod: paymentMethod,
        );
      }
    } catch (e) {
      developer.log('Payment processing failed: $e', name: 'PaymentService');
      return {
        'success': false,
        'message': e.toString(),
      };
    } finally {
      _isProcessing['payment'] = false;
      _performanceService.stopTimer('payment_processing');
    }
  }

  // Optimized COD payment processing
  Future<Map<String, dynamic>> _processCODPayment({
    required String firstName,
    required String email,
    required String phone,
    required double amount,
    required CartProvider cart,
    required String transactionId,
    required List<CartItem> purchasedItems,
    required String paymentMethod,
    String? promoCode,
  }) async {
    _performanceService.startTimer('cod_payment');

    try {
      // Validate COD parameters
      final validation = CODPaymentService.validateParameters(
        firstName: firstName,
        email: email,
        phone: phone,
        amount: amount,
      );

      if (!validation['isValid']) {
        final errors = validation['errors'] as Map<String, String>;
        final errorMessage = errors.values.first;
        throw Exception(errorMessage);
      }

      // Get auth token
      final authToken = await AuthService.getToken();

      // Process COD payment
      final codResult = await CODPaymentService.processCODPayment(
        firstName: firstName,
        email: email,
        phone: phone,
        amount: amount,
        authToken: authToken,
      );

      if (!codResult['success']) {
        throw Exception(codResult['message'] ?? 'COD payment failed');
      }

      // Create order in backend
      try {
        final orderItems = purchasedItems
            .map((item) => {
                  'productId': item.productId,
                  'name': item.name,
                  'imageUrl': item.image,
                  'quantity': item.quantity,
                  'price': item.price,
                  'batchNo': item.batchNo,
                })
            .toList();

        final orderResult = await AuthService.createCashOnDeliveryOrder(
          items: orderItems,
          totalAmount: amount,
          orderId: transactionId,
          paymentMethod: paymentMethod,
          promoCode: promoCode,
        );

        if (orderResult['status'] == 'success') {
          cart.clearCart();
        }
      } catch (e) {
        developer.log('Failed to save order to server: $e',
            name: 'PaymentService');
        // Continue with order even if server save fails
      }

      _performanceService.stopTimer('cod_payment');
      return {
        'success': true,
        'message':
            'COD payment processed successfully! You will pay when you receive your order.',
        'transactionId': transactionId,
        'paymentMethod': paymentMethod,
      };
    } catch (e) {
      _performanceService.stopTimer('cod_payment');
      throw e;
    }
  }

  // Optimized online payment processing
  Future<Map<String, dynamic>> _processOnlinePayment({
    required Map<String, dynamic> params,
    required List<CartItem> purchasedItems,
    required String transactionId,
    required String paymentMethod,
  }) async {
    _performanceService.startTimer('online_payment');

    try {
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http
          .post(
        Uri.parse('$_baseUrl$_expressPaymentEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(params),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'Payment request timed out. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final redirectUrl = response.body.trim();

        if (redirectUrl.isEmpty) {
          throw Exception('Received empty payment URL from server.');
        }

        _performanceService.stopTimer('online_payment');
        return {
          'success': true,
          'redirectUrl': redirectUrl,
          'transactionId': transactionId,
          'paymentMethod': paymentMethod,
          'purchasedItems': purchasedItems,
        };
      } else {
        throw Exception('Payment Failed, try again');
      }
    } catch (e) {
      _performanceService.stopTimer('online_payment');
      throw e;
    }
  }

  // Optimized payment status checking with caching
  Future<Map<String, dynamic>> checkPaymentStatus({
    String? transactionId,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cacheKey = '${_cacheKey}_status_${transactionId ?? 'current'}';
      final cached = _prefs.getString(cacheKey);

      if (cached != null) {
        try {
          final data = json.decode(cached);
          final timestamp = DateTime.parse(data['timestamp']);

          if (DateTime.now().difference(timestamp) < _cacheDuration) {
            _performanceService
                .trackUserInteraction('payment_status_cache_hit');
            return Map<String, dynamic>.from(data['result']);
          }
        } catch (e) {
          developer.log('Failed to parse cached payment status: $e',
              name: 'PaymentService');
        }
      }
    }

    _performanceService.startTimer('payment_status_check');
    try {
      final tokenRaw = await AuthService.getToken();
      if (tokenRaw == null || tokenRaw.isEmpty) {
        throw Exception('Please log in to check payment status');
      }

      final userId = await AuthService.getCurrentUserID();
      if (userId == null) {
        throw Exception('User ID not found. Please log in again.');
      }

      final requestBody = {'user_id': userId};

      final response = await http
          .post(
        Uri.parse('$_baseUrl$_checkPaymentEndpoint'),
        headers: {
          'Authorization': 'Bearer $tokenRaw',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Payment status check timed out. Please try again.');
        },
      );

      Map<String, dynamic> result;

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          result = {
            'status': 'pending',
            'message': 'Waiting for payment confirmation...',
          };
        } else {
          String responseBody = response.body.trim();
          int jsonStartIndex = responseBody.indexOf('{');
          if (jsonStartIndex != -1) {
            responseBody = responseBody.substring(jsonStartIndex);
          }

          final data = json.decode(responseBody);
          result = _processPaymentStatus(data);
        }
      } else {
        throw Exception('Failed to verify payment: ${response.statusCode}');
      }

      // Cache the result
      final cacheKey = '${_cacheKey}_status_${transactionId ?? 'current'}';
      final dataToCache = {
        'timestamp': DateTime.now().toIso8601String(),
        'result': result,
      };
      await _prefs.setString(cacheKey, json.encode(dataToCache));

      _performanceService.stopTimer('payment_status_check');
      return result;
    } catch (e) {
      _performanceService.stopTimer('payment_status_check');
      developer.log('Payment status check failed: $e', name: 'PaymentService');
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  // Process payment status response
  Map<String, dynamic> _processPaymentStatus(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';

    if (status.contains('completed') || status.contains('success')) {
      return {
        'status': 'success',
        'message': 'Payment completed successfully',
        'transaction_id': data['transaction_id'],
      };
    } else if (status.contains('declined') || status.contains('failed')) {
      return {
        'status': 'failed',
        'message': 'Payment was declined. Please try another method.',
        'transaction_id': data['transaction_id'],
      };
    } else if (status.contains('pending') || status.contains('processing')) {
      return {
        'status': 'pending',
        'message': 'Payment is being processed. Please wait...',
      };
    } else {
      return {
        'status': 'pending',
        'message': 'Payment status is being processed',
      };
    }
  }

  // Debounced function calls
  void debounce(String key, VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, callback);
  }

  // Cleanup expired cache
  Future<void> _cleanupExpiredCache() async {
    try {
      final keys = _prefs.getKeys();
      final now = DateTime.now();

      for (final key in keys) {
        if (key.startsWith(_cacheKey) ||
            key.startsWith(_promoCacheKey) ||
            key.startsWith(_userDataCacheKey)) {
          final cached = _prefs.getString(key);
          if (cached != null) {
            try {
              final data = json.decode(cached);
              final timestamp = DateTime.parse(data['timestamp']);

              Duration cacheDuration;
              if (key.startsWith(_promoCacheKey)) {
                cacheDuration = _promoCacheDuration;
              } else if (key.startsWith(_userDataCacheKey)) {
                cacheDuration = _userDataCacheDuration;
              } else {
                cacheDuration = _cacheDuration;
              }

              if (now.difference(timestamp) > cacheDuration) {
                await _prefs.remove(key);
              }
            } catch (e) {
              // Remove invalid cache entries
              await _prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      developer.log('Cache cleanup failed: $e', name: 'PaymentService');
    }
  }

  // Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    await _ensureInitialized();

    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cacheKey) ||
            key.startsWith(_promoCacheKey) ||
            key.startsWith(_userDataCacheKey)) {
          await _prefs.remove(key);
        }
      }
      developer.log('Payment cache cleared', name: 'PaymentService');
    } catch (e) {
      developer.log('Failed to clear cache: $e', name: 'PaymentService');
    }
  }

  // Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'isEnabled': _performanceService.isEnabled,
      'events': _performanceService.events.length,
      'metrics': _performanceService.metrics.length,
    };
  }

  // Dispose resources
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _isProcessing.clear();
  }
}
