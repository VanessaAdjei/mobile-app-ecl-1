// pages/payment_page.dart
import 'dart:async';
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/checkout_payment_service.dart';
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
import '../widgets/checkout_progress_stepper.dart';
import '../config/app_colors.dart';

// Post-checkout uses PostCheckoutOrderPage (see paymentwebview.dart).

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
  final double? apiSubtotal;
  final double? apiDiscountAmount;
  final bool? apiShippingFree;

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
    this.apiSubtotal,
    this.apiDiscountAmount,
    this.apiShippingFree,
  }) : super(key: key);

  bool get _isDelivery => deliveryOption.toLowerCase().trim() == 'delivery';

  double get _effectiveDeliveryFee => _isDelivery ? deliveryFee : 0.0;

  @override
  PaymentPageState createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage> {
  final CheckoutPaymentService _checkoutPaymentService =
      CheckoutPaymentService();
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

  double get _effectiveSubtotalFromApiOrCart {
    final apiSubtotal = widget.apiSubtotal;
    if (apiSubtotal != null && apiSubtotal >= 0) return apiSubtotal;
    final cart = Provider.of<CartProvider>(context, listen: false);
    return cart.calculateSubtotal();
  }

  double get _effectiveDiscountFromApiOrPromo {
    final apiDiscount = widget.apiDiscountAmount;
    if (apiDiscount != null && apiDiscount >= 0) return apiDiscount;
    return _discountAmount;
  }

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
    debugPrint('[DEBUG] Using token for payment verification: $token');
    return _checkoutPaymentService.verifyPayment();
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

      final subtotal = _effectiveSubtotalFromApiOrCart;
      if (subtotal <= 0) {
        throw Exception(
            'Invalid order amount. Please check your selected items.');
      }

      final headers = await buildCheckoutAuthHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception(
          'You must be logged in or have a guest session to use online payment. Please log in.',
        );
      }
      final isGuest = headers['Authorization']!.startsWith('Guest ');

      if (!isGuest &&
          (_userEmail.isEmpty || _userEmail == "No email available")) {
        throw Exception(
            'Please update your email address in your profile before making a payment.');
      }

      if (widget.contactNumber?.isEmpty ?? true) {
        throw Exception('Please provide a valid contact number for delivery.');
      }

      final emergencyOrderFee = widget.emergencyOrderFee ?? 0.00;
      final deliveryFeeCharged = widget._isDelivery
          ? (widget.apiShippingFree == true ? 0.0 : widget._effectiveDeliveryFee)
          : 0.0;
      final effectiveDiscount = _effectiveDiscountFromApiOrPromo;
      final total =
          subtotal + deliveryFeeCharged + emergencyOrderFee - effectiveDiscount;

      String orderDesc = selectedItems
          .map((item) => '${item.quantity}x ${item.name}')
          .join(', ');
      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

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
        'amount': double.parse(total.toStringAsFixed(2)),
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
        'delivery_fee': deliveryFeeCharged,
        'deliveryFee': deliveryFeeCharged,
        if (widget.apiSubtotal != null) 'subtotal': widget.apiSubtotal,
        if (widget.apiDiscountAmount != null)
          'discount_amount': widget.apiDiscountAmount,
      };

      final purchasedItems = List<CartItem>.from(selectedItems);
      final transactionId = params['order_id'];

      if (!mounted) return;

      // Open the payment screen immediately; portal URL resolves in the background.
      setState(() => _isProcessingPayment = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            resolveRedirectUrl: () async {
              debugPrint('[DEBUG] About to call expresspay API');
              final responseBody = await _checkoutPaymentService
                  .submitExpressPayment(params: params);
              debugPrint(
                  '[DEBUG] Online Payment API Response Body: $responseBody');
              final redirectUrl = parsePaymentRedirectUrl(responseBody);
              if (redirectUrl == null || redirectUrl.isEmpty) {
                throw Exception(
                  'Could not read a payment page URL from the server. '
                  'Please try again or contact support if this continues.',
                );
              }
              return redirectUrl;
            },
            paymentParams: params,
            purchasedItems: purchasedItems,
            paymentMethod: selectedPaymentMethod,
            deliveryAddress: widget.deliveryAddress ?? '',
            contactNumber: widget.contactNumber ?? _phoneNumber,
            deliveryOption: widget.deliveryOption,
            estimatedDeliveryTime:
                widget.estimatedDeliveryTime ?? 'Calculating ETA',
            deliveryFee: deliveryFeeCharged,
            discount: effectiveDiscount,
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
      backgroundColor: const Color(0xFFF4FAF7),
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
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: const CheckoutProgressStepper(
                          compact: true,
                          steps: [
                            'Cart',
                            'Delivery',
                            'Payment',
                            'Confirmation',
                          ],
                          activeStep: 3,
                          completedSteps: {1, 2},
                        ),
                      ),
                      if (widget.isOrderUrgent) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emergency_rounded,
                                  size: 15, color: Colors.red.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Urgent Order',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade800,
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(height: 6),
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
                            const SizedBox(height: 6),
                          ],
                          Animate(
                            effects: [
                              FadeEffect(duration: 400.ms),
                              SlideEffect(
                                  duration: 400.ms,
                                  begin: Offset(0, 0.1),
                                  end: Offset(0, 0))
                            ],
                            child: PaymentBillSummarySection(
                              subtotal: _effectiveSubtotalFromApiOrCart,
                              deliveryFee: widget._effectiveDeliveryFee,
                              showDeliveryFee: widget._isDelivery,
                              emergencyOrderFee:
                                  widget.emergencyOrderFee ?? 0.0,
                              discountAmount: _effectiveDiscountFromApiOrPromo,
                              useRawDeliveryFee: true,
                              forceFreeDelivery: widget.apiShippingFree == true,
                              lockPromoEditing: false,
                              appliedPromoCode: _appliedPromoCode,
                              promoError: _promoError,
                              isApplyingPromo: _isApplyingPromo,
                              promoCodeController: _promoCodeController,
                              onApplyPromo: _applyPromoCode,
                              onRemovePromo: _removePromoCode,
                            ),
                          ),
                          if (_paymentError != null) ...[
                            const SizedBox(height: 6),
                            Animate(
                              effects: [
                                FadeEffect(duration: 400.ms),
                                SlideEffect(
                                    duration: 400.ms,
                                    begin: Offset(0, 0.1),
                                    end: Offset(0, 0))
                              ],
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 18,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Payment error',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _paymentError!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red.shade600,
                                              height: 1.3,
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
                          const SizedBox(height: 96),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Fixed Payment Methods and Button at Bottom
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Consumer<CartProvider>(
                    builder: (context, cart, child) {
                      return _buildSlideToPay(cart);
                    },
                  ),
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

  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  Widget _buildSlideToPay(CartProvider cart) {
    final double containerWidth = MediaQuery.of(context).size.width - 28;
    final double handleSize = 38.0;
    final double maxSlideDistance = containerWidth - handleSize;
    final double threshold = maxSlideDistance * 0.8;
    final bool isCompleted = _slidePosition >= threshold;
    final bool wasCompleted = _slidePosition >= threshold - 10;
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
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary,
            width: 1.5,
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
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                  ),
                ),
              ),
            ),
            // Text on the right side
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessingPayment) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing payment…',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCompleted ? 'Release to pay' : 'Swipe right to pay',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessingPayment
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.arrow_forward,
                          color: isCompleted
                              ? AppColors.primary
                              : Colors.grey.shade700,
                          size: 20,
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
      debugPrint('[DEBUG] Apply Coupon API Request: $promoCode');

      final result = await _checkoutPaymentService.applyCoupon(
        promoCode: promoCode,
      );
      final statusCode = result['statusCode'] as int? ?? 0;
      final data = Map<String, dynamic>.from(
        (result['body'] as Map?) ?? const {},
      );

      debugPrint(
          '[DEBUG] Apply Coupon API Response: Status: $statusCode, Body: $data');

      if (statusCode == 200 || statusCode == 201) {
        if (data['success'] == true || data['status'] == 'success') {
          final discountAmount = (data['totalDiscount'] ?? 0.0).toDouble();

          debugPrint('Promo code applied: $promoCode');
          debugPrint('Discount amount: $discountAmount');

          setState(() {
            _appliedPromoCode = promoCode;
            _discountAmount = discountAmount;
            _promoError = null;
          });

          if (mounted) {
            setState(() {});
          }
        } else {
          final errorMessage = data['message'] ??
              data['error'] ??
              'Invalid promo code. Please try again.';
          setState(() {
            _promoError = errorMessage;
          });
        }
      } else {
        final errorMessage = data['message'] ??
            data['error'] ??
            'Failed to apply promo code. Please try again.';
        setState(() {
          _promoError = errorMessage;
        });
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
