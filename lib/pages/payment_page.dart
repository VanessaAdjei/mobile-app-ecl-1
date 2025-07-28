// pages/payment_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'cartprovider.dart';
import 'homepage.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'cart_item.dart';
import 'order_tracking_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'cart.dart';

class ExpressPayChannel {
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.expresspay');

  static Future<Map?> startExpressPay(Map<String, String> params) async {
    try {
      final result = await _channel.invokeMethod('startExpressPay', params);
      if (result is String) {
        // If the native side returns a JSON string, decode it
        return Map<String, dynamic>.from(jsonDecode(result));
      } else if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}

class PaymentPage extends StatefulWidget {
  final String? deliveryAddress;
  final String? contactNumber;
  final String deliveryOption;
  final String? guestEmail;

  const PaymentPage({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.guestEmail,
  });

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String selectedPaymentMethod = 'Online Payment';
  bool savePaymentMethod = false;
  bool _isProcessingPayment = false;
  String _userName = "User";
  String _userEmail = "No email available";
  String _phoneNumber = "No phone number available";
  String? _paymentError;
  String? _lastPaymentToken;
  String expressPaymentForm =
      'https://eclcommerce.ernestchemists.com.gh/api/expresspayment';
  final bool _paymentSuccess = false;
  bool _showAllItems = false; // Add this state variable

  // Promo code variables
  final TextEditingController _promoCodeController = TextEditingController();
  String? _appliedPromoCode;
  double _discountAmount = 0.0;
  bool _isApplyingPromo = false;
  String? _promoError;

  final List<Map<String, dynamic>> paymentMethods = const [
    {
      'name': 'Online Payment',
      'icon': Icons.phone_android,
      'description': 'Pay with Momo or Card',
    },
    {
      'name': 'Cash on Delivery',
      'icon': Icons.money,
      'description': 'Pay when you receive your order',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserData();
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn &&
          widget.guestEmail != null &&
          widget.guestEmail!.isNotEmpty) {
        setState(() {
          _userEmail = widget.guestEmail!;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          _userName = userData?['name'] ?? "User";
          _userEmail = userData?['email'] ?? "No email available";
          _phoneNumber = userData?['phone'] ?? "";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "User";
          _userEmail = "No email available";
          _phoneNumber = "";
        });
      }
    }
  }

  void queryPayment(String token) {
    setState(() {
      _paymentError = 'Query payment is not implemented in platform channel.';
    });
  }

  Future<Map<String, dynamic>> _verifyPayment(
      String token, String transactionId) async {
    final authToken = await AuthService.getToken();
    debugPrint('[DEBUG] Using token for payment verification: $authToken');
    if (authToken == null) {
      return {
        'verified': false,
        'status': 'error',
        'message': 'No auth token found',
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/check-payment'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'user_id': await AuthService.getCurrentUserID(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'verified': true,
          'status': data['status'] ?? 'success',
          'message': data['message'] ?? 'Payment verified successfully',
        };
      }

      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification failed',
      };
    } catch (e) {
      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification error: $e',
      };
    }
  }

  // Helper to get the correct Authorization header (Bearer or Guest)
  Future<String?> getAuthHeader() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();
    if (isLoggedIn &&
        token != null &&
        token.isNotEmpty &&
        !token.startsWith('guest_')) {
      return 'Bearer $token';
    } else if (!isLoggedIn && token != null && token.startsWith('guest_')) {
      return 'Guest $token';
    }
    return null;
  }

  Future<void> processPayment(CartProvider cart) async {
    debugPrint('[DEBUG] Entered processPayment');
    if (!mounted) return;

    // Print selected payment method and token at the start
    final debugToken = await AuthService.getToken();
    debugPrint('[DEBUG] Payment button pressed. Method: '
        '$selectedPaymentMethod Token:$debugToken');

    setState(() {
      _paymentError = null;
      _isProcessingPayment = true;
    });

    try {
      // Validate cart
      if (cart.cartItems.isEmpty) {
        debugPrint('[DEBUG] Returning early: cart is empty');
        throw Exception(
            'Your cart is empty. Please add items before proceeding with payment.');
      }
      debugPrint('[DEBUG] Passed cart empty check');

      // Calculate total
      final subtotal = cart.calculateSubtotal();
      if (subtotal <= 0) {
        debugPrint('[DEBUG] Returning early: subtotal <= 0');
        throw Exception('Invalid order amount. Please check your cart items.');
      }
      debugPrint('[DEBUG] Passed subtotal check');

      final deliveryFee = 0.00;
      final total = subtotal + deliveryFee - _discountAmount;

      // Determine if user is guest
      final authHeader = await getAuthHeader();
      final isGuest = authHeader != null && authHeader.startsWith('Guest ');
      debugPrint('[DEBUG] Passed guest check');
      debugPrint('[DEBUG] isGuest: $isGuest, authHeader: $authHeader');

      // Validate user data
      if (!isGuest &&
          (_userEmail.isEmpty || _userEmail == "No email available")) {
        debugPrint(
            '[DEBUG] Returning early: user email is empty or not available');
        throw Exception(
            'Please update your email address in your profile before making a payment.');
      }
      debugPrint('[DEBUG] Passed user data check');

      if (widget.contactNumber?.isEmpty ?? true) {
        debugPrint('[DEBUG] Returning early: contact number is empty');
        throw Exception('Please provide a valid contact number for delivery.');
      }
      debugPrint('[DEBUG] Passed contact number check');

      // Create order description
      String orderDesc = cart.cartItems
          .map((item) => '${item.quantity}x ${item.name}')
          .join(', ');
      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

      // Add promo code info to order description if applied
      if (_appliedPromoCode != null) {
        orderDesc += ' (Promo: $_appliedPromoCode)';
      }

      final nameParts = _userName.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Customer';

      final params = {
        'request': 'submit',
        'order_id': 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        'currency': 'GHS',
        'amount': total.toStringAsFixed(2),
        'order_desc': orderDesc,
        'user_name': _userEmail,
        'first_name': firstName,
        'last_name': lastName,
        'email': _userEmail,
        'phone_number': widget.contactNumber ?? _phoneNumber,
        'account_number': widget.contactNumber ?? _phoneNumber,
        'address': widget.deliveryAddress ?? '',
        'region': '',
        'city': '',
        'redirect_url': 'http://eclcommerce.test/complete',
        'shipping_type': widget.deliveryOption,
      };

      final purchasedItems = List<CartItem>.from(cart.cartItems);
      final transactionId = params['order_id'];

      if (selectedPaymentMethod == 'Cash on Delivery') {
        if (!mounted) return;

        // Extract first name from user name
        final firstName = _userName.split(' ').first.isNotEmpty
            ? _userName.split(' ').first
            : 'Customer';

        // Validate COD payment parameters
        final emailForValidation =
            isGuest ? (widget.guestEmail ?? '') : _userEmail;
        debugPrint(
            '[DEBUG] Email used for COD validation: "$emailForValidation"');
        final validation = CODPaymentService.validateParameters(
          firstName: firstName,
          email: emailForValidation,
          phone: widget.contactNumber ?? _phoneNumber,
          amount: total,
        );
        debugPrint('[DEBUG] COD validation result: $validation');

        if (!validation['isValid']) {
          final errors = validation['errors'] as Map<String, String>;
          final errorMessage = errors.values.first;
          throw Exception(errorMessage);
        }

        // Get the correct auth header (Bearer or Guest)
        final authHeader = await getAuthHeader();
        if (authHeader == null) {
          setState(() {
            _paymentError =
                'You must be logged in or have a guest session to use Cash on Delivery.';
          });
          return;
        }

        // Extract just the token string for CODPaymentService
        String? tokenString;
        if (authHeader.startsWith('Bearer ')) {
          tokenString = authHeader.substring(7);
        } else if (authHeader.startsWith('Guest ')) {
          tokenString = authHeader.substring(6);
        }

        // Debug print for email being sent to COD API
        debugPrint('[DEBUG] COD API call email: "$emailForValidation"');

        // Process COD payment through the API
        final codResult = await CODPaymentService.processCODPayment(
          firstName: firstName,
          email: emailForValidation,
          phone: widget.contactNumber ?? _phoneNumber,
          amount: total,
          authToken: tokenString,
        );

        debugPrint('[DEBUG] COD Payment API Response: ${codResult.toString()}');

        if (!codResult['success']) {
          throw Exception(codResult['message'] ?? 'COD payment failed');
        }

        // Navigate to OrderConfirmationPage immediately
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationPage(
              paymentParams: params,
              purchasedItems: purchasedItems,
              initialStatus: 'pending',
              initialTransactionId: transactionId,
              paymentSuccess: true,
              paymentVerified: true,
              paymentToken: null,
              paymentMethod: selectedPaymentMethod,
            ),
          ),
          (route) => false,
        );

        // Remove each item from the backend cart after successful COD payment
        Future.microtask(() async {
          for (final item in List<CartItem>.from(cart.cartItems)) {
            await cart.removeFromCart(item.id);
          }
          cart.clearCart();
        });

        // Create the order in the backend for cash on delivery
        try {
          // Convert cart items to the format expected by the API
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
            totalAmount: total,
            orderId: transactionId!,
            paymentMethod: selectedPaymentMethod,
            promoCode: _appliedPromoCode,
          );

          if (orderResult['status'] != 'success') {
            // Show warning but still proceed with the order
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: ${orderResult['message'] ?? 'Could not save order to server, but proceeding with order'}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: EdgeInsets.all(16),
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            // Clear the cart after successful order creation
            cart.clearCart();
          }
        } catch (e) {
          // Ignore order creation errors for now
        }
        return;
      }

      // Online Payment Flow
      final isLoggedIn = await AuthService.isLoggedIn();
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (isLoggedIn &&
          token != null &&
          token.isNotEmpty &&
          !token.startsWith('guest_')) {
        headers['Authorization'] = 'Bearer $token';
      } else if (!isLoggedIn && token != null && token.startsWith('guest_')) {
        final guestId = token;
        headers['Authorization'] = 'Guest $guestId';
        headers['X-Guest-ID'] = guestId;
        debugPrint('[DEBUG] Guest payment status check: guest_id = $guestId');
      } else {
        setState(() {
          _paymentError =
              'You must be logged in or have a guest session to use online payment. Please choose Cash on Delivery or log in.';
        });
        debugPrint('[DEBUG] Returning early: no valid token for payment');
        return;
      }

      debugPrint('[DEBUG] Payment API Request Headers: $headers');
      debugPrint('[DEBUG] Payment API Request Body: ${jsonEncode(params)}');
      debugPrint('[DEBUG] About to call expresspay API');
      http.Response? response;
      try {
        response = await http.post(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/expresspayment'),
          headers: headers,
          body: jsonEncode(params),
        );
        debugPrint(
            '[DEBUG] Online Payment API Response: Status: ${response.statusCode}, Body: ${response.body}');
      } catch (e) {
        debugPrint('[DEBUG] Exception during expresspay API call: $e');
        rethrow;
      }
      debugPrint('[DEBUG] Finished expresspay API call');

      if (response.statusCode == 200) {
        final redirectUrl = response.body.trim();

        if (redirectUrl.isEmpty) {
          throw Exception('Received empty payment URL from server.');
        }

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(
              url: redirectUrl,
              paymentParams: params,
              purchasedItems: purchasedItems,
              paymentMethod: selectedPaymentMethod,
              onPaymentComplete: (success, token) async {
                if (success && token != null) {
                  try {
                    final result = await _verifyPayment(token, transactionId!);
                    final statusText =
                        result['status']?.toString().toLowerCase() ?? '';

                    final isDeclined = statusText.contains('declined');
                    final isCompleted = statusText.contains('completed');

                    if (result['verified'] == true &&
                        isCompleted &&
                        !isDeclined) {
                      // Payment verified and completed
                    } else {
                      // Payment not completed or declined
                    }
                  } catch (e) {
                    throw Exception(
                        'Failed to verify payment status. Please contact support.');
                  }
                }
              },
            ),
          ),
        );

        // WebView was closed - user either completed payment or cancelled
        // Don't automatically navigate to confirmation page
        // Let the WebView handle the navigation based on payment completion
      } else if (response.statusCode == 401) {
        throw Exception('Payment Failed, try again');
      } else if (response.statusCode == 403) {
        throw Exception('Payment Failed, try again');
      } else if (response.statusCode == 404) {
        throw Exception('Payment Failed, try again');
      } else if (response.statusCode >= 500) {
        throw Exception('Payment Failed, try again');
      } else {
        throw Exception('Payment Failed, try again');
      }
    } catch (e) {
      setState(() {
        _paymentError = e.toString();
      });
      _showPaymentFailureDialog(e.toString());
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // Enhanced header with better design
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0))
                ],
                child: Container(
                  padding: EdgeInsets.only(top: topPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header with back button and title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            BackButtonUtils.withConfirmation(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              title: 'Leave Payment',
                              message:
                                  'Are you sure you want to leave the payment page? Your progress will be saved.',
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Payment Information',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: 48), // Balance the back button
                          ],
                        ),
                      ),
                      // Enhanced progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressStep("Cart",
                                  isActive: false, isCompleted: true, step: 1),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Delivery",
                                  isActive: false, isCompleted: true, step: 2),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Payment",
                                  isActive: true, isCompleted: false, step: 3),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Confirmation",
                                  isActive: false, isCompleted: false, step: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Items Section (First)
                          Animate(
                            effects: [
                              FadeEffect(duration: 400.ms),
                              SlideEffect(
                                  duration: 400.ms,
                                  begin: Offset(0, 0.1),
                                  end: Offset(0, 0))
                            ],
                            child: _buildOrderItems(cart),
                          ),
                          const SizedBox(height: 8),

                          // Order Summary Section (Second)
                          Animate(
                            effects: [
                              FadeEffect(duration: 400.ms),
                              SlideEffect(
                                  duration: 400.ms,
                                  begin: Offset(0, 0.1),
                                  end: Offset(0, 0))
                            ],
                            child: _buildOrderSummary(cart),
                          ),
                          const SizedBox(height: 8),

                          // Error Display
                          if (_paymentError != null) ...[
                            const SizedBox(height: 8),
                            Animate(
                              effects: [
                                FadeEffect(duration: 400.ms),
                                SlideEffect(
                                    duration: 400.ms,
                                    begin: Offset(0, 0.1),
                                    end: Offset(0, 0))
                              ],
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 40,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Payment Error',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            "Please try again",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Bottom spacing for fixed payment section
                          const SizedBox(height: 120),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Fixed Payment Methods and Button at Bottom
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Payment Methods Section
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms),
                        SlideEffect(
                            duration: 400.ms,
                            begin: Offset(0, 0.1),
                            end: Offset(0, 0))
                      ],
                      child: _buildPaymentMethods(),
                    ),

                    // Payment Button
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms),
                        SlideEffect(
                            duration: 400.ms,
                            begin: Offset(0, 0.1),
                            end: Offset(0, 0))
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Consumer<CartProvider>(
                          builder: (context, cart, child) {
                            return Container(
                              width: double.infinity,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.green.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _isProcessingPayment
                                      ? null
                                      : () => processPayment(cart),
                                  child: Center(
                                    child: _isProcessingPayment
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                selectedPaymentMethod ==
                                                        'Cash on Delivery'
                                                    ? 'Processing COD Order...'
                                                    : 'Processing...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                selectedPaymentMethod ==
                                                        'Cash on Delivery'
                                                    ? Icons.money
                                                    : Icons.payment,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                selectedPaymentMethod ==
                                                        'Cash on Delivery'
                                                    ? 'PLACE ORDER (COD)'
                                                    : 'CONTINUE TO PAYMENT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isProcessingPayment)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _paymentError ?? 'An error occurred with your payment',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 50,
      height: 1,
      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 1.5,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 12, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight:
                isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    // Otherwise, treat as filename
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  Widget _buildPaymentMethods() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: Colors.green[700],
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Payment Method Cards
          ...paymentMethods.map((method) {
            final isSelected = selectedPaymentMethod == method['name'];
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.1),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        selectedPaymentMethod = method['name'];
                        _paymentError = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // Radio Button
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                              color: isSelected
                                  ? Colors.green.shade600
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 7,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          // Method Icon
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Icon(
                              method['icon'],
                              color: isSelected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Method Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  method['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.green.shade700
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  method['description'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.green.shade600
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderItems(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.shopping_bag,
                    color: Colors.green[700],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'YOUR ORDER',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Order Items
            if (cart.cartItems.isNotEmpty) ...[
              Text(
                'Items in your order (${cart.cartItems.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...cart.cartItems
                  .take(_showAllItems ? cart.cartItems.length : 3)
                  .map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  getImageUrl(item.image),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${item.quantity}x GHS ${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      )),
              if (cart.cartItems.length > 3 && !_showAllItems) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllItems = true;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_more,
                          color: Colors.blue.shade600,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Show ${cart.cartItems.length - 3} more items',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (cart.cartItems.length > 3 && _showAllItems) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllItems = false;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_less,
                          color: Colors.grey.shade600,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Show less',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final subtotal = cart.calculateSubtotal();
    final deliveryFee = 0.00;
    final total = subtotal + deliveryFee - _discountAmount;



    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.green[700],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Promo Code Section
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Promo Code Header
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Colors.blue[700],
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PROMO CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.blue[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Promo Code Input
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            // color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            // border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: TextField(
                            controller: _promoCodeController,
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              suffixIcon: _appliedPromoCode != null
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.green[600],
                                      size: 16,
                                    )
                                  : null,
                            ),
                            style: TextStyle(fontSize: 11),
                            enabled: _appliedPromoCode == null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_appliedPromoCode == null)
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed:
                                _isApplyingPromo ? null : _applyPromoCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: _isApplyingPromo
                                ? SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Apply',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: _removePromoCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Promo Code Status
                  if (_promoError != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[600],
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _promoError!,
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_appliedPromoCode != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green[600],
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Promo code "$_appliedPromoCode" applied! You saved GHS ${_discountAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Price Breakdown
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', subtotal,
                      icon: Icons.shopping_cart_outlined),
                  const SizedBox(height: 6),
                  if (_discountAmount > 0) ...[
                    _buildSummaryRow('Discount', -_discountAmount,
                        icon: Icons.local_offer, isDiscount: true),
                    const SizedBox(height: 6),
                  ],
                  _buildSummaryRow('Delivery Fee', deliveryFee,
                      icon: Icons.local_shipping_outlined),
                  Divider(height: 12, thickness: 1, color: Colors.grey[300]),
                  _buildSummaryRow('TOTAL', total,
                      isHighlighted: true, icon: Icons.payment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isHighlighted = false, IconData? icon, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: isDiscount
                  ? Colors.green[600]
                  : isHighlighted
                      ? Colors.green[700]
                      : Colors.grey[600],
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                fontSize: isHighlighted ? 16 : 14,
                color: isDiscount
                    ? Colors.green[600]
                    : isHighlighted
                        ? Colors.grey[800]
                        : Colors.grey[700],
              ),
            ),
          ),
          Text(
            isDiscount
                ? '-GHS ${value.abs().toStringAsFixed(2)}'
                : 'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
              fontSize: isHighlighted ? 18 : 14,
              color: isDiscount
                  ? Colors.green[600]
                  : isHighlighted
                      ? Colors.green[700]
                      : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.local_offer,
                    color: Colors.blue[700],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PROMO CODE',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Promo Code Input
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _promoCodeController,
                      decoration: InputDecoration(
                        hintText: 'Enter promo code',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: _appliedPromoCode != null
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.green[600],
                                size: 18,
                              )
                            : null,
                      ),
                      style: TextStyle(fontSize: 12),
                      enabled: _appliedPromoCode == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_appliedPromoCode == null)
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _isApplyingPromo ? null : _applyPromoCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isApplyingPromo
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )
                else
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _removePromoCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Promo Code Status
            if (_promoError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[600],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _promoError!,
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_appliedPromoCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green[600],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Promo code "$_appliedPromoCode" applied! You saved GHS ${_discountAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final promoCode = _promoCodeController.text.trim();
    if (promoCode.isEmpty) {
      setState(() {
        _promoError = 'Please enter a promo code';
      });
      return;
    }

    setState(() {
      _isApplyingPromo = true;
      _promoError = null;
    });

    try {
      // Simulate API call for promo code validation
      await Future.delayed(Duration(seconds: 1));

      // Mock promo code validation - replace with actual API call
      if (promoCode.toLowerCase() == 'save10' ||
          promoCode.toLowerCase() == 'discount20' ||
          promoCode.toLowerCase() == 'test50') {
        final discountPercentage = promoCode.toLowerCase() == 'save10'
            ? 0.10
            : promoCode.toLowerCase() == 'discount20'
                ? 0.20
                : 0.50; // 50% discount for test50
        final cart = Provider.of<CartProvider>(context, listen: false);
        final subtotal = cart.calculateSubtotal();
        final discountAmount = subtotal * discountPercentage;

        debugPrint('Promo code applied: $promoCode');
        debugPrint('Subtotal: $subtotal');
        debugPrint('Discount percentage: $discountPercentage');
        debugPrint('Discount amount: $discountAmount');

        setState(() {
          _appliedPromoCode = promoCode;
          _discountAmount = discountAmount;
          _promoError = null;
        });

        // Force rebuild of the order summary
        if (mounted) {
          setState(() {});
        }
      } else {
        setState(() {
          _promoError = 'Invalid promo code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _promoError = 'Failed to apply promo code. Please try again.';
      });
    } finally {
      setState(() {
        _isApplyingPromo = false;
      });
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromoCode = null;
      _discountAmount = 0.0;
      _promoCodeController.clear();
      _promoError = null;
    });
  }

  void _showPaymentFailureDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 30,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Payment Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  'Payment Failed, try again',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Action Button
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade500,
                        Colors.red.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentInProgressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment In Progress'),
          content: const Text(
              'A payment is already in progress. Please wait for the current payment to complete.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class OrderConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> paymentParams;
  final List<CartItem> purchasedItems;
  final String? initialStatus;
  final String? initialTransactionId;
  final bool paymentSuccess;
  final bool paymentVerified;
  final String? paymentToken;
  final String paymentMethod;

  const OrderConfirmationPage({
    super.key,
    required this.paymentParams,
    required this.purchasedItems,
    this.initialStatus,
    this.initialTransactionId,
    required this.paymentSuccess,
    required this.paymentVerified,
    this.paymentToken,
    required this.paymentMethod,
  });

  @override
  _OrderConfirmationPageState createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  String? _status;
  String? _statusMessage;
  String? _transactionId;
  bool _isLoading = true;
  bool _paymentSuccess = false;
  bool _hasFetchedStatus = false;
  bool _showCheckStatusButton = false;
  Timer? _statusCheckTimer;
  Timer? _buttonShowTimer;
  Timer? _emptyResponseTimer;
  DateTime? _firstEmptyResponseTime;
  int _emptyResponseCount = 0;
  static const int _maxEmptyResponseTimeMinutes = 3;
  static const int _maxEmptyResponseCount =
      36; // 3 minutes / 5 seconds = 36 checks

  @override
  void initState() {
    super.initState();
    // For cash on delivery, always show success
    if (widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      _status = "success";
      _paymentSuccess = true;
      _statusMessage = "Order successfully placed! You will pay on delivery.";
      _isLoading = false;
    } else {
      // For online payments, show loading and check status
      _status = "pending";
      _statusMessage = "Please wait while we process your payment...";
      _isLoading = true;

      // Start periodic status checking
      _startStatusChecking();
    }
    _transactionId = widget.initialTransactionId;
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _buttonShowTimer?.cancel();
    _emptyResponseTimer?.cancel();
    super.dispose();
  }

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    // Otherwise, treat as filename
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  void _startStatusChecking() {
    // Check status immediately
    _checkPaymentStatus();

    // Set up periodic checking every 5 seconds instead of every second
    _statusCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkPaymentStatus();
      } else {
        timer.cancel();
      }
    });

    // Show check status button after 10 seconds if still pending
    _buttonShowTimer = Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showCheckStatusButton = true;
        });
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    try {
      debugPrint('[DEBUG] _checkPaymentStatus called');
      setState(() {
        _isLoading = true;
      });
      final result = await _fetchPaymentStatus();
      debugPrint('[DEBUG] _fetchPaymentStatus result: $result');
      if (mounted) {
        setState(() {
          debugPrint(
              '[DEBUG] setState in _checkPaymentStatus: updating status to ${result['status']?.toString() ?? 'null'}');
          final newStatus = result['status'];
          final currentStatus = _status?.toLowerCase();

          // Always update status if we get a new status from server
          // Only keep failed status if server returns pending/error/null
          if (currentStatus == 'failed' &&
              (newStatus == 'pending' ||
                  newStatus == 'error' ||
                  newStatus == null)) {
            // Keep the failed status, don't update
            _statusMessage = result['message'] ?? _statusMessage;
          } else {
            // Update status normally - this includes updating from failed to success
            _status = newStatus;
            _statusMessage = result['message'];
          }

          _paymentSuccess = _status?.toLowerCase() == 'success';
          _isLoading = false;

          // Handle different payment states
          if (_status?.toLowerCase() == 'success') {
            _statusCheckTimer?.cancel();
            _buttonShowTimer?.cancel();
            _emptyResponseTimer?.cancel();
            _showCheckStatusButton = false;
            // Reset empty response tracking
            _firstEmptyResponseTime = null;
            _emptyResponseCount = 0;
          } else if (_status?.toLowerCase() == 'failed') {
            _statusCheckTimer?.cancel(); // Stop automatic checks
            _buttonShowTimer?.cancel(); // Cancel the button show timer
            _emptyResponseTimer?.cancel();
            // Don't hide the check status button for failed payments
            // Reset empty response tracking
            _firstEmptyResponseTime = null;
            _emptyResponseCount = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Don't change status to 'pending' if it's already 'failed'
          if (_status?.toLowerCase() != 'failed') {
            _status = 'pending';
            _statusMessage =
                'Unable to verify payment status. Please try again.';
          } else {
            _statusMessage =
                'Unable to verify payment status. Please try again.';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.purchasedItems
        .fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // Enhanced header with better design
              Animate(
                effects: [
                  FadeEffect(duration: 400.ms),
                  SlideEffect(
                      duration: 400.ms,
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0))
                ],
                child: Container(
                  padding: EdgeInsets.only(top: topPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                        Colors.green.shade800,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header with back button and title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            AppBackButton(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              onPressed: () {
                                // Navigate back to home page using a more direct approach
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HomePage(),
                                  ),
                                  (route) => false,
                                );
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Order Confirmation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: 48), // Balance the back button
                          ],
                        ),
                      ),
                      // Enhanced progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressStep("Cart",
                                  isActive: false, isCompleted: true, step: 1),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Delivery",
                                  isActive: false, isCompleted: true, step: 2),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Payment",
                                  isActive: true, isCompleted: false, step: 3),
                              _buildProgressLine(isActive: false),
                              _buildProgressStep("Confirmation",
                                  isActive: false, isCompleted: false, step: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _isLoading = true);
                    try {
                      final result = await _fetchPaymentStatus();
                      setState(() {
                        _status = result['status'];
                        _statusMessage = result['message'];
                        _hasFetchedStatus = true;
                      });
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _status?.toLowerCase() == 'success'
                                  ? [
                                      Colors.green.shade50,
                                      Colors.green.shade100
                                    ]
                                  : _status?.toLowerCase() == 'failed'
                                      ? [
                                          Colors.red.shade50,
                                          Colors.red.shade100
                                        ]
                                      : [
                                          Colors.orange.shade50,
                                          Colors.orange.shade100
                                        ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _status?.toLowerCase() == 'success'
                                      ? Icons.check_circle
                                      : _status?.toLowerCase() == 'failed'
                                          ? Icons.error
                                          : Icons.pending,
                                  color: _getStatusColor(_status),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _getStatusLabel(_status),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(_status),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getStatusMessage(_status),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getStatusColor(_status)
                                      .withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (widget.paymentMethod !=
                                  'Cash on Delivery') ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.payment,
                                            size: 18,
                                            color: _getStatusColor(_status),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            widget.paymentMethod,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: _getStatusColor(_status),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_showCheckStatusButton) ...[
                                      SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            debugPrint(
                                                '[DEBUG] Check Status button pressed');
                                            _checkPaymentStatus();
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _isLoading
                                                  ? SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                _getStatusColor(
                                                                    _status)),
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.refresh,
                                                      size: 18,
                                                      color: _getStatusColor(
                                                          _status),
                                                    ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Check Status',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      _getStatusColor(_status),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Items
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Order Items',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...widget.purchasedItems.map((item) =>
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Product Image
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    getImageUrl(item.image),
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
                                                      if (loadingProgress ==
                                                          null) {
                                                        return child;
                                                      }
                                                      return Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[200],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            value: loadingProgress
                                                                        .expectedTotalBytes !=
                                                                    null
                                                                ? loadingProgress
                                                                        .cumulativeBytesLoaded /
                                                                    loadingProgress
                                                                        .expectedTotalBytes!
                                                                : null,
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[200],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                color: Colors
                                                                    .grey[400],
                                                                size: 20),
                                                            Text(
                                                              'No Image',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[400],
                                                                fontSize: 10,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Product Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'GHS ${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Item Total
                                                Text(
                                                  'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                      const Divider(height: 24),
                                      // Total
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Amount',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'GHS ${total.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_status?.toLowerCase() == 'failed') ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const HomePage(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                          icon: const Icon(Icons.shopping_cart,
                                              size: 18),
                                          label: const Text('Continue Shopping',
                                              style: TextStyle(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const Cart(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                          icon: const Icon(Icons.refresh,
                                              size: 18),
                                          label: const Text('Try Again',
                                              style: TextStyle(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Only show Track Order button for successful payments
                                  if (_paymentSuccess) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const HomePage(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                          icon: const Icon(Icons.shopping_cart,
                                              size: 18),
                                          label: const Text('Continue Shopping',
                                              style: TextStyle(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    OrderTrackingPage(
                                                  orderDetails: {
                                                    'order_id': _transactionId,
                                                    'transaction_id':
                                                        _transactionId,
                                                    'status': _status,
                                                    'created_at': DateTime.now()
                                                        .toIso8601String(),
                                                    'product_name': widget
                                                            .purchasedItems
                                                            .isNotEmpty
                                                        ? widget.purchasedItems
                                                            .first.name
                                                        : 'Unknown Product',
                                                    'product_img': widget
                                                            .purchasedItems
                                                            .isNotEmpty
                                                        ? widget.purchasedItems
                                                            .first.image
                                                        : '',
                                                    'qty': widget.purchasedItems
                                                        .fold(
                                                            0,
                                                            (sum, item) =>
                                                                sum +
                                                                item.quantity),
                                                    'price': widget
                                                            .purchasedItems
                                                            .isNotEmpty
                                                        ? widget.purchasedItems
                                                            .first.price
                                                        : 0,
                                                    'total_price': widget
                                                        .purchasedItems
                                                        .fold(
                                                            0.0,
                                                            (sum, item) =>
                                                                sum +
                                                                (item.price *
                                                                    item.quantity)),
                                                    'order_items': widget
                                                        .purchasedItems
                                                        .map((item) => {
                                                              'product_name':
                                                                  item.name,
                                                              'product_img':
                                                                  item.image,
                                                              'qty':
                                                                  item.quantity,
                                                              'price':
                                                                  item.price,
                                                              'batch_no':
                                                                  item.batchNo,
                                                            })
                                                        .toList(),
                                                    'is_multi_item': widget
                                                            .purchasedItems
                                                            .length >
                                                        1,
                                                    'item_count': widget
                                                        .purchasedItems.length,
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.local_shipping,
                                              size: 18),
                                          label: const Text('Track Order',
                                              style: TextStyle(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_hasFetchedStatus) ...[
              Row(
                children: [
                  Icon(
                    _getStatusIcon(_status),
                    color: _getStatusColor(_status),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _getStatusLabel(_status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(_status),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _statusMessage ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return Colors.blue;
    } else if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return Colors.green;
    } else if (status?.toLowerCase() == 'failed') {
      return Colors.red;
    }
    return Colors.orange;
  }

  IconData _getStatusIcon(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return Icons.hourglass_empty;
    } else if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return Icons.check_circle;
    } else if (status?.toLowerCase() == 'failed') {
      return Icons.error;
    }
    return Icons.pending;
  }

  String _getStatusLabel(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return 'Processing Payment';
    } else if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return 'Order Successfully Placed';
    } else if (status?.toLowerCase() == 'failed') {
      return 'Payment Failed';
    }
    return 'Payment Pending';
  }

  String _getStatusMessage(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return 'Please wait while we process your payment...';
    } else if (widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return 'Your order has been placed successfully. You will pay when the items are delivered.';
    } else if (status?.toLowerCase() == 'success') {
      return 'Your payment was successful and your order has been placed.';
    } else if (status?.toLowerCase() == 'failed') {
      return 'Your payment was declined. Please try another payment method.';
    }
    return 'Your payment is being processed. Please wait while we confirm your payment.';
  }

  Future<Map<String, dynamic>> _fetchPaymentStatus() async {
    try {
      debugPrint('[DEBUG] _fetchPaymentStatus started');
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      final tokenRaw = await AuthService.getToken();
      String? userId = await AuthService.getCurrentUserID();
      String? authHeader;
      Map<String, dynamic> requestBody = {};

      debugPrint(
          '[DEBUG] Auth check - isLoggedIn: $isLoggedIn, tokenRaw: ${tokenRaw?.substring(0, 10)}..., userId: $userId');

      if (isLoggedIn &&
          tokenRaw != null &&
          tokenRaw.isNotEmpty &&
          !tokenRaw.startsWith('guest_')) {
        // Logged-in user: ONLY use Bearer token, never guest_id
        authHeader = 'Bearer $tokenRaw';
        if (userId == null) {
          debugPrint('[DEBUG] Early return: userId is null');
          return {'status': 'error', 'message': ''};
        }
        requestBody = {'user_id': userId};
        debugPrint('[DEBUG] Using logged-in user flow');
      } else if (!isLoggedIn &&
          tokenRaw != null &&
          tokenRaw.startsWith('guest_')) {
        // Guest user: ONLY use guest_id if not logged in
        final guestId = tokenRaw;
        authHeader = 'Guest $guestId';
        requestBody = {'guest_id': guestId};
        debugPrint('[DEBUG] Guest payment status check: guest_id = $guestId');
      } else {
        debugPrint('[DEBUG] Early return: no valid auth found');
        return {'status': 'error', 'message': ''};
      }

      // Make the request with timeout
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      headers['Authorization'] = authHeader;
      if (!isLoggedIn && tokenRaw.startsWith('guest_')) {
        headers['X-Guest-ID'] = tokenRaw;
      }
      debugPrint('[DEBUG] Payment Status Check - Request Headers: $headers');
      debugPrint(
          '[DEBUG] Payment Status Check - Request Body: ${jsonEncode(requestBody)}');
      
      debugPrint('[DEBUG] Making HTTP request to check-payment endpoint...');
      final response = await http
          .post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-payment'),
        headers: headers,
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[DEBUG] Payment status check timed out');
          throw TimeoutException(
              'Payment status check timed out. Please try again.');
        },
      );
      debugPrint('[DEBUG] HTTP request completed successfully');
      debugPrint(
          '[DEBUG] Payment Status Check - Raw Response: ${response.body}');

      if (response.statusCode == 200) {
        // Handle empty response
        if (response.body.isEmpty) {
          // Track empty response time
          if (_firstEmptyResponseTime == null) {
            _firstEmptyResponseTime = DateTime.now();
            _emptyResponseCount = 1;
          } else {
            _emptyResponseCount++;
          }

          // Check if we've been receiving empty responses for 3 minutes
          if (_firstEmptyResponseTime != null) {
            final timeSinceFirstEmpty =
                DateTime.now().difference(_firstEmptyResponseTime!);
            final minutesSinceFirstEmpty = timeSinceFirstEmpty.inMinutes;

            if (minutesSinceFirstEmpty >= _maxEmptyResponseTimeMinutes ||
                _emptyResponseCount >= _maxEmptyResponseCount) {
              _statusCheckTimer?.cancel();
              _buttonShowTimer?.cancel();
              _emptyResponseTimer?.cancel();

              return {
                'status': 'failed',
                'message':
                    'Payment verification failed due to server timeout. Please try again or contact support.',
              };
            }
          }

          // Try to make another request after a short delay
          await Future.delayed(Duration(seconds: 2));
          final retryResponse = await http
              .post(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/check-payment'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
              .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                  'Payment status check timed out on retry. Please try again.');
            },
          );

          if (retryResponse.body.isNotEmpty) {
            // Reset empty response tracking if we get a valid response
            _firstEmptyResponseTime = null;
            _emptyResponseCount = 0;

            try {
              // Handle malformed JSON responses that might have extra text before JSON
              String responseBody = retryResponse.body.trim();

              // Try to find JSON object in the response
              int jsonStartIndex = responseBody.indexOf('{');
              if (jsonStartIndex != -1) {
                // Extract only the JSON part
                responseBody = responseBody.substring(jsonStartIndex);
              }

              final data = json.decode(responseBody);
              return _processPaymentStatus(data);
            } catch (e) {
              throw Exception(
                  'Invalid response format from server. Please try again.');
            }
          } else {
            // Retry also returned empty response, increment count
            _emptyResponseCount++;
          }

          return {
            'status': 'pending',
            'message': 'Waiting for payment confirmation...',
          };
        } else {
          // Reset empty response tracking if we get a valid response
          _firstEmptyResponseTime = null;
          _emptyResponseCount = 0;
        }

        try {
          // Handle malformed JSON responses that might have extra text before JSON
          String responseBody = response.body.trim();

          // Try to find JSON object in the response
          int jsonStartIndex = responseBody.indexOf('{');
          if (jsonStartIndex != -1) {
            // Extract only the JSON part
            responseBody = responseBody.substring(jsonStartIndex);
          }

          final data = json.decode(responseBody);
          return _processPaymentStatus(data);
        } catch (e) {
          throw Exception(
              'Invalid response format from server. Please try again.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to check payment status.');
      } else if (response.statusCode == 404) {
        throw Exception('Payment record not found. Please contact support.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Failed to verify payment: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Payment status check timed out. Please check your internet connection and try again.');
    } on SocketException {
      throw Exception(
          'No internet connection. Please check your network and try again.');
    } on FormatException {
      throw Exception('Invalid response format from server. Please try again.');
    }
  }

  Map<String, dynamic> _processPaymentStatus(Map<String, dynamic> data) {
    // Check for specific status strings
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
      // If status is not recognized, keep as pending
      return {
        'status': 'pending',
        'message': 'Payment status is being processed',
      };
    }
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 50,
      height: 1,
      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 1.5,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 12, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight:
                isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final Function(bool) onPaymentComplete;

  const WebViewPage({
    super.key,
    required this.url,
    required this.onPaymentComplete,
  });

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });

            // Check for payment completion URLs
            if (url.contains('payment-success')) {
              widget.onPaymentComplete(true);
              Navigator.pop(context, true);
            } else if (url.contains('payment-failed')) {
              widget.onPaymentComplete(false);
              Navigator.pop(context, false);
            }
          },
          onWebResourceError: (error) {},
        ),
      );

    // Load the URL
    try {
      _webViewController.loadRequest(Uri.parse(widget.url));
    } catch (e) {
      // Handle the error appropriately
      widget.onPaymentComplete(false);
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
