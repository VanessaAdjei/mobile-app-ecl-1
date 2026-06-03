import 'dart:async';

import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/models/cart_item.dart';
import 'package:eclapp/models/order_status_step.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/providers/cart_provider.dart';
import 'package:eclapp/providers/order_tracking_provider.dart';
import 'package:eclapp/pages/delivery_page.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/services/guest_checkout_draft_service.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:eclapp/services/pending_payment_polling_service.dart';
import 'package:eclapp/utils/non_ui_error_reporter.dart';
import 'package:eclapp/utils/app_error_utils.dart';
import 'package:eclapp/widgets/checkout_progress_stepper.dart';
import 'package:eclapp/widgets/order_status_timeline.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_entrance.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_content.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_order_items_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PostCheckoutOrderPage extends StatefulWidget {
  const PostCheckoutOrderPage({
    super.key,
    required this.paymentParams,
    required this.purchasedItems,
    required this.initialTransactionId,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.contactNumber,
    required this.deliveryOption,
    required this.estimatedDeliveryTime,
    this.deliveryFee,
    required this.discount,
    this.initialStatus = 'pending',
  });

  final Map<String, dynamic> paymentParams;
  final List<CartItem> purchasedItems;
  final String initialTransactionId;
  final String paymentMethod;
  final String deliveryAddress;
  final String contactNumber;
  final String deliveryOption;
  final String estimatedDeliveryTime;
  final double? deliveryFee;
  final double discount;
  final String initialStatus;

  /// Unified post-checkout route after payment (webview or direct).
  static Route<void> route({
    required Map<String, dynamic> paymentParams,
    required List<CartItem> purchasedItems,
    required String initialTransactionId,
    required String paymentMethod,
    required String deliveryAddress,
    required String contactNumber,
    required String deliveryOption,
    required String estimatedDeliveryTime,
    double? deliveryFee,
    required double discount,
    String initialStatus = 'pending',
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => PostCheckoutOrderPage(
        paymentParams: paymentParams,
        purchasedItems: purchasedItems,
        initialTransactionId: initialTransactionId,
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
        contactNumber: contactNumber,
        deliveryOption: deliveryOption,
        estimatedDeliveryTime: estimatedDeliveryTime,
        deliveryFee: deliveryFee,
        discount: discount,
        initialStatus: initialStatus,
      ),
    );
  }

  @override
  State<PostCheckoutOrderPage> createState() => _PostCheckoutOrderPageState();
}

class _PostCheckoutOrderPageState extends State<PostCheckoutOrderPage> {
  static const String _supportPhoneNumber = '+233508411184';
  bool _hasNavigatedAway = false;
  bool _hasShownOrderPlacedBanner = false;
  bool _hasShownOrderConfirmedOnScreen = false;
  bool _showOrderConfirmedBanner = false;
  /// Shown only after user leaves this page; system notifications always fire separately.
  String? _deferredPlacedSnackMessage;
  String? _deferredConfirmedSnackMessage;
  bool _isPickupReadyForCollection(OrderTrackingModel order) {
    if (!_isPickupOrderFor(order)) return false;
    if (order.stage == OrderTrackingStage.outForDelivery) return true;
    final raw = order.rawStatus.toLowerCase();
    return raw.contains('ready for pickup') ||
        raw.contains('ready_for_pickup') ||
        raw.contains('ready to be picked');
  }

  bool _isPickupOrderFor(OrderTrackingModel order) {
    final candidates = <String?>[
      widget.deliveryOption,
      order.deliveryOption,
      order.paymentParams['delivery_option']?.toString(),
      order.paymentParams['shipping_type']?.toString(),
    ];
    return candidates.any(
      (value) =>
          (value ?? '').toLowerCase().replaceAll('-', '').contains('pickup'),
    );
  }

  String _pickupLocationText(OrderTrackingModel order) {
    return order.deliveryAddress
        .replaceFirst(RegExp(r'^Pickup at\s*', caseSensitive: false), '')
        .trim();
  }

