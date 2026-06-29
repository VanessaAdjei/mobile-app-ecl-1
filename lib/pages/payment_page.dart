// pages/payment_page.dart
import 'dart:async';
import 'package:eclapp/pages/paymentwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/guest_checkout_draft.dart';
import '../services/checkout_payment_service.dart';
import '../services/auth_service.dart';
import '../services/guest_checkout_draft_service.dart';
import '../services/delivery_service.dart';
import '../providers/cart_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../config/api_config.dart';
import '../utils/checkout_order_totals.dart';
import '../utils/checkout_log.dart';
import '../utils/express_pay_api_log.dart';
import '../utils/payment_redirect_url.dart';
import '../widgets/payment/payment_bill_summary_section.dart';
import '../widgets/payment/payment_delivery_details_card.dart';
import '../widgets/payment/payment_order_items_section.dart';
import '../widgets/payment/payment_slide_design.dart';
import '../widgets/checkout_flow_header.dart';
import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';
import 'package:google_fonts/google_fonts.dart';

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
  /// True when delivery page already ran save-billing + fee sync before navigate.
  final bool billingCartSynced;
  /// Authoritative distance_text from save-billing (e.g. "0.4 km").
  final String? feeDistanceText;
  /// Locked fee scalars from delivery (survive hot reload / draft gaps).
  final double? lockedDeliveryFee;
  final double? lockedXpressFee;
  /// Street / addr_1 from delivery page (logged-in users have no guest draft).
  final String? streetAddress;
  final String? deliveryCity;
  final String? deliveryRegion;
  final int? billingRegionId;
  final int? billingCityId;

  const PaymentPage({
    super.key,
    this.orderTotals,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.guestEmail,
    this.lat,
    this.lng,
    this.estimatedDeliveryTime,
    this.distanceKm,
    this.feeDistanceText,
    this.lockedDeliveryFee,
    this.lockedXpressFee,
    this.isOrderUrgent = false,
    this.billingCartSynced = false,
    this.streetAddress,
    this.deliveryCity,
    this.deliveryRegion,
    this.billingRegionId,
    this.billingCityId,
  });

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
        isDelivery: base.isDelivery || widget._isDelivery,
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

  bool _expectsDeliveryFee(CheckoutOrderTotals totals) {
    if ((widget.lockedDeliveryFee ?? 0) > 0) return true;
    return (totals.isDelivery || widget._isDelivery) && !totals.shippingFree;
  }

  /// Sync totals for UI + payment — merges locked fee scalars and clears stale
  /// free-shipping when a delivery fee is actually owed.
  CheckoutOrderTotals _paymentTotals(CheckoutOrderTotals base) {
    final lockedDelivery = widget.lockedDeliveryFee ?? 0;
    final isDelivery = widget._isDelivery;
    final owedDelivery = isDelivery
        ? (lockedDelivery > 0
            ? lockedDelivery
            : (base.deliveryFee > 0
                ? base.deliveryFee
                : (widget.orderTotals?.deliveryFee ?? 0)))
        : 0.0;
    final xpressFee = widget.lockedXpressFee ??
        (base.emergencyOrderFee > 0
            ? base.emergencyOrderFee
            : (widget.orderTotals?.emergencyOrderFee ?? 0));
    var shippingFree = base.shippingFree;
    if (isDelivery && owedDelivery > 0) {
      shippingFree = false;
    }

    return base.copyWith(
      deliveryFee: owedDelivery,
      emergencyOrderFee: xpressFee,
      isDelivery: isDelivery,
      shippingFree: shippingFree,
    );
  }

  CheckoutOrderTotals get _displayTotals =>
      _paymentTotals(_checkoutTotals);

  /// Best-known delivery fee — locked scalars from delivery page win over API.
  double _resolveDeliveryCharge(
    CheckoutOrderTotals totals, {
    Map<String, dynamic>? saveResult,
  }) {
    final lockedScalar = widget.lockedDeliveryFee ?? 0;
    if (widget.billingCartSynced && lockedScalar > 0) {
      return lockedScalar;
    }

    if (!_expectsDeliveryFee(totals)) return 0;
    if (totals.chargedDeliveryFee > 0) return totals.chargedDeliveryFee;
    if (totals.deliveryFee > 0) return totals.deliveryFee;

    if (lockedScalar > 0) return lockedScalar;

    final fromOrderTotals = widget.orderTotals?.deliveryFee ?? 0;
    if (fromOrderTotals > 0) return fromOrderTotals;

    final fromSave = DeliveryService.deliveryFeeFromSaveResult(saveResult);
    if (fromSave != null && fromSave > 0) return fromSave;

    return 0;
  }

  Future<double> _resolveDeliveryChargeAsync(
    CheckoutOrderTotals totals, {
    Map<String, dynamic>? saveResult,
  }) async {
    final syncCharge = _resolveDeliveryCharge(totals, saveResult: saveResult);
    if (syncCharge > 0) return syncCharge;

    final draft = await GuestCheckoutDraftService.load();
    if (draft != null &&
        draft.deliveryOption == 'delivery' &&
        draft.deliveryFee > 0) {
      return draft.deliveryFee;
    }
    return 0;
  }

  CheckoutOrderTotals _withResolvedDeliveryFee(
    CheckoutOrderTotals totals, {
    required double deliveryCharge,
  }) {
    if (deliveryCharge <= 0) return totals;
    if (!_expectsDeliveryFee(totals) &&
        (widget.lockedDeliveryFee ?? 0) <= 0) {
      return totals;
    }
    if (totals.chargedDeliveryFee >= deliveryCharge &&
        !totals.shippingFree) {
      return totals;
    }
    return totals.copyWith(
      deliveryFee: deliveryCharge,
      isDelivery: true,
      shippingFree: false,
    );
  }

  /// Merges locked [orderTotals], widget fee scalars, and guest draft so fees
  /// survive hot reload and logged-in checkout (no guest draft).
  Future<CheckoutOrderTotals> _resolveCheckoutTotalsForPayment() async {
    final draft = await GuestCheckoutDraftService.load();
    var totals = _checkoutTotals;
    final locked = widget.orderTotals;

    double pickDeliveryFee() {
      final lockedScalar = widget.lockedDeliveryFee ?? 0;
      if (lockedScalar > 0) return lockedScalar;
      if (totals.deliveryFee > 0) return totals.deliveryFee;
      if (totals.chargedDeliveryFee > 0) return totals.deliveryFee;
      final fromLocked = locked?.deliveryFee ?? 0;
      if (fromLocked > 0) return fromLocked;
      if (draft != null &&
          draft.deliveryOption == 'delivery' &&
          draft.deliveryFee > 0) {
        return draft.deliveryFee;
      }
      return 0;
    }

    double pickXpressFee() {
      if (totals.emergencyOrderFee > 0) return totals.emergencyOrderFee;
      final fromLocked = locked?.emergencyOrderFee ?? 0;
      if (fromLocked > 0) return fromLocked;
      final fromScalar = widget.lockedXpressFee ?? 0;
      if (fromScalar > 0) return fromScalar;
      if (draft?.emergencyOrderFee != null && draft!.emergencyOrderFee! > 0) {
        return draft.emergencyOrderFee!;
      }
      final urgent =
          widget.isOrderUrgent || (draft?.isOrderUrgent ?? false);
      if (urgent) return DeliveryService.defaultXpressFee;
      return 0;
    }

    final deliveryFee = pickDeliveryFee();
    final xpressFee = pickXpressFee();
    final isDelivery = totals.isDelivery ||
        widget._isDelivery ||
        (draft?.deliveryOption == 'delivery');
    var shippingFree = locked?.shippingFree ??
        draft?.apiShippingFree ??
        totals.shippingFree;
    // Any owed delivery fee overrides stale free-shipping flags from save-billing.
    if (isDelivery && deliveryFee > 0) {
      shippingFree = false;
    }

    if (deliveryFee > 0 ||
        xpressFee > 0 ||
        isDelivery != totals.isDelivery ||
        shippingFree != totals.shippingFree) {
      totals = totals.copyWith(
        deliveryFee: deliveryFee > 0 ? deliveryFee : totals.deliveryFee,
        emergencyOrderFee:
            xpressFee > 0 ? xpressFee : totals.emergencyOrderFee,
        isDelivery: isDelivery,
        shippingFree: shippingFree,
      );
    }

    return totals;
  }

  /// Payable amount — always merchandise + delivery line + xpress (never rely on
  /// stale [shippingFree] alone).
  String _expressPayGrandTotal({
    required CheckoutOrderTotals totals,
    required double deliveryCharge,
  }) {
    final merchandise = totals.merchandiseAfterDiscount;
    final delivery = widget._isDelivery
        ? (deliveryCharge > 0 ? deliveryCharge : totals.chargedDeliveryFee)
        : 0.0;
    final xpress = totals.emergencyOrderFee;
    return (merchandise + delivery + xpress).toStringAsFixed(2);
  }

  bool _isUrgentCheckout(CheckoutOrderTotals totals) =>
      widget.isOrderUrgent || totals.emergencyOrderFee > 0;

  /// Re-sync delivery fee to the server cart immediately before ExpressPay.
  Future<void> _syncServerCartBeforeExpressPay(double deliveryCharge) async {
    ExpressPayApiLog.section('Pre-ExpressPay cart sync starting');

    if (!widget._isDelivery || deliveryCharge <= 0) {
      ExpressPayApiLog.message(
        'Skipping delivery cart sync (isDelivery=${widget._isDelivery}, '
        'deliveryCharge=$deliveryCharge)',
      );
      return;
    }

    final distanceText = await DeliveryService.resolveDistanceTextForDeliveryFee(
      feeDistanceText: widget.feeDistanceText,
      knownDistanceKm: widget.distanceKm,
      lat: widget.lat,
      lng: widget.lng,
    );

    final email = _userEmail.trim().isNotEmpty &&
            _userEmail != 'No email available'
        ? _userEmail.trim()
        : (widget.guestEmail?.trim() ?? '');
    final phone = widget.contactNumber?.trim() ?? _phoneNumber.trim();
    final xpressFee = widget.lockedXpressFee ??
        widget.orderTotals?.emergencyOrderFee ??
        0.0;

    checkoutLog(
      '[PAYMENT] Pre-ExpressPay cart sync — delivery=$deliveryCharge, '
      'distance=$distanceText',
    );

    await DeliveryService.saveDeliveryInfo(
      name: _userName.trim().isNotEmpty ? _userName.trim() : 'Customer',
      email: email.isNotEmpty ? email : 'guest@checkout.local',
      phone: phone,
      deliveryOption: 'delivery',
      region: widget.deliveryRegion,
      city: widget.deliveryCity,
      address: widget.streetAddress ?? widget.deliveryAddress,
      regionId: widget.billingRegionId,
      cityId: widget.billingCityId,
      lat: widget.lat,
      lng: widget.lng,
      deliveryFee: deliveryCharge,
      distanceText: distanceText,
      orderUrgent: _isUrgentCheckout(
        widget.orderTotals ??
            CheckoutOrderTotals(
              merchandiseSubtotal: 0,
              discount: 0,
              deliveryFee: deliveryCharge,
              emergencyOrderFee: xpressFee,
            ),
      ),
      emergencyOrderFee: xpressFee > 0 ? xpressFee : null,
      clearStaleUrgentFee: !widget.isOrderUrgent,
      expressPayFlow: true,
    );

    if (distanceText != null && distanceText.isNotEmpty) {
      await DeliveryService.applyDeliveryFeeToCart(
        distanceText: distanceText,
        forceRefresh: true,
        knownDeliveryFee: deliveryCharge,
      );
    }

    if (widget.isOrderUrgent && xpressFee > 0) {
      await DeliveryService.addXpressFee();
    }

    ExpressPayApiLog.section('Pre-ExpressPay cart sync complete');
  }

  Map<String, dynamic> _buildExpressPaySubmitParams({
    required String totalAmountDue,
    required String orderId,
    required String orderDesc,
    required String firstName,
    required String lastName,
    required String accountNumber,
    required double deliveryCharge,
  }) {
    final deliveryOpt = widget.deliveryOption.toLowerCase().trim();
    final params = <String, dynamic>{
      'request': 'submit',
      'order_id': orderId,
      'currency': 'GHS',
      'amount': totalAmountDue,
      'order_desc': orderDesc,
      'first_name': firstName,
      'last_name': lastName,
      'email': _userEmail,
      'redirect_url': ApiConfig.paymentRedirectUrl,
      'account_number': accountNumber,
      'shipping_type': deliveryOpt,
    };
    if (deliveryOpt == 'delivery' && deliveryCharge > 0) {
      params['delivery_fee'] = deliveryCharge.toStringAsFixed(2);
    }
    return params;
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

  Future<void> _refreshPaymentPage() async {
    if (_isProcessingPayment || !mounted) return;

    setState(() => _paymentError = null);

    final cart = Provider.of<CartProvider>(context, listen: false);
    await Future.wait([
      _loadUserData(),
      cart.refreshLoginStatus(),
      cart.syncWithApi(),
    ]);

    final appliedPromo = _appliedPromoCode?.trim();
    if (appliedPromo != null && appliedPromo.isNotEmpty) {
      _promoCodeController.text = appliedPromo;
      await _applyPromoCode();
    }

    if (mounted) {
      _scheduleScrollHintUpdate();
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
      deliveryFee: widget.lockedDeliveryFee ??
          widget.orderTotals?.deliveryFee ??
          0,
      isOrderUrgent: widget.isOrderUrgent,
      emergencyOrderFee: widget.orderTotals?.emergencyOrderFee,
      estimatedDeliveryTime:
          widget.estimatedDeliveryTime ?? existing?.estimatedDeliveryTime,
      distanceKm: widget.distanceKm ?? existing?.distanceKm,
      feeDistanceText: widget.feeDistanceText ?? existing?.feeDistanceText,
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

  Future<Map<String, dynamic>> _verifyPayment(
      String token, String transactionId) async {
    checkoutLog('[DEBUG] Using token for payment verification: $token');
    return _checkoutPaymentService.verifyPayment();
  }

  Future<void> processPayment(CartProvider cart) async {
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

      var totals = _paymentTotals(await _resolveCheckoutTotalsForPayment());

      var deliveryCharge = await _resolveDeliveryChargeAsync(totals);
      totals = _withResolvedDeliveryFee(
        totals,
        deliveryCharge: deliveryCharge,
      );
      totals = _paymentTotals(totals);

      if (_expectsDeliveryFee(totals) && deliveryCharge <= 0) {
        throw Exception(
          'Delivery fee is missing. Please go back to delivery details and try again.',
        );
      }

      if (_isUrgentCheckout(totals) && totals.emergencyOrderFee <= 0) {
        throw Exception(
          'Urgent order fee is missing. Please go back to delivery details and try again.',
        );
      }

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

      if (!mounted) return;

      final totalAmountDue = _expressPayGrandTotal(
        totals: totals,
        deliveryCharge: deliveryCharge,
      );

      if (kDebugMode) {
        debugPrint(
          '[PAYMENT] ExpressPay amount=$totalAmountDue '
          '(merchandise=${totals.merchandiseAfterDiscount}, '
          'delivery=$deliveryCharge, xpress=${totals.emergencyOrderFee}, '
          'shippingFree=${totals.shippingFree})',
        );
      }

      checkoutLog(
        '[PAYMENT] ExpressPay amount=$totalAmountDue '
        '(items=${totals.merchandiseAfterDiscount}, delivery=$deliveryCharge, '
        'xpress=${totals.emergencyOrderFee})',
      );

      final expressPayParams = _buildExpressPaySubmitParams(
        totalAmountDue: totalAmountDue,
        orderId: orderId,
        orderDesc: orderDesc,
        firstName: firstName,
        lastName: lastName,
        accountNumber: accountNumber,
        deliveryCharge: deliveryCharge,
      );

      // Local order metadata (WebView / post-checkout — not sent to ExpressPay).
      final paymentParams = <String, dynamic>{
        ...expressPayParams,
        'merchandise_subtotal': totals.merchandiseAfterDiscount,
        'delivery_fee': deliveryCharge,
        'deliveryFee': deliveryCharge,
        'discount_amount': totals.discount,
        'phone_number': accountNumber,
        'address': widget.deliveryAddress ?? '',
        'shipping_type': widget.deliveryOption,
        'order_urgent': _isUrgentCheckout(totals),
        if (totals.emergencyOrderFee > 0)
          'emergency_order_fee': totals.emergencyOrderFee,
        if (widget.lat != null) 'lat': widget.lat,
        if (widget.lng != null) 'lng': widget.lng,
      };

      ExpressPayApiLog.section('Submitting to POST /expresspayment');
      ExpressPayApiLog.message('Payload: $expressPayParams');

      final purchasedItems = List<CartItem>.from(selectedItems);
      final transactionId = orderId;

      setState(() => _isProcessingPayment = false);

      unawaited(_persistGuestCheckoutDraft());

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            resolveRedirectUrl: () async {
              await _syncServerCartBeforeExpressPay(deliveryCharge);
              final responseBody = await _checkoutPaymentService
                  .submitExpressPayment(params: expressPayParams);
              final redirectUrl = prepareExpressPayPortalUrl(responseBody);
              ExpressPayApiLog.message(
                'ExpressPay portal URL: ${redirectUrl ?? responseBody}',
              );
              if (redirectUrl == null || redirectUrl.isEmpty) {
                throw Exception(
                  'Could not read a payment page URL from the server. '
                  'Please try again or contact support if this continues.',
                );
              }
              return redirectUrl;
            },
            paymentParams: paymentParams,
            purchasedItems: purchasedItems,
            paymentMethod: selectedPaymentMethod,
            deliveryAddress: widget.deliveryAddress ?? '',
            contactNumber: widget.contactNumber ?? _phoneNumber,
            deliveryOption: widget.deliveryOption,
            estimatedDeliveryTime:
                widget.estimatedDeliveryTime ?? 'Calculating ETA',
            deliveryFee: deliveryCharge,
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
        var message = e.toString().replaceFirst('Exception: ', '').trim();
        if (message.isEmpty) {
          message = kUserFacingPaymentFailureMessage;
        }
        setState(() {
          _paymentError = message;
        });
        _showPaymentFailureDialog(e, st, message);
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
    // Persistent inset for home indicator / gesture bar (stable when keyboard opens).
    final systemBottomInset = mediaQuery.viewPadding.bottom;
    const bottomLift = 8.0;
    const payBarTopPadding = 8.0;
    const payBarGap = 10.0;
    final payBarBottomPadding = bottomLift + systemBottomInset;

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.isDark
                ? [theme.pageBg, theme.pageBg]
                : [
                    AppColors.primary.withValues(alpha: 0.04),
                    theme.pageBg,
                  ],
            stops: const [0.0, 0.35],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                CheckoutFlowHeader(
                  title: 'Checkout',
                  subtitle: 'Review & pay securely',
                  activeStep: 3,
                  completedSteps: const {1, 2},
                  confirmOnBack: true,
                  leaveTitle: 'Leave Checkout',
                  leaveMessage:
                      'Are you sure you want to leave the checkout page? Your progress will be saved.',
                  footer: widget.isOrderUrgent
                      ? Container(
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emergency_rounded,
                                size: 15,
                                color: theme.isDark
                                    ? Colors.red.shade300
                                    : Colors.red.shade700,
                              ),
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
                        )
                      : null,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          final totals = _displayTotals;
                          final displayDeliveryFee = totals.deliveryFee;
                          return RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _refreshPaymentPage,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget._isDelivery) ...[
                                    _paymentSection(
                                      0,
                                      PaymentDeliveryDetailsCard(
                                        deliveryAddress: widget.deliveryAddress,
                                        contactNumber: widget.contactNumber,
                                        deliveryOption: widget.deliveryOption,
                                        deliveryIsFree:
                                            totals.chargedDeliveryFee <= 0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  _paymentSection(
                                    widget._isDelivery ? 1 : 0,
                                    PaymentOrderItemsSection(
                                      selectedItems: cart.getSelectedItems(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _paymentSection(
                                    widget._isDelivery ? 2 : 1,
                                    PaymentBillSummarySection(
                                      subtotal: totals.merchandiseSubtotal,
                                      deliveryFee: displayDeliveryFee,
                                      showDeliveryFee:
                                          totals.isDelivery || widget._isDelivery,
                                      emergencyOrderFee:
                                          totals.emergencyOrderFee,
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
                                          begin: const Offset(0, 0.1),
                                          end: Offset.zero,
                                        ),
                                      ],
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme.isDark
                                              ? Colors.red
                                                  .withValues(alpha: 0.12)
                                              : Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.red.withValues(
                                              alpha: theme.isDark ? 0.35 : 0.25,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.error_outline_rounded,
                                              size: 18,
                                              color: theme.isDark
                                                  ? Colors.red.shade300
                                                  : Colors.red.shade600,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _paymentError!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: theme.isDark
                                                      ? Colors.red.shade300
                                                      : Colors.red.shade700,
                                                  height: 1.35,
                                                ),
                                                maxLines: 5,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (_showScrollHint)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
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
                    ],
                  ),
                ),
                _buildPaymentPayBar(
                  theme: theme,
                  payBarTopPadding: payBarTopPadding,
                  payBarBottomPadding: payBarBottomPadding,
                  payBarGap: payBarGap,
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
      ),
    );
  }

  Widget _buildPaymentPayBar({
    required AppThemeColors theme,
    required double payBarTopPadding,
    required double payBarBottomPadding,
    required double payBarGap,
  }) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(14),
          ),
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: theme.isDark ? 0.2 : 0.12,
              ),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          14,
          payBarTopPadding,
          14,
          payBarBottomPadding,
        ),
        child: Selector<CartProvider, int>(
          selector: (_, cart) => Object.hash(
            cart.calculateSubtotal(),
            _displayTotals.payableAmount,
            _effectiveDiscountFromApiOrPromo,
          ),
          builder: (context, _, slideChild) {
            final total = _displayTotals.total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.isDark
                          ? [
                              AppColors.primary.withValues(alpha: 0.18),
                              AppColors.primaryDark.withValues(alpha: 0.28),
                            ]
                          : [
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.primary.withValues(alpha: 0.14),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: theme.isDark ? 0.35 : 0.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total due',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'GHS ${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: payBarGap),
                slideChild!,
              ],
            );
          },
          child: Consumer<CartProvider>(
            builder: (context, cart, _) => _buildSlideToPay(cart),
          ),
        ),
      ),
    );
  }

  Widget _paymentSection(int index, Widget child) {
    final delay = (70 * index).ms;
    return Animate(
      effects: [
        FadeEffect(duration: 320.ms, delay: delay),
        SlideEffect(
          duration: 320.ms,
          delay: delay,
          begin: const Offset(0, 0.05),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
        ),
      ],
      child: child,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double handleSize = 42.0;
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
              height: 48,
              decoration: BoxDecoration(
                color: PaymentSlideDesign.trackBg(context),
                borderRadius: BorderRadius.circular(24),
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
                          topLeft: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isProcessingPayment) ...[
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: PaymentSlideDesign.accent(context),
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Processing…',
                              style: TextStyle(
                                color: theme.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              canPay
                                  ? Icons.lock_outline
                                  : Icons.shopping_cart_outlined,
                              size: 14,
                              color: PaymentSlideDesign.labelIconColor(
                                context,
                                onProgress: labelOnProgress,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              !canPay && selectedItems.isEmpty
                                  ? 'Select items to pay'
                                  : isCompleted
                                      ? 'Release to pay'
                                      : 'Swipe to pay',
                              style: TextStyle(
                                color: PaymentSlideDesign.labelColor(
                                  context,
                                  onProgress: labelOnProgress,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
                        borderRadius: BorderRadius.circular(24),
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
                                size: 20,
                              )
                                .animate(
                                  onPlay: canPay && !isCompleted
                                      ? (c) => c.repeat(reverse: true)
                                      : null,
                                )
                                .moveX(
                                  begin: 0,
                                  end: 3,
                                  duration: 900.ms,
                                  curve: Curves.easeInOut,
                                ),
                      ),
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

  void _showPaymentFailureDialog(
    Object error, [
    StackTrace? stackTrace,
    String? message,
  ]) {
    debugPrint('[Payment] Failure dialog (details above): $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }

    final body = message ?? _paymentError ?? kUserFacingPaymentFailureMessage;

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
                  body,
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
