// pages/payment_page.dart
import 'dart:async';
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/guest_checkout_draft.dart';
import '../services/checkout_payment_service.dart';
import '../services/auth_service.dart';
import '../services/guest_checkout_draft_service.dart';
import '../providers/cart_provider.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../config/api_config.dart';
import '../utils/checkout_order_totals.dart';
import '../utils/payment_redirect_url.dart';
import '../widgets/payment/payment_bill_summary_section.dart';
import '../widgets/payment/payment_delivery_details_card.dart';
import '../widgets/payment/payment_order_items_section.dart';
import '../widgets/payment/payment_slide_design.dart';
import '../widgets/checkout_progress_stepper.dart';
import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';

// Post-checkout uses PostCheckoutOrderPage (see paymentwebview.dart).

/// Shown in the UI when online payment fails; technical details are only logged.
const String kUserFacingPaymentFailureMessage =
    'Payment did not go through. No charge was made—please try again.';

class PaymentPage extends StatefulWidget {
  /// Locked bill from delivery (single source of truth). Promo edits on this
  /// screen override [CheckoutOrderTotals.discount] only.
  final CheckoutOrderTotals? orderTotals;
  final String? deliveryAddress;
  final String? contactNumber;
  final String deliveryOption;
  final String? guestEmail;
  final double? lat;
  final double? lng;
  final String? estimatedDeliveryTime;
  final double? distanceKm;
  final bool isOrderUrgent;

  const PaymentPage({
    Key? key,
    this.orderTotals,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.guestEmail,
    this.lat,
    this.lng,
    this.estimatedDeliveryTime,
    this.distanceKm,
    this.isOrderUrgent = false,
  }) : super(key: key);

  bool get _isDelivery => deliveryOption.toLowerCase().trim() == 'delivery';

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

  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  double get _effectiveSubtotalFromApiOrCart {
    final fromTotals = widget.orderTotals?.merchandiseSubtotal;
    if (fromTotals != null && fromTotals >= 0) return fromTotals;
    final cart = Provider.of<CartProvider>(context, listen: false);
    return cart.calculateSubtotal();
  }

  double get _effectiveDiscountFromApiOrPromo {
    if (_discountAmount > 0) return _discountAmount;
    return widget.orderTotals?.discount ?? 0.0;
  }