  List<OrderStatusStep> _pickupTimelineSteps(OrderTrackingModel order) {
    return order.timelineSteps.map((step) {
      var title = step.title;
      var id = step.id;
      final normalized = title.toLowerCase().trim();
      if (normalized == 'out for delivery') {
        title = 'Ready to be picked up';
        id = 'readyForPickup';
      } else if (normalized == 'delivered') {
        title = 'Picked up';
        id = 'pickedUp';
      }
      return OrderStatusStep(
        id: id,
        title: title,
        isCompleted: step.isCompleted,
        isCurrent: step.isCurrent,
        occurredAt: step.occurredAt,
      );
    }).toList(growable: false);
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Widget _staggerReveal(
    int index,
    Widget child, {
    int stepMs = 90,
    Duration duration = const Duration(milliseconds: 520),
  }) {
    return PostCheckoutEntrance(
      index: index,
      stepMs: stepMs,
      duration: duration,
      child: child,
    );
  }

  Future<void> _openPickupDirections(String pickupLocation) async {
    final destination = pickupLocation.trim();
    if (destination.isEmpty) return;

    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=driving',
    );

    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    AppErrorUtils.showSnack(context, 'Unable to open maps right now.');
  }

  bool get _isEmergencyOrder {
    final v = widget.paymentParams['order_urgent'];
    return v == true || v == 'true';
  }

  late final OrderTrackingProvider _provider;
  final OrderTrackingService _service = OrderTrackingService();

  @override
  void initState() {
    super.initState();

    final initialOrder = _service.createInitialOrder(
      paymentParams: widget.paymentParams,
      purchasedItems: widget.purchasedItems,
      paymentMethod: widget.paymentMethod,
      initialTransactionId: widget.initialTransactionId,
      deliveryAddress: widget.deliveryAddress,
      contactNumber: widget.contactNumber,
      deliveryOption: widget.deliveryOption,
      estimatedDeliveryTime: widget.estimatedDeliveryTime,
      deliveryFee: widget.deliveryFee,
      discount: widget.discount,
      initialStatus: widget.initialStatus,
    );

    // On-page provider owns polling; stop any background handoff from a prior visit.
    PendingPaymentPollingService.stop();

    _provider = OrderTrackingProvider(
      initialOrder: initialOrder,
      initialTransactionId: widget.initialTransactionId,
      onOrderConfirmed: _handleOrderConfirmedUi,
    )..initialize();

    _provider.addListener(_onOrderTrackingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showOrderPlacedBannerIfNeeded(_provider);
    });

