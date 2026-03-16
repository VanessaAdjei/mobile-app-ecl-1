// pages/payment_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../services/auth_service.dart';
import '../providers/cart_provider.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../models/cart_item.dart';
import 'order_tracking_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/order_notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpressPayChannel {
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.expresspay');

  static Future<Map?> startExpressPay(Map<String, String> params) async {
    try {
      final result = await _channel.invokeMethod('startExpressPay', params);
      if (result is String) {
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
  final double? lat;
  final double? lng;
  final String? estimatedDeliveryTime;
  final double? distanceKm;
  final double? deliveryFee;
  final bool isOrderUrgent;

  const PaymentPage({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.guestEmail,
    this.lat,
    this.lng,
    this.estimatedDeliveryTime,
    this.distanceKm,
    this.deliveryFee,
    this.isOrderUrgent = false,
  });

  @override
  PaymentPageState createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage> {
  String selectedPaymentMethod = 'Online Payment';
  bool savePaymentMethod = false;
  bool _isProcessingPayment = false;
  String _userName = "User";
  String _userEmail = "No email available";
  String _phoneNumber = "No phone number available";
  String? _paymentError;
  String get expressPaymentForm =>
      ApiConfig.getEndpointUrl(ApiConfig.expressPayment);
  bool _showAllItems = false; 

  // Promo code variables
  final TextEditingController _promoCodeController = TextEditingController();
  String? _appliedPromoCode;
  double _discountAmount = 0.0;
  bool _isApplyingPromo = false;
  String? _promoError;

  // Slide to pay variables
  double _slidePosition = 0.0;
  bool _isSliding = false;

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
            Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkPayment)),
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


  Future<String?> getAuthHeader() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? token = await AuthService.getToken();
    if (isLoggedIn && token != null && token.isNotEmpty) {
   
      return 'Bearer $token';
    } else if (!isLoggedIn && token != null && token.isNotEmpty) {
 
      return 'Guest $token';
    }
    return null;
  }

  Future<void> processPayment(CartProvider cart) async {
    debugPrint('[DEBUG] Entered processPayment');
    if (!mounted) return;

   
    final debugToken = await AuthService.getToken();
    debugPrint('[DEBUG] Payment button pressed. Method: '
        '$selectedPaymentMethod Token:$debugToken');

    setState(() {
      _paymentError = null;
      _isProcessingPayment = true;
      _slidePosition = 0.0;
      _isSliding = false;
    });

    try {
 
      final selectedItems = cart.getSelectedItems();

    
      if (selectedItems.isEmpty) {
        debugPrint('[DEBUG] Returning early: no items selected');
        throw Exception(
            'Please select at least one item to proceed with payment.');
      }
      debugPrint(
          '[DEBUG] Passed selected items check (${selectedItems.length} items selected)');

    
      final subtotal = cart.calculateSubtotal();
      if (subtotal <= 0) {
        debugPrint('[DEBUG] Returning early: subtotal <= 0');
        throw Exception(
            'Invalid order amount. Please check your selected items.');
      }
      debugPrint('[DEBUG] Passed subtotal check');

      final deliveryFee = widget.deliveryFee ?? 0.00;
      final total = subtotal + deliveryFee - _discountAmount;

      // check if theyre a guest or logged in
      final authHeader = await getAuthHeader();
      final isGuest = authHeader != null && authHeader.startsWith('Guest ');
      debugPrint('[DEBUG] Passed guest check');
      debugPrint('[DEBUG] isGuest: $isGuest, authHeader: $authHeader');

      // make sure we have their info
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

      // make a description of what theyre ordering (only selected items)
      String orderDesc = selectedItems
          .map((item) => '${item.quantity}x ${item.name}')
          .join(', ');
      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

      // add promo code info if they used one
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
        'amount': total,
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
        'order_urgent': widget.isOrderUrgent,
      };

      // Only include selected items in purchased items
      final purchasedItems = List<CartItem>.from(selectedItems);
      final transactionId = params['order_id'];

      // Online Payment Flow
      final isLoggedIn = await AuthService.isLoggedIn();
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (isLoggedIn && token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else if (!isLoggedIn && token != null && token.isNotEmpty) {
        final guestId = token;
        headers['Authorization'] = 'Guest $guestId';
        headers['X-Guest-ID'] = guestId;
        debugPrint('[DEBUG] Guest payment status check: guest_id = $guestId');
      } else {
        setState(() {
          _paymentError =
              'You must be logged in or have a guest session to use online payment. Please log in.';
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
          Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.expressPayment)),
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
              deliveryAddress: widget.deliveryAddress ?? '',
              contactNumber: widget.contactNumber ?? _phoneNumber,
              deliveryOption: widget.deliveryOption,
              estimatedDeliveryTime:
                  widget.estimatedDeliveryTime ?? 'Calculating ETA',
              deliveryFee: deliveryFee,
              discount: _discountAmount,
              onPaymentComplete: (success, token) async {
                if (success && token != null) {
                  try {
                    final result =
                        await _verifyPayment(token, transactionId.toString());
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
      if (mounted) {
        setState(() {
          _paymentError = e.toString();
        });
        _showPaymentFailureDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _slidePosition = 0.0;
          _isSliding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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
                      if (widget.isOrderUrgent) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emergency_rounded, size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Emergency order',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          // Order Items Section (First) - Item details
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

                          // Delivery Information Section (Second) - if delivery
                          if (widget.deliveryOption == 'delivery') ...[
                            Animate(
                              effects: [
                                FadeEffect(duration: 400.ms),
                                SlideEffect(
                                    duration: 400.ms,
                                    begin: Offset(0, 0.1),
                                    end: Offset(0, 0))
                              ],
                              child: _buildDeliveryInfo(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Order Summary Section (Third) - Price breakdown
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
              SafeArea(
                top: false,
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return _buildSlideToPay(cart);
                  },
                ),
              ),
            ],
          ),
          if (_isProcessingPayment)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Center(
                child: CircularProgressIndicator(color: Colors.green.shade600),
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
    return ApiConfig.getImageOrStorageUrl(url);
  }

  Widget _buildSlideToPay(CartProvider cart) {
    final double containerWidth =
        MediaQuery.of(context).size.width - 24; // Account for padding (12*2)
    final double handleSize = 44.0;
    final double maxSlideDistance =
        containerWidth - handleSize; // Account for handle width
    final double threshold = maxSlideDistance * 0.8; // 80% to trigger payment
    final bool isCompleted = _slidePosition >= threshold;
    final bool wasCompleted =
        _slidePosition >= threshold - 10; // For haptic feedback
    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (!_isProcessingPayment && cart.getSelectedItems().isNotEmpty) {
          setState(() {
            _isSliding = true;
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        if (!_isProcessingPayment && _isSliding && cart.cartItems.isNotEmpty) {
          final newPosition =
              (_slidePosition + details.delta.dx).clamp(0.0, maxSlideDistance);
          setState(() {
            _slidePosition = newPosition;
          });

          // Haptic feedback when reaching threshold
          if (newPosition >= threshold && !wasCompleted) {
            HapticFeedback.mediumImpact();
          }
        }
      },
      onHorizontalDragEnd: (_) {
        if (!_isProcessingPayment && cart.getSelectedItems().isNotEmpty) {
          if (_slidePosition >= threshold) {
            // Trigger payment
            HapticFeedback.heavyImpact();
            processPayment(cart);
          } else {
            // Reset position with animation
            setState(() {
              _slidePosition = 0.0;
              _isSliding = false;
            });
          }
        }
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.green.shade600,
            width: 2,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Progress track - green fill
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 100),
                curve: Curves.easeOut,
                width: _slidePosition,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    bottomLeft: Radius.circular(25),
                  ),
                ),
              ),
            ),
            // Text on the right side
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessingPayment) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.green.shade600,
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Processing Payment...',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 8),
                      Text(
                        isCompleted ? 'Release to Pay' : 'Swipe right to pay',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Sliding handle on the left
            AnimatedPositioned(
              duration: Duration(milliseconds: 100),
              curve: Curves.easeOut,
              left: _slidePosition.clamp(0.0, maxSlideDistance),
              top: 0,
              bottom: 0,
              child: Container(
                width: handleSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessingPayment
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.green.shade600,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.arrow_forward,
                          color: isCompleted
                              ? Colors.green.shade600
                              : Colors.grey.shade700,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(CartProvider cart) {
    // Get only selected items
    final selectedItems = cart.getSelectedItems();

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

            // Order Items (only selected items)
            if (selectedItems.isNotEmpty) ...[
              Text(
                'Items in your order (${selectedItems.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...selectedItems
                  .take(_showAllItems ? selectedItems.length : 3)
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
                                child: CachedNetworkImage(
                                  imageUrl: getImageUrl(item.image),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.grey[400]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
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
              if (selectedItems.length > 3 && !_showAllItems) ...[
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
                          'Show ${selectedItems.length - 3} more items',
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
              if (selectedItems.length > 3 && _showAllItems) ...[
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
    final deliveryFee = widget.deliveryFee ?? 0.00;
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
                  'BILL',
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

  /// Build delivery information box
  Widget _buildDeliveryInfo() {
    // Force the delivery info to show even if data is missing (for debugging)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade100.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.green[700],
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'DELIVERY INFORMATION',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Delivery Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address
                  if (widget.deliveryAddress != null &&
                      widget.deliveryAddress!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.home_outlined,
                          color: Colors.green[700],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        widget.deliveryAddress!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Contact Number
                  if (widget.contactNumber != null &&
                      widget.contactNumber!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: Colors.green[700],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contact',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        widget.contactNumber!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Delivery Time
                  if (widget.estimatedDeliveryTime != null &&
                      widget.estimatedDeliveryTime!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.green[700],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimated Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        widget.estimatedDeliveryTime!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
      // Check if user is logged in or guest
      final isLoggedIn = await AuthService.isLoggedIn();
      final token = await AuthService.getToken();

      // Prepare headers
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Prepare request body
      final requestBody = <String, dynamic>{
        'coupon': promoCode,
      };

      // Add authentication headers and guest_id if needed
      if (isLoggedIn && token != null && token.isNotEmpty) {
        // Logged-in user: only send coupon code
        headers['Authorization'] = 'Bearer $token';
        debugPrint('[DEBUG] Applying coupon as logged-in user');
      } else if (!isLoggedIn && token != null && token.isNotEmpty) {
        // Guest user: send coupon code and guest_id
        final guestId = token;
        headers['Authorization'] = 'Guest $guestId';
        headers['X-Guest-ID'] = guestId;
        requestBody['guest_id'] = guestId;
        debugPrint(
            '[DEBUG] Applying coupon as guest user: guest_id = $guestId');
      } else {
        setState(() {
          _promoError =
              'You must be logged in or have a guest session to apply a coupon.';
        });
        return;
      }

      // Make API call
      debugPrint(
          '[DEBUG] Apply Coupon API Request: ${jsonEncode(requestBody)}');
      debugPrint('[DEBUG] Apply Coupon API Headers: $headers');

      final response = await http
          .post(
            Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.applyCoupon)),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '[DEBUG] Apply Coupon API Response: Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Check if the response indicates success
        if (data['success'] == true || data['status'] == 'success') {
          // Extract discount information from response
          // The API returns totalDiscount which should be subtracted from the total
          final discountAmount = (data['totalDiscount'] ?? 0.0).toDouble();

          debugPrint('Promo code applied: $promoCode');
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
          // API returned error message
          final errorMessage = data['message'] ??
              data['error'] ??
              'Invalid promo code. Please try again.';
          setState(() {
            _promoError = errorMessage;
          });
        }
      } else {
        // Handle non-200 status codes
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Failed to apply promo code. Please try again.';
          setState(() {
            _promoError = errorMessage;
          });
        } catch (e) {
          setState(() {
            _promoError = 'Failed to apply promo code. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('[DEBUG] Exception during apply coupon API call: $e');
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
    final displayMessage =
        error.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final message = displayMessage.isNotEmpty &&
            displayMessage != 'Payment Failed, try again'
        ? displayMessage
        : 'Something went wrong. Please check your details and try again.';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with soft gradient background
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFEF5350).withValues(alpha: 0.15),
                        const Color(0xFFE53935).withValues(alpha: 0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.credit_card_off_rounded,
                    size: 36,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Payment didn’t go through',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Primary button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
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
  final String? estimatedDeliveryTime;

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
    this.estimatedDeliveryTime,
  });

  @override
  OrderConfirmationPageState createState() => OrderConfirmationPageState();
}

class OrderConfirmationPageState extends State<OrderConfirmationPage> {
  String? _status;
  String? _statusMessage;
  String? _transactionId;
  bool _isLoading = true;
  bool _paymentSuccess = false;
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
    // For online payments, show loading and check status
    _status = "pending";
    _statusMessage = "Please wait while we process your payment...";
    _isLoading = true;

    // Start periodic status checking
    _startStatusChecking();
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
    return ApiConfig.getImageOrStorageUrl(url);
  }

  /// Store delivery fee for this order so it can be retrieved later
  Future<void> _storeDeliveryFeeForOrder() async {
    try {
      if (_transactionId == null || _transactionId!.isEmpty) {
        debugPrint('🔍 Cannot store delivery fee: transaction_id is null');
        return;
      }

      // Calculate delivery fee from paymentParams (same as in build method)
      final subtotal = widget.purchasedItems
          .fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
      final totalAmountStr = widget.paymentParams['amount']?.toString() ?? '';
      final total = totalAmountStr.isNotEmpty
          ? (double.tryParse(totalAmountStr) ?? 0.0)
          : subtotal;
      final deliveryFeeStr = widget.paymentParams['delivery_fee']?.toString() ??
          widget.paymentParams['deliveryFee']?.toString();
      final deliveryFee = deliveryFeeStr != null && deliveryFeeStr.isNotEmpty
          ? (double.tryParse(deliveryFeeStr) ?? 0.0)
          : (total > subtotal ? (total - subtotal) : 0.0)
              .clamp(0.0, double.infinity);

      if (deliveryFee > 0) {
        final prefs = await SharedPreferences.getInstance();

        // Get the original transaction ID (ORDER_ prefix) from initialTransactionId
        final originalTransactionId = widget.initialTransactionId;

        // Store with the current transaction_id (which should be ECL format after payment response)
        final key = 'order_delivery_fee_$_transactionId';
        await prefs.setDouble(key, deliveryFee);
        debugPrint(
            '🔍 Stored delivery fee for order $_transactionId: $deliveryFee');

        // Also store total amount for reference
        final totalKey = 'order_total_$_transactionId';
        await prefs.setDouble(totalKey, total);
        debugPrint('🔍 Stored total amount for order $_transactionId: $total');

        // Also store with the original ORDER_ prefix if it's different (for backward compatibility)
        if (originalTransactionId != null &&
            originalTransactionId.isNotEmpty &&
            originalTransactionId != _transactionId &&
            originalTransactionId.startsWith('ORDER_')) {
          final originalKey = 'order_delivery_fee_$originalTransactionId';
          await prefs.setDouble(originalKey, deliveryFee);
          debugPrint(
              '🔍 Also stored delivery fee with original ORDER_ prefix $originalTransactionId: $deliveryFee');

          final originalTotalKey = 'order_total_$originalTransactionId';
          await prefs.setDouble(originalTotalKey, total);
          debugPrint(
              '🔍 Also stored total with original ORDER_ prefix $originalTransactionId: $total');
        }
      }
    } catch (e) {
      debugPrint('🔍 Error storing delivery fee: $e');
    }
  }

  /// Create notification for successful payment verification
  Future<void> _createPaymentSuccessNotification() async {
    try {
      // Check if user is logged in (not a guest)
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('📱 Skipping notification for guest user payment');
        return;
      }

      final orderId = widget.initialTransactionId ?? '';
      final totalAmount = widget.paymentParams['amount']?.toString() ?? '0';

      // Create order data for notification
      final orderData = {
        'id': orderId,
        'transaction_id': orderId,
        'order_number': orderId,
        'total_amount': totalAmount,
        'status': 'Payment Verified',
        'payment_method': widget.paymentMethod,
        'items': widget.purchasedItems
            .map((item) => {
                  'name': item.name,
                  'price': item.price,
                  'quantity': item.quantity,
                  'imageUrl': item.image,
                  'batchNo': item.batchNo,
                })
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Create notification only after payment is verified as successful
      await OrderNotificationService.createOrderPlacedNotification(orderData);

      debugPrint(
          '📱 Payment verified notification created for order #$orderId');
    } catch (e) {
      debugPrint('Error creating payment success notification: $e');
    }
  }

  void _startStatusChecking() {
    // Check status immediately
    _checkPaymentStatus().catchError((e) {
      debugPrint('Error in initial payment status check: $e');
    });

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
        final newStatus = result['status'];
        final currentStatus = _status?.toLowerCase();

        // Always update status if we get a new status from server
        // Only keep failed status if server returns pending/error/null
        String? updatedStatus = _status;
        String? updatedMessage = _statusMessage;

        if (currentStatus == 'failed' &&
            (newStatus == 'pending' ||
                newStatus == 'error' ||
                newStatus == null)) {
          // Keep the failed status, don't update
          updatedMessage = result['message'] ?? _statusMessage;
        } else {
          // Update status normally - this includes updating from failed to success
          updatedStatus = newStatus;
          updatedMessage = result['message'];
        }

        setState(() {
          debugPrint(
              '[DEBUG] setState in _checkPaymentStatus: updating status to ${updatedStatus?.toString() ?? 'null'}');
          _status = updatedStatus;
          _statusMessage = updatedMessage;
          _paymentSuccess = _status?.toLowerCase() == 'success';
          _isLoading = false;
        });

        // Handle different payment states (outside setState for async operations)
        if (updatedStatus?.toLowerCase() == 'success') {
          _statusCheckTimer?.cancel();
          _buttonShowTimer?.cancel();
          _emptyResponseTimer?.cancel();
          _showCheckStatusButton = false;
          // Reset empty response tracking
          _firstEmptyResponseTime = null;
          _emptyResponseCount = 0;

          // Update _transactionId with actual transaction_id from payment response if available
          // This ensures we use the ECL format ID that matches the API
          final actualTransactionId = result['transaction_id']?.toString();
          if (actualTransactionId != null && actualTransactionId.isNotEmpty) {
            final oldTransactionId = _transactionId;
            _transactionId = actualTransactionId;
            debugPrint(
                '[DEBUG] Updated _transactionId from payment response: $oldTransactionId -> $actualTransactionId');
          } else {
            debugPrint(
                '[DEBUG] No transaction_id in payment response, keeping: $_transactionId');
          }

          // Clear cart after successful payment verification
          final cartProvider =
              Provider.of<CartProvider>(context, listen: false);
          cartProvider.clearCart();

          // Store delivery fee for later retrieval (now using the correct transaction_id)
          debugPrint(
              '[DEBUG] About to store delivery fee with transaction_id: $_transactionId');
          await _storeDeliveryFeeForOrder();

          // Create notification only after payment is verified as successful
          _createPaymentSuccessNotification();
        } else if (updatedStatus?.toLowerCase() == 'failed') {
          _statusCheckTimer?.cancel(); // Stop automatic checks
          _buttonShowTimer?.cancel(); // Cancel the button show timer
          _emptyResponseTimer?.cancel();
          // Don't hide the check status button for failed payments
          // Reset empty response tracking
          _firstEmptyResponseTime = null;
          _emptyResponseCount = 0;
        }
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
    // Calculate subtotal from items
    final subtotal = widget.purchasedItems
        .fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

    // Use the actual amount from paymentParams (includes delivery fee and discount)
    // Fallback to calculating from items if amount is not available
    final totalAmountStr = widget.paymentParams['amount']?.toString() ?? '';
    final total = totalAmountStr.isNotEmpty
        ? (double.tryParse(totalAmountStr) ?? 0.0)
        : subtotal;

    // Get delivery fee from paymentParams or estimate from difference
    final deliveryFeeStr = widget.paymentParams['delivery_fee']?.toString() ??
        widget.paymentParams['deliveryFee']?.toString();
    final deliveryFee = deliveryFeeStr != null && deliveryFeeStr.isNotEmpty
        ? (double.tryParse(deliveryFeeStr) ?? 0.0)
        : (total > subtotal ? (total - subtotal) : 0.0)
            .clamp(0.0, double.infinity);

    // Get discount if any
    final discountStr = widget.paymentParams['discount']?.toString() ??
        widget.paymentParams['discount_amount']?.toString();
    final discount = discountStr != null && discountStr.isNotEmpty
        ? (double.tryParse(discountStr) ?? 0.0)
        : 0.0;

    final topPadding = MediaQuery.of(context).padding.top;

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
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            AppBackButton(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              onPressed: () {
                                // Navigate back to home page using a more direct approach
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.home,
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
                            vertical: 10, horizontal: 6),
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
                        if (_status?.toLowerCase() == 'success') {
                          _paymentSuccess = true;
                        }
                      });
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _buildOrderItemsList(),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 10,
                          bottom: 10 + MediaQuery.of(context).padding.bottom,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPaymentSummary(
                                subtotal, deliveryFee, discount, total),
                            const SizedBox(height: 6),
                            _buildBottomActions(deliveryFee, discount, total),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final statusColor = _getStatusColor(_status);
    final icon = _status?.toLowerCase() == 'success'
        ? Icons.check_circle_rounded
        : _status?.toLowerCase() == 'failed'
            ? Icons.error_rounded
            : Icons.pending_rounded;

    return Animate(
      effects: [
        FadeEffect(duration: 500.ms),
        ScaleEffect(begin: Offset(0.9, 0.9))
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 42,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getStatusLabel(_status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _getStatusMessage(_status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Check Status Button (only loop if needed)
          if (_showCheckStatusButton)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () {
                  _checkPaymentStatus();
                },
                icon: _isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Icon(Icons.refresh, size: 14),
                label: Text(_isLoading ? 'Checking...' : 'Check Status',
                    style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: statusColor,
                  side: BorderSide(color: statusColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: widget.purchasedItems.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined,
                    color: Colors.grey[700], size: 18),
                const SizedBox(width: 6),
                Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          );
        }

        final item = widget.purchasedItems[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      getImageUrl(item.image),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[100],
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey[400]),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${item.quantity}  •  GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentSummary(
      double subtotal, double deliveryFee, double discount, double total) {
    return Column(
      children: [
        _buildSummaryRow('Subtotal', subtotal),
        if (deliveryFee > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow('Delivery Fee', deliveryFee),
        ],
        if (discount > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow('Discount', -discount, isDiscount: true),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'GHS ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(widget.paymentMethod,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '${isDiscount ? '' : 'GHS '}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDiscount ? Colors.green[700] : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
      double deliveryFee, double discount, double total) {
    if (_status?.toLowerCase() == 'failed') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Home',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.cart,
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    if (_paymentSuccess) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final totalVal =
                    _status?.toLowerCase() == 'success' ? total : 0.0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingPage(
                      orderDetails: {
                        'id': _transactionId,
                        'order_id': _transactionId, // Ensure order_id is set
                        'transaction_id': _transactionId,
                        'status': _status,
                        'created_at': DateTime.now().toIso8601String(),
                        'estimated_delivery_time':
                            widget.estimatedDeliveryTime ??
                                'Location not specified',
                        'product_name': widget.purchasedItems.isNotEmpty
                            ? widget.purchasedItems.first.name
                            : 'Unknown Product',
                        'product_img': widget.purchasedItems.isNotEmpty
                            ? widget.purchasedItems.first.image
                            : '',
                        'qty': widget.purchasedItems
                            .fold(0, (sum, item) => sum + item.quantity),
                        'price': widget.purchasedItems.isNotEmpty
                            ? widget.purchasedItems.first.price
                            : 0,
                        'total_price': totalVal,
                        'delivery_fee': deliveryFee,
                        'deliveryFee': deliveryFee,
                        'discount': discount > 0 ? discount : null,
                        'discount_amount': discount > 0 ? discount : null,
                        'order_items': widget.purchasedItems
                            .map((item) => {
                                  'product_name': item.name,
                                  'product_img': item.image,
                                  'qty': item.quantity,
                                  'price': item.price,
                                  'batch_no': item.batchNo,
                                })
                            .toList(),
                        'is_multi_item': widget.purchasedItems.length > 1,
                        'item_count': widget.purchasedItems.length,
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 2,
                shadowColor: Colors.green.withValues(alpha: 0.4),
              ),
              child: const Text('Track Order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return Colors.blue;
    } else if (status?.toLowerCase() == 'success') {
      return Colors.green;
    } else if (status?.toLowerCase() == 'failed') {
      return Colors.red;
    }
    return Colors.orange;
  }

  String _getStatusLabel(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return 'Processing Payment';
    } else if (status?.toLowerCase() == 'success') {
      return 'Order Successfully Placed';
    } else if (status?.toLowerCase() == 'failed') {
      return 'Payment Failed';
    }
    return 'Payment Pending';
  }

  String _getStatusMessage(String? status) {
    if (status?.toLowerCase() == 'loading') {
      return 'Please wait while we process your payment...';
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

      if (isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
        // Logged-in user: ONLY use Bearer token, never guest_id
        authHeader = 'Bearer $tokenRaw';
        if (userId == null) {
          debugPrint('[DEBUG] Early return: userId is null');
          return {'status': 'error', 'message': ''};
        }
        requestBody = {'user_id': userId};
        debugPrint('[DEBUG] Using logged-in user flow');
      } else if (!isLoggedIn && tokenRaw != null && tokenRaw.isNotEmpty) {
        // Guest user: token is guest_id from getToken()
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
      if (!isLoggedIn) {
        headers['X-Guest-ID'] = tokenRaw;
      }
      debugPrint('[DEBUG] Payment Status Check - Request Headers: $headers');
      debugPrint(
          '[DEBUG] Payment Status Check - Request Body: ${jsonEncode(requestBody)}');

      debugPrint('[DEBUG] Making HTTP request to check-payment endpoint...');
      final response = await http
          .post(
        Uri.parse(
            ApiConfig.getEndpointUrl(ApiConfig.checkPayment)),
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
            Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkPayment)),
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
  WebViewPageState createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
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