  CheckoutOrderTotals get _checkoutTotals {
    final base = widget.orderTotals;
    if (base != null) {
      return CheckoutOrderTotals(
        merchandiseSubtotal: base.merchandiseSubtotal > 0
            ? base.merchandiseSubtotal
            : _effectiveSubtotalFromApiOrCart,
        discount: _effectiveDiscountFromApiOrPromo,
        deliveryFee: base.deliveryFee,
        emergencyOrderFee: base.emergencyOrderFee,
        runningSubtotal: base.runningSubtotal,
        shippingFree: base.shippingFree,
        isDelivery: widget._isDelivery,
      );
    }
    final cart = Provider.of<CartProvider>(context, listen: false);
    return CheckoutOrderTotals(
      merchandiseSubtotal: cart.calculateSubtotal(),
      discount: _discountAmount,
      deliveryFee: 0,
      emergencyOrderFee: 0,
      isDelivery: widget._isDelivery,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onPaymentScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserData();
      if (mounted) _updateScrollHint();
    });
  }

  @override
  void dispose() {
    unawaited(_persistGuestCheckoutDraft());
    _scrollController.removeListener(_onPaymentScroll);
    _scrollController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  bool _scrollHintUpdateScheduled = false;

  void _scheduleScrollHintUpdate() {
    if (_scrollHintUpdateScheduled || !mounted) return;
    _scrollHintUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHintUpdateScheduled = false;
      if (mounted) _updateScrollHint();
    });
  }

  void _onPaymentScroll() => _scheduleScrollHintUpdate();

  void _updateScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final hasScrollableContent = position.maxScrollExtent > 1.0;
    final hasMoreBelow = position.pixels < position.maxScrollExtent - 12;
    final showHint = hasScrollableContent && hasMoreBelow;

    if (showHint != _showScrollHint) {
      setState(() => _showScrollHint = showHint);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        final draft = await GuestCheckoutDraftService.load();
        if (draft != null && mounted) {
          setState(() {
            _userName =
                draft.name.trim().isNotEmpty ? draft.name.trim() : 'Guest';
            _userEmail = draft.email.trim().isNotEmpty
                ? draft.email.trim()
                : (widget.guestEmail?.trim().isNotEmpty == true
                    ? widget.guestEmail!.trim()
                    : 'No email available');
            _phoneNumber = draft.phone.trim().isNotEmpty
                ? draft.phone.trim()
                : (widget.contactNumber?.trim() ?? '');
            final promo = draft.promoCode?.trim();
            if (promo != null && promo.isNotEmpty) {
              _appliedPromoCode = promo;
              _discountAmount = draft.discountAmount;
              _promoCodeController.text = promo;
            }
          });
          return;
        }
        if (mounted &&
            widget.guestEmail != null &&
            widget.guestEmail!.trim().isNotEmpty) {
          setState(() {
            _userEmail = widget.guestEmail!.trim();
            _phoneNumber = widget.contactNumber?.trim() ?? '';
          });
          return;
        }
      }

      final userData = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          _userName = userData?['name'] ?? 'User';
          _userEmail = userData?['email'] ?? 'No email available';
          _phoneNumber = userData?['phone'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userEmail = widget.guestEmail?.trim().isNotEmpty == true
              ? widget.guestEmail!.trim()
              : 'No email available';
          _phoneNumber = widget.contactNumber?.trim() ?? '';
        });
      }
    }
  }

  Future<void> _persistGuestCheckoutDraft() async {
    if (!mounted) return;
    if (await AuthService.isLoggedIn()) return;

    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_id');
    if (guestId == null || guestId.isEmpty) return;

    final existing = await GuestCheckoutDraftService.load();
    final draft = GuestCheckoutDraft(
      guestId: guestId,
      name:
          existing?.name.isNotEmpty == true ? existing!.name : _userName.trim(),
      email: _userEmail.trim().isNotEmpty && _userEmail != 'No email available'
          ? _userEmail.trim()
          : (existing?.email ?? widget.guestEmail ?? ''),
      phone: _phoneNumber.trim().isNotEmpty
          ? _phoneNumber.trim()
          : (existing?.phone ?? widget.contactNumber ?? ''),
      deliveryOption: widget.deliveryOption.toLowerCase(),
      region: existing?.region ?? '',
      city: existing?.city ?? '',
      address: existing?.address ?? '',
      notes: existing?.notes ?? '',
      pickupRegionLabel: existing?.pickupRegionLabel ?? '',
      pickupCityLabel: existing?.pickupCityLabel ?? '',
      pickupSiteLabel: existing?.pickupSiteLabel ?? '',
      lat: widget.lat ?? existing?.lat,
      lng: widget.lng ?? existing?.lng,
      deliveryFee: widget.orderTotals?.chargedDeliveryFee ?? 0,
      isOrderUrgent: widget.isOrderUrgent,
      emergencyOrderFee: widget.orderTotals?.emergencyOrderFee,
      estimatedDeliveryTime:
          widget.estimatedDeliveryTime ?? existing?.estimatedDeliveryTime,
      distanceKm: widget.distanceKm ?? existing?.distanceKm,
      apiSubtotal: widget.orderTotals?.merchandiseSubtotal ??
          _effectiveSubtotalFromApiOrCart,
      apiDiscountAmount: _effectiveDiscountFromApiOrPromo > 0
          ? _effectiveDiscountFromApiOrPromo
          : null,
      apiShippingFree: widget.orderTotals?.shippingFree,
      promoCode: _appliedPromoCode,
      discountAmount: _effectiveDiscountFromApiOrPromo,
    );

    await GuestCheckoutDraftService.save(draft);
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

      final totals = _checkoutTotals;
      final payableAmount = totals.payableAmount;

      if (widget._isDelivery &&
          !totals.shippingFree &&
          totals.deliveryFee > 0 &&
          totals.chargedDeliveryFee <= 0) {
        debugPrint(
          '[PAYMENT] ⚠️ Delivery fee lost in totals — raw=${totals.deliveryFee}, '
          'isDelivery=${totals.isDelivery}, shippingFree=${totals.shippingFree}',
        );
      }

      debugPrint(
        '[PAYMENT] Bill breakdown — merchandise=${totals.merchandiseSubtotal}, '
        'discount=${totals.discount}, delivery=${totals.chargedDeliveryFee}, '
        'xpress=${totals.emergencyOrderFee}; ExpressPay amount=$payableAmount',
      );

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

      final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
      final accountNumber = widget.contactNumber ?? _phoneNumber;

      debugPrint(
        '[PAYMENT] ExpressPay submit only (no save-billing) — '
        'amount=$payableAmount',
      );

      // ExpressPay API — only these fields are sent to /api/expresspayment.
      final expressPayParams = <String, dynamic>{
        'request': 'submit',
        'order_id': orderId,
        'currency': 'GHS',
        'amount': payableAmount,
        'order_desc': orderDesc,
        'first_name': firstName,
        'last_name': lastName,
        'email': _userEmail,
        'redirect_url': ApiConfig.paymentRedirectUrl,
        'account_number': accountNumber,
      };

      // Local order metadata (WebView / post-checkout — not sent to ExpressPay).
      final paymentParams = <String, dynamic>{
        ...expressPayParams,
        'delivery_fee': totals.chargedDeliveryFee,
        'deliveryFee': totals.chargedDeliveryFee,
        'discount_amount': totals.discount,
        'phone_number': accountNumber,
        'address': widget.deliveryAddress ?? '',
        'shipping_type': widget.deliveryOption,
        'order_urgent': widget.isOrderUrgent,
        if (widget.lat != null) 'lat': widget.lat,
        if (widget.lng != null) 'lng': widget.lng,
      };

      final purchasedItems = List<CartItem>.from(selectedItems);
      final transactionId = orderId;

      if (!mounted) return;

      // Open the payment screen immediately; portal URL resolves in the background.
      setState(() => _isProcessingPayment = false);

      unawaited(_persistGuestCheckoutDraft());

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            resolveRedirectUrl: () async {
              final responseBody = await _checkoutPaymentService
                  .submitExpressPayment(params: expressPayParams);
              final redirectUrl = parsePaymentRedirectUrl(responseBody);
              if (redirectUrl == null || redirectUrl.isEmpty) {
                throw Exception(
                  'Could not read a payment page URL from the server. '
                  'Please try again or contact support if this continues.',
                );
              }
              return redirectUrl;
            },
            expectedPayableAmount: totals.total,
            merchandiseSubtotal: totals.merchandiseSubtotal,
            paymentParams: paymentParams,
            purchasedItems: purchasedItems,
            paymentMethod: selectedPaymentMethod,
            deliveryAddress: widget.deliveryAddress ?? '',
            contactNumber: widget.contactNumber ?? _phoneNumber,
            deliveryOption: widget.deliveryOption,
            estimatedDeliveryTime:
                widget.estimatedDeliveryTime ?? 'Calculating ETA',
            deliveryFee: totals.chargedDeliveryFee,
            discount: totals.discount,
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
    final theme = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    // Persistent inset for home indicator / gesture bar (stable when keyboard opens).
    final systemBottomInset = mediaQuery.viewPadding.bottom;
    const bottomLift = 10.0;
    const payBarTopPadding = 10.0;
    const slideHeight = 56.0;
    final payBarBottomPadding = bottomLift + systemBottomInset;
    final payBarInset = payBarTopPadding + slideHeight + payBarBottomPadding;

    return Scaffold(
      backgroundColor: theme.pageBg,
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
                        AppThemeColors.headerBackground,
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                      stops: const [0.0, 0.5, 1.0],
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
                                  size: 15,
                                  color: theme.isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Urgent Order',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.isDark
                                      ? Colors.red.shade200
                                      : Colors.red.shade800,
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        _scheduleScrollHintUpdate();
                        final totals = _checkoutTotals;
                        return SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            0,
                            12,
                            0,
                            payBarInset + 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(height: 8),
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
                              Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: PaymentBillSummarySection(
                                  subtotal: totals.merchandiseSubtotal,
                                  deliveryFee: totals.deliveryFee,
                                  showDeliveryFee: totals.isDelivery,
                                  emergencyOrderFee: totals.emergencyOrderFee,
                                  discountAmount: totals.discount,
                                  runningSubtotal: totals.runningSubtotal,
                                  useRawDeliveryFee: true,
                                  forceFreeDelivery: totals.shippingFree,
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
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.isDark
                                          ? Colors.red.withValues(alpha: 0.14)
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.red.withValues(
                                          alpha: theme.isDark ? 0.45 : 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: theme.isDark
                                              ? Colors.red.shade300
                                              : Colors.red.shade600,
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
                                                  color: theme.isDark
                                                      ? Colors.red.shade300
                                                      : Colors.red.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _paymentError!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme.isDark
                                                      ? Colors.red.shade400
                                                      : Colors.red.shade600,
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
                            ],
                          ),
                        );
                      },
                    ),
                    if (_showScrollHint)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: payBarInset,
                        child: IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      theme.pageBg.withValues(alpha: 0),
                                      theme.pageBg,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                color: theme.pageBg,
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Scroll for more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.isDark
                                            ? Colors.white70
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          border: Border(
                            top: BorderSide(color: theme.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: theme.isDark ? 0.35 : 0.08,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          14,
                          payBarTopPadding,
                          14,
                          payBarBottomPadding,
                        ),
                        child: Consumer<CartProvider>(
                          builder: (context, cart, child) {
                            return _buildSlideToPay(cart);
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
              color: PaymentSlideDesign.processingOverlay(context),
              child: Center(
                child: CircularProgressIndicator(
                  color: PaymentSlideDesign.accent(context),
                ),
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
    final theme = context.appColors;
    final selectedItems = cart.getSelectedItems();
    final canPay = selectedItems.isNotEmpty && !_isProcessingPayment;
    final horizontalInset = 14.0 * 2;
    final double containerWidth =
        MediaQuery.sizeOf(context).width - horizontalInset;
    final double handleSize = 50.0;
    final double maxSlideDistance = containerWidth - handleSize;
    final double threshold = maxSlideDistance * 0.8;
    final bool isCompleted = _slidePosition >= threshold;
    final bool wasCompleted = _slidePosition >= threshold - 10;
    final bool labelOnProgress = _slidePosition > containerWidth * 0.42;
    return Opacity(
      opacity: canPay ? 1 : PaymentSlideDesign.disabledOpacity(context),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          if (canPay) {
            setState(() {
              _isSliding = true;
            });
          }
        },
        onHorizontalDragUpdate: (details) {
          if (canPay && _isSliding) {
            final newPosition = (_slidePosition + details.delta.dx)
                .clamp(0.0, maxSlideDistance);
            setState(() {
              _slidePosition = newPosition;
            });

            if (newPosition >= threshold && !wasCompleted) {
              HapticFeedback.mediumImpact();
            }
          }
        },
        onHorizontalDragEnd: (_) {
          if (canPay) {
            if (_slidePosition >= threshold) {
              HapticFeedback.heavyImpact();
              processPayment(cart);
            } else {
              setState(() {
                _slidePosition = 0.0;
                _isSliding = false;
              });
            }
          }
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: PaymentSlideDesign.trackBg(context),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: PaymentSlideDesign.trackBorder(context),
              width: PaymentSlideDesign.trackBorderWidth(context),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  width: _slidePosition,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: PaymentSlideDesign.progressColors(context),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      bottomLeft: Radius.circular(28),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessingPayment) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: PaymentSlideDesign.accent(context),
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Processing payment…',
                          style: TextStyle(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          canPay
                              ? Icons.lock_outline
                              : Icons.shopping_cart_outlined,
                          size: 16,
                          color: PaymentSlideDesign.labelIconColor(
                            context,
                            onProgress: labelOnProgress,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          !canPay && selectedItems.isEmpty
                              ? 'Select items to pay'
                              : isCompleted
                                  ? 'Release to pay'
                                  : 'Swipe right to pay',
                          style: TextStyle(
                            color: PaymentSlideDesign.labelColor(
                              context,
                              onProgress: labelOnProgress,
                            ),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                left: _slidePosition.clamp(0.0, maxSlideDistance),
                top: 0,
                bottom: 0,
                child: Container(
                  width: handleSize,
                  decoration: BoxDecoration(
                    color: PaymentSlideDesign.handleBg(context),
                    borderRadius: BorderRadius.circular(28),
                    border: PaymentSlideDesign.handleBorder(context),
                    boxShadow: PaymentSlideDesign.handleShadow(context),
                  ),
                  child: Center(
                    child: _isProcessingPayment
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: PaymentSlideDesign.accent(context),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isCompleted
                                ? Icons.check_circle
                                : Icons.arrow_forward,
                            color: isCompleted
                                ? PaymentSlideDesign.accent(context)
                                : theme.muted,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ],
          ),
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
          unawaited(_persistGuestCheckoutDraft());
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
    unawaited(_persistGuestCheckoutDraft());
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
      builder: (BuildContext dialogContext) {
        final dialogTheme = dialogContext.appColors;
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
              color: dialogTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: dialogTheme.border),
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
                Text(
                  'Payment didn’t go through',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dialogTheme.ink,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  kUserFacingPaymentFailureMessage,
                  style: TextStyle(
                    fontSize: 15,
                    color: dialogTheme.muted,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
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