    // When a push (order_status/delivery) arrives, refresh tracking immediately.
    OrderTrackingProvider.onOrderStatusUpdateFromPush = () {
      _provider.refreshTracking();
    };
    OrderTrackingProvider.onOrderConfirmedStageUi = _showOrderConfirmedOnScreen;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        _showOrderConfirmedOnScreenIfAlreadyConfirmed(_provider.order);
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_onOrderTrackingChanged);
    OrderTrackingProvider.onOrderStatusUpdateFromPush = null;
    OrderTrackingProvider.onOrderConfirmedStageUi = null;

    // Keep checking payment after user leaves (e.g. Continue to home).
    if (_provider.isAwaitingPaymentConfirmation) {
      PendingPaymentPollingService.start(
        order: _provider.order,
        initialTransactionId: widget.initialTransactionId,
      );
    } else {
      PendingPaymentPollingService.stop();
    }

    _flushDeferredOrderSnacks();
    _provider.dispose();
    super.dispose();
  }

  void _flushDeferredOrderSnacks() {
    final confirmed = _deferredConfirmedSnackMessage;
    final placed = _deferredPlacedSnackMessage;
    final message = confirmed ?? placed;
    if (message == null) return;

    final duration = confirmed != null
        ? const Duration(seconds: 5)
        : const Duration(seconds: 4);
    AppErrorUtils.showGlobalSnack(
      message,
      isError: false,
      duration: duration,
    );
  }

  void _onOrderTrackingChanged() {
    if (!mounted) return;
    _showOrderPlacedBannerIfNeeded(_provider);
    _showOrderConfirmedOnScreenIfAlreadyConfirmed(_provider.order);
  }

  void _showOrderConfirmedOnScreenIfAlreadyConfirmed(OrderTrackingModel order) {
    if (order.stage == OrderTrackingStage.orderConfirmed) {
      _showOrderConfirmedOnScreen(order);
    }
  }

  List<Widget> _orderConfirmedBannerWidgets(OrderTrackingModel order) {
      return const [];
  }

  void _showOrderConfirmedOnScreen(OrderTrackingModel order) {
    if (!mounted || _hasShownOrderConfirmedOnScreen) return;
    if (order.stage != OrderTrackingStage.orderConfirmed) return;

    _hasShownOrderConfirmedOnScreen = true;

    final orderRef = order.orderNumber.isNotEmpty
        ? order.orderNumber
        : order.transactionId;
    _deferredConfirmedSnackMessage = orderRef.isEmpty
        ? 'Your order has been confirmed'
        : 'Order #$orderRef confirmed';
  }

  Future<void> _handleOrderConfirmedUi(OrderTrackingModel _) async {
    if (!mounted) return;

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();
    } catch (e, st) {
      NonUiErrorReporter.report(
        'PostCheckoutOrderPage._handleOrderConfirmedUi',
        e,
        st,
      );
    }
  }

  void _showOrderPlacedBannerIfNeeded(OrderTrackingProvider provider) {
    if (!mounted || _hasShownOrderPlacedBanner) return;
    if (provider.isAwaitingPaymentConfirmation) return;
    if (provider.order.stage == OrderTrackingStage.failed) return;

    final order = provider.order;
    final orderRef =
        order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId;
    if (orderRef.isEmpty) return;

    _hasShownOrderPlacedBanner = true;
    _deferredPlacedSnackMessage = 'Order #$orderRef placed successfully';
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:$_supportPhoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    AppErrorUtils.showSnack(context, 'Unable to open the dialer right now.');
  }

  void _goHome() {
    if (_hasNavigatedAway || !mounted) return;
    _hasNavigatedAway = true;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  void _goToCart() {
    if (_hasNavigatedAway || !mounted) return;
    _hasNavigatedAway = true;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.cart,
      (route) => false,
    );
  }

  Future<void> _resumeGuestCheckoutAfterFailure() async {
    if (_hasNavigatedAway || !mounted) return;
    _hasNavigatedAway = true;

    final isLoggedIn = await AuthService.isLoggedIn();
    final hasDraft = !isLoggedIn && await GuestCheckoutDraftService.hasDraft();

    if (!mounted) return;

    if (hasDraft) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const DeliveryPage()),
        (route) => route.isFirst,
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.cart,
      (route) => false,
    );
  }

  Widget _buildConfirmationHeader({
    required String title,
  }) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
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
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _goHome,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
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
                activeStep: 4,
                completedSteps: {1, 2, 3},
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildPendingBody(
    OrderTrackingModel order,
    OrderTrackingProvider provider,
    Color accent,
  ) {
    return RefreshIndicator(
      onRefresh: provider.retry,
      color: accent,
      child: PostCheckoutPendingContent(
        order: order,
        provider: provider,
        accent: accent,
        onHome: _goHome,
      ),
    );
  }

  Widget _buildFailedBody(OrderTrackingModel order, Color accent) {
    const cardRadius = 14.0;
    const innerRadius = 10.0;
    const borderColor = Color(0xFFE5E7EB);
    const failRed = Color(0xFFDC2626);
    const failRedDark = Color(0xFFB91C1C);
    final orderRef =
        order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId;
    final failureMessage = order.stageMessage.trim().isNotEmpty
        ? order.stageMessage
        : 'Your payment could not be completed. No charge was made.';

    return RefreshIndicator(
      onRefresh: _provider.retry,
      color: failRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggerReveal(
              0,
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardRadius),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      failRedDark,
                      failRed,
                      Color(0xFFEF4444),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: failRed.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ShakeInIcon(
                                child: _BounceInIcon(
                                  continuousPulse: true,
                                  child: _BreathingGlow(
                                    glowColor: Colors.white,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.credit_card_off_rounded,
                                        color: failRed,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment unsuccessful',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      failureMessage,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                        fontSize: 11,
                                        height: 1.35,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          color: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: const _FailedStatusTrack(),
                        ),
                      ],
                    ),
                    const _HeroShimmerSweep(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _staggerReveal(
              1,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: failRed,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order summary',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: failRedDark,
                          ),
                        ),
                        if (order.items.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFFF6F5),
                            Color(0xFFFFF1F2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(innerRadius),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 14,
                              color: failRedDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderRef.isNotEmpty
                                      ? 'Order #$orderRef'
                                      : 'Order reference unavailable',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1F1C),
                                  ),
                                ),
                                Text(
                                  'GHS ${order.totalAmount.toStringAsFixed(2)} total',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _PendingOrderItemsList(
                        items: order.items,
                        failedStyle: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _staggerReveal(
              2,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(innerRadius),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: failRedDark,
                    ).animate().shake(
                        hz: 1.2, duration: 520.ms, curve: Curves.easeOut),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No charge was made. Your items are still in your cart — retry payment or choose a different method.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _staggerReveal(
              3,
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _resumeGuestCheckoutAfterFailure,
                        style: FilledButton.styleFrom(
                          backgroundColor: failRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Retry payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.02, 1.02),
                            duration: 1400.ms,
                            curve: Curves.easeInOut,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _goHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.home_rounded,
                            size: 18, color: Colors.grey.shade700),
                        label: const Text(
                          'Home',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _staggerReveal(
              4,
              Center(
                child: TextButton.icon(
                  onPressed: _callSupport,
                  icon: Icon(Icons.phone_in_talk_rounded,
                      size: 16, color: failRedDark),
                  label: Text(
                    'Call support',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: failRedDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickedUpBody(OrderTrackingModel order) {
    final brandGreen = AppColors.primary;
    final pickupLocation = _pickupLocationText(order);
    final thankYou =
        'Thanks for collecting your order from Ernest Chemists Limited. We appreciate your business and are here whenever you need us.';

    Widget detailRow({
      required IconData icon,
      required String label,
      required String value,
      int maxLines = 4,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A),
                      height: 1.35,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      child: Column(
        children: [
          _FadeInUp(
            duration: const Duration(milliseconds: 320),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          brandGreen,
                          AppColors.primaryDark,
                          const Color(0xFF157A4C),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        _BounceInIcon(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.store_mall_directory_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PICKED UP',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Successfully picked up',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your pickup order is complete.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Text(
                      thankYou,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.55,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order summary',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#${order.orderNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total paid',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            'GHS ${order.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: brandGreen,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  detailRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Items',
                    value:
                        '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'}',
                    maxLines: 1,
                  ),
                  if (pickupLocation.isNotEmpty)
                    detailRow(
                      icon: Icons.storefront_outlined,
                      label: 'Pickup store',
                      value: pickupLocation,
                      maxLines: 4,
                    ),
                ],
              ),
            ),
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FadeInUp(
              duration: const Duration(milliseconds: 450),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'What you ordered',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...order.items.asMap().entries.map(
                          (e) => _OrderItemRow(
                            item: e.value,
                            isLast: e.key == order.items.length - 1,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _goHome,
                style: FilledButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.home_rounded, size: 21),
                label: Text(
                  'Back to home',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTrackingBody(
    OrderTrackingModel order,
    OrderTrackingProvider provider,
    Color accent,
  ) {
    final paymentConfirmed = !provider.isAwaitingPaymentConfirmation &&
        order.stage != OrderTrackingStage.pendingPayment &&
        order.stage != OrderTrackingStage.failed;
    final isReady = _isPickupReadyForCollection(order);
    final pickupLocation = _pickupLocationText(order);

    return RefreshIndicator(
      onRefresh: provider.refreshTracking,
      color: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        children: [
          ..._orderConfirmedBannerWidgets(order),
          _staggerReveal(
            0,
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 480),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: isReady
                  ? Container(
                      key: const ValueKey('pickup-ready-hero'),
                        width: double.infinity,
                      padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                        color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5EBE8)),
                          boxShadow: [
                            BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BounceInIcon(
                              continuousPulse: true,
                              child: Container(
                              width: 52,
                              height: 52,
                                decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                              child: Icon(
                                  Icons.store_mall_directory_rounded,
                                color: accent,
                                size: 28,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                              'Ready for pickup',
                              style: GoogleFonts.poppins(
                                    fontSize: 17,
                                fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A2E24),
                                height: 1.2,
                              ),
                            ),
                                const SizedBox(height: 6),
                            Text(
                              'Your order is packed and waiting at the store below. Bring your order reference when you collect.',
                              style: GoogleFonts.poppins(
                                    fontSize: 12,
                                height: 1.45,
                                    color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('pickup-prep-banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: paymentConfirmed
                            ? const Color(0xFFEFFAF4)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: paymentConfirmed
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            paymentConfirmed
                                ? Icons.verified_rounded
                                : Icons.hourglass_top_rounded,
                            color: paymentConfirmed
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paymentConfirmed
                                      ? 'Order confirmed'
                                      : 'Payment confirmation pending',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: paymentConfirmed
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  paymentConfirmed
                                      ? 'We are preparing your order. You will be notified when it is ready to collect.'
                                      : 'We are still waiting for payment verification.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
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
          const SizedBox(height: 8),
          _staggerReveal(
            1,
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: isReady
                  ? Container(
                      key: const ValueKey('pickup-ready-map'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      accent.withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Collect from',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pickupLocation.isNotEmpty
                                            ? pickupLocation
                                            : 'Selected store location',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: pickupLocation.isNotEmpty
                                    ? () =>
                                        _openPickupDirections(pickupLocation)
                                    : null,
                                icon: const Icon(Icons.navigation_rounded,
                                    size: 20),
                                label: const Text('Get directions'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('pickup-prep-store'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            color: Colors.grey.shade500,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup store',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pickupLocation.isNotEmpty
                                      ? pickupLocation
                                      : 'Selected store location',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF334155),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You can get directions once your order is ready for pickup.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
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
          const SizedBox(height: 8),
          _staggerReveal(
            2,
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order progress',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  OrderStatusTimeline(
                    steps: _pickupTimelineSteps(order),
                    accent: accent,
                  ),
                ],
              ),
            ),
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            _staggerReveal(
              3,
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade100, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order items',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showItemsSheet(order),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              'View details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...order.items.asMap().entries.map(
                          (e) => _DelayedFadeInUp(
                            delay: Duration(milliseconds: 120 + (e.key * 60)),
                            duration: const Duration(milliseconds: 380),
                            child: _OrderItemRow(
                              item: e.value,
                              isLast: e.key == order.items.length - 1,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _staggerReveal(
            4,
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _goHome,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.home_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Back to home',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTrackingBody(
    OrderTrackingModel order,
    OrderTrackingProvider provider,
    Color accent,
  ) {
    return RefreshIndicator(
      onRefresh: provider.refreshTracking,
      color: accent,
      child: PostCheckoutOrderContent(
        order: order,
        provider: provider,
        accent: accent,
        onHome: _goHome,
        onSupport: _callSupport,
      ),
    );
  }

  void _showItemsSheet(OrderTrackingModel order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DetailSheet(
        title: 'Order details',
        subtitle:
            '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'} • ${DateFormat('MMM d, y • h:mm a').format(order.createdAt)}',
        child: Column(
          children: order.items.asMap().entries.map((e) {
            return PostCheckoutOrderItemRow(
              item: e.value,
              accent: PostCheckoutDesign.accent,
              showDivider: e.key < order.items.length - 1,
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderTrackingProvider>.value(
      value: _provider,
      child: Consumer<OrderTrackingProvider>(
        builder: (context, provider, _) {
          final order = provider.order;
          final accent = PostCheckoutDesign.accent;
          final isPickup = _isPickupOrderFor(order);

          final isFailed = order.stage == OrderTrackingStage.failed;
          final headerTitle = provider.isAwaitingPaymentConfirmation
              ? 'Confirming payment'
              : order.stage == OrderTrackingStage.delivered
                  ? 'Delivered'
                  : 'Confirmation';

          return Scaffold(
            backgroundColor:
                isFailed ? const Color(0xFFFFF6F5) : PostCheckoutDesign.pageBg,
            body: Column(
              children: [
                _buildConfirmationHeader(title: headerTitle),
                if (_isEmergencyOrder)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency_rounded,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Urgent Order',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: order.stage == OrderTrackingStage.failed
                      ? _buildFailedBody(order, accent)
                      : provider.isAwaitingPaymentConfirmation
                          ? _buildPendingBody(order, provider, accent)
                          : _isPickupOrderFor(order)
                              ? (order.stage == OrderTrackingStage.delivered
                                  ? _buildPickedUpBody(order)
                                  : _buildPickupTrackingBody(
                                      order,
                                      provider,
                                      accent,
                                    ))
                              : _buildDeliveryTrackingBody(
                                  order,
                                  provider,
                                  accent,
                                ),
                                                      ),
                                                    ],
            ),
          );
        },
      ),
    );
  }
}

class _FadeInUp extends StatelessWidget {
  const _FadeInUp({
    required this.child,
    this.duration = const Duration(milliseconds: 450),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _DelayedFadeInUp extends StatefulWidget {
  const _DelayedFadeInUp({
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<_DelayedFadeInUp> createState() => _DelayedFadeInUpState();
}

class _DelayedFadeInUpState extends State<_DelayedFadeInUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _translate = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translate.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _BreathingGlow extends StatefulWidget {
  const _BreathingGlow({
    super.key,
    required this.child,
    this.glowColor = Colors.white,
  });

  final Widget child;
  final Color glowColor;

  @override
  State<_BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<_BreathingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _glow.value),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _BounceInIcon extends StatefulWidget {
  const _BounceInIcon({
    required this.child,
    this.continuousPulse = false,
  });

  final Widget child;
  final bool continuousPulse;

  @override
  State<_BounceInIcon> createState() => _BounceInIconState();
}

class _BounceInIconState extends State<_BounceInIcon>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _scale;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _pulseScale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceController, _pulseController]),
      builder: (context, child) {
        double scale = _scale.value;
        if (widget.continuousPulse && _bounceController.isCompleted) {
          scale *= _pulseScale.value;
        }
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _FailedStatusTrack extends StatelessWidget {
  const _FailedStatusTrack();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FailedStepDot(
          icon: Icons.shopping_cart_checkout_outlined,
          label: 'Attempted',
          isComplete: true,
          isActive: false,
        ),
        Expanded(
          child: _AnimatedStatusLine(isActive: true),
        ),
        _FailedStepDot(
          icon: Icons.close_rounded,
          label: 'Failed',
          isComplete: false,
          isActive: true,
          pulse: true,
        ),
        Expanded(
          child: _AnimatedStatusLine(isActive: true),
        ),
        _FailedStepDot(
          icon: Icons.refresh_rounded,
          label: 'Retry',
          isComplete: false,
          isActive: false,
          pulse: true,
        ),
      ],
    );
  }
}

class _FailedStepDot extends StatelessWidget {
  const _FailedStepDot({
    required this.icon,
    required this.label,
    required this.isComplete,
    required this.isActive,
    this.pulse = false,
  });

  final IconData icon;
  final String label;
  final bool isComplete;
  final bool isActive;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    const failRedDark = Color(0xFFB91C1C);
    final bg = isComplete || isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.18);
    final iconColor = isComplete || isActive
        ? failRedDark
        : Colors.white.withValues(alpha: 0.75);

    Widget dot = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.35),
        ),
      ),
      child: Icon(icon, size: 14, color: iconColor),
    );

    if (pulse) {
      dot = _PulseScale(
        minScale: isActive ? 0.92 : 0.94,
        maxScale: isActive ? 1.08 : 1.06,
        child: dot,
      );
    }

    return Column(
      children: [
        dot,
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: Colors.white.withValues(alpha: isActive ? 1 : 0.78),
          ),
        ),
      ],
    );
  }
}

class _AnimatedWaitingDots extends StatefulWidget {
  const _AnimatedWaitingDots({required this.color});

  final Color color;

  @override
  State<_AnimatedWaitingDots> createState() => _AnimatedWaitingDotsState();
}

class _AnimatedWaitingDotsState extends State<_AnimatedWaitingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 420 + (i * 120)),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, _) {
            return Container(
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color
                    .withValues(alpha: 0.35 + (_controllers[i].value * 0.65)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class _PulseScale extends StatefulWidget {
  const _PulseScale({
    required this.child,
    this.minScale = 0.92,
    this.maxScale = 1.08,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<_PulseScale> createState() => _PulseScaleState();
}

class _PulseScaleState extends State<_PulseScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale =
        Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class _ShakeInIcon extends StatefulWidget {
  const _ShakeInIcon({required this.child});

  final Widget child;

  @override
  State<_ShakeInIcon> createState() => _ShakeInIconState();
}

class _ShakeInIconState extends State<_ShakeInIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _PendingOrderItemsList extends StatefulWidget {
  const _PendingOrderItemsList({
    required this.items,
    this.failedStyle = false,
  });

  final List<OrderTrackingItem> items;
  final bool failedStyle;

  @override
  State<_PendingOrderItemsList> createState() => _PendingOrderItemsListState();
}

class _PendingOrderItemsListState extends State<_PendingOrderItemsList> {
  bool _showAllItems = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final hiddenCount = items.length > 3 ? items.length - 3 : 0;
    final displayed =
        _showAllItems || hiddenCount == 0 ? items : items.take(3).toList();
    final accent =
        widget.failedStyle ? const Color(0xFFDC2626) : AppColors.primary;
    final accentDark =
        widget.failedStyle ? const Color(0xFFB91C1C) : AppColors.primaryDark;
    const borderColor = Color(0xFFE5E7EB);

    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: Column(
        key: ValueKey('pending-items-${items.length}-$_showAllItems'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.failedStyle
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFBBEAD3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ...displayed.asMap().entries.map((entry) {
                  final isLast = entry.key == displayed.length - 1;
                  return _DelayedFadeInUp(
                    delay: Duration(milliseconds: 60 * entry.key),
                    duration: const Duration(milliseconds: 320),
                    child: Column(
                      children: [
                        _CompactPendingItemRow(
                          item: entry.value,
                          accent: accent,
                          accentDark: accentDark,
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: borderColor.withValues(alpha: 0.7),
                            indent: 58,
                            endIndent: 10,
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          if (hiddenCount > 0 && !_showAllItems)
            _PendingItemsExpandToggle(
              label:
                  'Show $hiddenCount more item${hiddenCount == 1 ? '' : 's'}',
              expanded: false,
              failedStyle: widget.failedStyle,
              onTap: () => setState(() => _showAllItems = true),
            ),
          if (hiddenCount > 0 && _showAllItems)
            _PendingItemsExpandToggle(
              label: 'Show less',
              expanded: true,
              failedStyle: widget.failedStyle,
              onTap: () => setState(() => _showAllItems = false),
            ),
        ],
      ),
    );
  }
}

class _PendingItemsExpandToggle extends StatefulWidget {
  const _PendingItemsExpandToggle({
    required this.label,
    required this.expanded,
    required this.onTap,
    this.failedStyle = false,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool failedStyle;

  @override
  State<_PendingItemsExpandToggle> createState() =>
      _PendingItemsExpandToggleState();
}

class _PendingItemsExpandToggleState extends State<_PendingItemsExpandToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.failedStyle ? const Color(0xFFB91C1C) : AppColors.primaryDark;
    final bg = widget.expanded
        ? (widget.failedStyle
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE3F5EC))
        : (widget.failedStyle
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFEEF9F3));
    final border =
        widget.failedStyle ? const Color(0xFFFECACA) : const Color(0xFFBBEAD3);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _pressScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  turns: widget.expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.expand_more,
                    color: accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroShimmerSweep extends StatelessWidget {
  const _HeroShimmerSweep();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.45,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat()).slideX(
                    begin: -2.2,
                    end: 2.2,
                    duration: 2600.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingStatusTrack extends StatefulWidget {
  const _PendingStatusTrack({required this.isChecking});

  final bool isChecking;

  @override
  State<_PendingStatusTrack> createState() => _PendingStatusTrackState();
}

class _PendingStatusTrackState extends State<_PendingStatusTrack>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _updateSpin();
  }

  @override
  void didUpdateWidget(_PendingStatusTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecking != widget.isChecking) {
      _updateSpin();
    }
  }

  void _updateSpin() {
    if (widget.isChecking) {
      _spinController.repeat();
    } else {
      _spinController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PendingStepDot(
          icon: Icons.check_rounded,
          label: 'Paid',
          isComplete: true,
          isActive: false,
        ),
        Expanded(
          child: _AnimatedStatusLine(isActive: true),
        ),
        _PendingStepDot(
          icon: Icons.sync_rounded,
          label: 'Confirming',
          isComplete: false,
          isActive: true,
          pulse: widget.isChecking,
          spinning: widget.isChecking,
          spinController: _spinController,
        ),
        Expanded(
          child: _AnimatedStatusLine(isActive: widget.isChecking),
        ),
        _PendingStepDot(
          icon: Icons.shopping_bag_outlined,
          label: 'Placed',
          isComplete: false,
          isActive: false,
        ),
      ],
    );
  }
}

class _AnimatedStatusLine extends StatelessWidget {
  const _AnimatedStatusLine({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: isActive
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.2),
      ),
    );

    if (!isActive) return line;

    return line
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.45, end: 1, duration: 900.ms);
  }
}

class _PendingStepDot extends StatelessWidget {
  const _PendingStepDot({
    required this.icon,
    required this.label,
    required this.isComplete,
    required this.isActive,
    this.pulse = false,
    this.spinning = false,
    this.spinController,
  });

  final IconData icon;
  final String label;
  final bool isComplete;
  final bool isActive;
  final bool pulse;
  final bool spinning;
  final AnimationController? spinController;

  @override
  Widget build(BuildContext context) {
    final bg = isComplete || isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.18);
    final iconColor = isComplete || isActive
        ? AppColors.primaryDark
        : Colors.white.withValues(alpha: 0.75);

    Widget iconWidget = Icon(
      isComplete ? Icons.check_rounded : icon,
      size: 14,
      color: iconColor,
    );

    if (spinning && spinController != null) {
      iconWidget = RotationTransition(
        turns: spinController!,
        child: iconWidget,
      );
    }

    Widget dot = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.35),
        ),
      ),
      child: iconWidget,
    );

    if (pulse && isActive) {
      dot = _PulseScale(child: dot);
    }

    return Column(
      children: [
        dot,
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: Colors.white.withValues(alpha: isActive ? 1 : 0.78),
          ),
        ),
      ],
    );
  }
}

class _CompactPendingItemRow extends StatelessWidget {
  const _CompactPendingItemRow({
    required this.item,
    required this.accent,
    required this.accentDark,
  });

  final OrderTrackingItem item;
  final Color accent;
  final Color accentDark;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl.isEmpty
        ? ''
        : item.imageUrl.startsWith('http')
            ? item.imageUrl
            : ApiConfig.getProductImageUrl(item.imageUrl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFFF4FAF7),
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.medical_services_outlined,
                          size: 16,
                          color: accent.withValues(alpha: 0.45),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.medical_services_outlined,
                            size: 16,
                            color: accent.withValues(alpha: 0.45),
                          ),
                        ),
                ),
              ),
              Positioned(
                right: -5,
                bottom: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1F1C),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'GHS ${item.price.toStringAsFixed(2)} each',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'GHS ${item.lineTotal.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentDark,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetBanner extends StatelessWidget {
  const _SheetBanner({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.accent,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: const Color(0xFF2D2D2D),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.15,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade900,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    this.isLast = false,
  });

  final OrderTrackingItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl.startsWith('http')
        ? item.imageUrl
        : ApiConfig.getProductImageUrl(item.imageUrl);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              color: Colors.grey.shade100,
              child: item.imageUrl.isEmpty
                  ? Icon(Icons.image_outlined,
                      size: 20, color: Colors.grey.shade400)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty ${item.quantity}${item.batchNo.isNotEmpty ? ' · ${item.batchNo}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text(
            'GHS ${item.lineTotal.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
