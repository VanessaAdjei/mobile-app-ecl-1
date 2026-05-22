// pages/payment_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/cart_provider.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../models/cart_item.dart';
import '../config/api_config.dart';
import '../utils/payment_redirect_url.dart';
import '../widgets/payment/payment_bill_summary_section.dart';
import '../widgets/payment/payment_delivery_details_card.dart';
import '../widgets/payment/payment_order_items_section.dart';

export 'order_confirmation_page.dart';

/// Shown in the UI when online payment fails; technical details are only logged.
const String kUserFacingPaymentFailureMessage =
    'Payment did not go through. No charge was made—please try again.';

class PaymentPage extends StatefulWidget {
  final String? deliveryAddress;
  final String? contactNumber;
  final String deliveryOption;
  final String? guestEmail;
  final double? lat;
  final double? lng;
  final String? estimatedDeliveryTime;
  final double? distanceKm;
  final double deliveryFee;
  final bool isOrderUrgent;
  final double? emergencyOrderFee;

  const PaymentPage({
    Key? key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.guestEmail,
    this.lat,
    this.lng,
    this.estimatedDeliveryTime,
    this.distanceKm,
    this.deliveryFee = 0,
    this.isOrderUrgent = false,
    this.emergencyOrderFee,
  }) : super(key: key);

  bool get _isDelivery =>
      deliveryOption.toLowerCase().trim() == 'delivery';

  double get _effectiveDeliveryFee => _isDelivery ? deliveryFee : 0.0;

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
      _paymentError = kUserFacingPaymentFailureMessage;
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
        debugPrint('[CHECK PAYMENT API RESPONSE] ${response.body}');
        print('[CHECK PAYMENT API RESPONSE] ${response.body}');
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

      final emergencyOrderFee = widget.emergencyOrderFee ?? 0.00;
      final total = subtotal +
          widget._effectiveDeliveryFee +
          emergencyOrderFee -
          _discountAmount;

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
        'amount':
            double.parse(total.toStringAsFixed(2)), // Send as float, not string
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
        'redirect_url': ApiConfig.paymentRedirectUrl,
        'shipping_type': widget.deliveryOption,
        'order_urgent': widget.isOrderUrgent,
        if (widget.lat != null) 'lat': widget.lat,
        if (widget.lng != null) 'lng': widget.lng,
        if (widget.lat != null) 'latitude': widget.lat,
        if (widget.lng != null) 'longitude': widget.lng,
        'delivery_fee': widget._effectiveDeliveryFee,
        'deliveryFee': widget._effectiveDeliveryFee,
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
        // Convert params to form-encoded body (backend expects form data, not JSON)
        final formBody = params.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');

        final formHeaders = <String, String>{
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        };

        response = await http.post(
          Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.expressPayment)),
          headers: formHeaders,
          body: formBody,
        );
        debugPrint(
            '[DEBUG] Online Payment API Response: Status: ${response.statusCode}, Body: ${response.body}');

        // Log full API response for express payment
        debugPrint('✅ [EXPRESS PAYMENT API] RESPONSE RECEIVED:');
        debugPrint('📊 Status Code: ${response.statusCode}');
        debugPrint('📋 Full Response Body: ${response.body}');
        debugPrint('📋 Response Headers: ${response.headers}');
        debugPrint('🔍 Request Params: ${jsonEncode(params)}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } catch (e) {
        debugPrint('[DEBUG] Exception during expresspay API call: $e');
        rethrow;
      }
      debugPrint('[DEBUG] Finished expresspay API call');

      // Status code gate intentionally disabled as requested.
      // if (response.statusCode == 200) {
      // API may return a bare URL, quoted string, or JSON { "redirect_url": "..." }.
      final redirectUrl = parsePaymentRedirectUrl(response.body);
      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception(
          'Could not read a payment page URL from the server. '
          'Please try again or contact support if this continues.',
        );
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
            deliveryFee: widget._effectiveDeliveryFee,
            discount: _discountAmount,
            onPaymentComplete: (success, token) async {
              if (success && token != null) {
                try {
                  final result =
                      await _verifyPayment(token, transactionId.toString());
                  debugPrint('[CHECK PAYMENT API RESULT] $result');
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
                  debugPrint('[CHECK PAYMENT API ERROR] $e');
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
      // } else if (response.statusCode == 401) {
      //   throw Exception('Payment Failed, try again');
      // } else if (response.statusCode == 403) {
      //   throw Exception('Payment Failed, try again');
      // } else if (response.statusCode == 404) {
      //   throw Exception('Payment Failed, try again');
      // } else if (response.statusCode >= 500) {
      //   throw Exception('Payment Failed, try again');
      // } else {
      //   throw Exception('Payment Failed, try again');
      // }
    } catch (e, st) {
      debugPrint('[Payment] Online payment failed: $e\n$st');
      if (mounted) {
        setState(() {
          _paymentError = kUserFacingPaymentFailureMessage;
        });
        _showPaymentFailureDialog(e, st);
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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
                              Icon(Icons.emergency_rounded,
                                  size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Urgent Order',
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
                            child: PaymentOrderItemsSection(
                              selectedItems: cart.getSelectedItems(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Delivery Information Section (Second) - if delivery
                          if (widget._isDelivery) ...[
                            Animate(
                              effects: [
                                FadeEffect(duration: 400.ms),
                                SlideEffect(
                                    duration: 400.ms,
                                    begin: Offset(0, 0.1),
                                    end: Offset(0, 0))
                              ],
                              child: PaymentDeliveryDetailsCard(
                                deliveryAddress: widget.deliveryAddress,
                                contactNumber: widget.contactNumber,
                              ),
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
                            child: PaymentBillSummarySection(
                              subtotal: cart.calculateSubtotal(),
                              deliveryFee: widget._effectiveDeliveryFee,
                              showDeliveryFee: widget._isDelivery,
                              emergencyOrderFee:
                                  widget.emergencyOrderFee ?? 0.0,
                              discountAmount: _discountAmount,
                              appliedPromoCode: _appliedPromoCode,
                              promoError: _promoError,
                              isApplyingPromo: _isApplyingPromo,
                              promoCodeController: _promoCodeController,
                              onApplyPromo: _applyPromoCode,
                              onRemovePromo: _removePromoCode,
                            ),
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
                                            _paymentError!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade600,
                                              height: 1.25,
                                            ),
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
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

  void _showPaymentFailureDialog(Object error, [StackTrace? stackTrace]) {
    debugPrint('[Payment] Failure dialog (details above): $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }

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
                  kUserFacingPaymentFailureMessage,
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

