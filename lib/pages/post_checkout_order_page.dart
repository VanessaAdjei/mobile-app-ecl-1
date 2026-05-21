import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/models/cart_item.dart';
import 'package:eclapp/models/order_status_step.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/widgets/app_header_bar.dart';
import 'package:eclapp/providers/cart_provider.dart';
import 'package:eclapp/providers/order_tracking_provider.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:eclapp/utils/non_ui_error_reporter.dart';
import 'package:eclapp/widgets/live_tracking_placeholder_card.dart';
import 'package:eclapp/widgets/order_status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  @override
  State<PostCheckoutOrderPage> createState() => _PostCheckoutOrderPageState();
}

class _PostCheckoutOrderPageState extends State<PostCheckoutOrderPage> {
  static const String _supportPhoneNumber = '+233508411184';
  bool _hasNavigatedAway = false;
  bool _hasShownOrderPlacedBanner = false;
  bool _orderPlacedSnackBarPending = false;
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
    int stepMs = 75,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    return _DelayedFadeInUp(
      delay: Duration(milliseconds: index * stepMs),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open maps right now.'),
      ),
    );
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
  }

  @override
  void dispose() {
    _provider.removeListener(_onOrderTrackingChanged);
    OrderTrackingProvider.onOrderStatusUpdateFromPush = null;
    _provider.dispose();
    super.dispose();
  }

  void _onOrderTrackingChanged() {
    if (!mounted) return;
    _showOrderPlacedBannerIfNeeded(_provider);
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
    if (_orderPlacedSnackBarPending) return;

    _orderPlacedSnackBarPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orderPlacedSnackBarPending = false;
      if (!mounted || _hasShownOrderPlacedBanner) return;
      if (_provider.isAwaitingPaymentConfirmation) return;
      if (_provider.order.stage == OrderTrackingStage.failed) return;

      final order = _provider.order;
      final orderRef = order.orderNumber.isNotEmpty
          ? order.orderNumber
          : order.transactionId;
      if (orderRef.isEmpty) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Order #$orderRef placed successfully'),
          backgroundColor: const Color(0xFF0D7A4C),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.down,
          showCloseIcon: true,
          duration: const Duration(seconds: 4),
        ),
      );
      _hasShownOrderPlacedBanner = true;
    });
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:$_supportPhoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the dialer right now.')),
    );
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

  Widget _buildPendingBody(
    OrderTrackingModel order,
    OrderTrackingProvider provider,
    Color accent,
  ) {
    return RefreshIndicator(
      onRefresh: provider.retry,
      color: accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _PulsingIcon(
              accent: accent,
              isRefreshing: provider.isRefreshing,
            ),
            const SizedBox(height: 28),
            Text(
              'Almost there!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hang tight — we\'re confirming your payment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _AnimatedDots(accent: accent),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.06),
                    accent.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Text(
                    'Usually ready in seconds',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'} • GHS ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (order.items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      ...order.items.map((item) => _OrderItemRow(item: item)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: IgnorePointer(
                    ignoring: provider.isRefreshing,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: provider.retry,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: provider.isRefreshing
                                ? accent.withValues(alpha: 0.6)
                                : accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (provider.isRefreshing)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                provider.isRefreshing
                                    ? 'Checking…'
                                    : 'Check status',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _goHome,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_rounded,
                              size: 20,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Home',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
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
          ],
        ),
      ),
    );
  }

  Widget _buildFailedBody(OrderTrackingModel order, Color accent) {
    return RefreshIndicator(
      onRefresh: _provider.retry,
      color: accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _BounceInIcon(
                      continuousPulse: true,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 36,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Payment unsuccessful',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No worries — you can try again or use a different payment method. We\'re here if you need help.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _DelayedFadeInUp(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 450),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'} • GHS ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DelayedFadeInUp(
                delay: const Duration(milliseconds: 280),
                duration: const Duration(milliseconds: 450),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items in this order',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...order.items.map((item) => _OrderItemRow(item: item)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            _DelayedFadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 450),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToCart,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Retry payment',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goHome,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_rounded,
                                size: 20,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Home',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveredBody(OrderTrackingModel order, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _FadeInUp(
            duration: const Duration(milliseconds: 350),
            child: Column(
              children: [
                _BounceInIcon(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 40,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Delivered Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'DELIVERED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Main Title
                Text(
                  'Your order has arrived',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Message Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'We appreciate you choosing us for your health and wellness essentials.',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thank you. Remember, we are always ready to assist the best way possible.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Decorative Divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 1.5,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 1.5,
                      color: Colors.grey.shade300,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'GHS ${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade100,
                          Colors.grey.shade200,
                          Colors.grey.shade100,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (order.deliveryAddress.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.deliveryAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FadeInUp(
              duration: const Duration(milliseconds: 450),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order items',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
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
          const SizedBox(height: 28),
          _FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(
                  'Back to Home',
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

  Widget _buildPickedUpBody(OrderTrackingModel order) {
    final brandGreen = AppColors.primary;
    final pickupLocation = _pickupLocationText(order);
    final thankYou =
        'Thanks for collecting your order from Ernest Chemists. We appreciate your business and are here whenever you need us.';

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
    final pickupLat = _parseCoordinate(order.paymentParams['lat']) ??
        _parseCoordinate(order.paymentParams['latitude']) ??
        _parseCoordinate(order.paymentParams['store_lat']) ??
        _parseCoordinate(order.paymentParams['store_latitude']);
    final pickupLng = _parseCoordinate(order.paymentParams['lng']) ??
        _parseCoordinate(order.paymentParams['longitude']) ??
        _parseCoordinate(order.paymentParams['store_lng']) ??
        _parseCoordinate(order.paymentParams['store_longitude']);

    return RefreshIndicator(
      onRefresh: provider.refreshTracking,
      color: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        children: [
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
                  ? _BreathingGlow(
                      key: const ValueKey('pickup-ready-hero'),
                      glowColor: accent,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent,
                              AppColors.primaryDark,
                              const Color(0xFF157A4C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _BounceInIcon(
                              continuousPulse: true,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.store_mall_directory_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ready for pickup',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your order is packed and waiting at the store below. Bring your order reference when you collect.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.45,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
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
                border: Border.all(color: accent.withValues(alpha: 0.2)),
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
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: 190,
                      child: TrackingMap(
                        order: order.copyWith(deliveryAddress: pickupLocation),
                        accent: accent,
                        showShopLocation: false,
                        destinationMarkerTitle: 'Pickup location',
                        deliveryCoordinates:
                            (pickupLat != null && pickupLng != null)
                                ? LatLng(pickupLat, pickupLng)
                                : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: pickupLocation.isNotEmpty
                            ? () => _openPickupDirections(pickupLocation)
                            : null,
                        icon: const Icon(Icons.navigation_rounded, size: 20),
                        label: const Text('Get directions'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  'Map and directions will appear here once your order is ready for pickup.',
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
          children: order.items
              .map((item) => _OrderItemRow(item: item))
              .toList(growable: false),
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
          final accent = const Color(0xFF0D7A4C); // Refined emerald
          final isPickup = _isPickupOrderFor(order);
          final isTerminalSuccess = order.stage == OrderTrackingStage.delivered;
          final showPickedUp = isPickup && isTerminalSuccess;
          final showDelivered = !isPickup && isTerminalSuccess;
          final showPickupReady =
              isPickup && !showPickedUp && _isPickupReadyForCollection(order);

          return Scaffold(
            backgroundColor: (showPickedUp || showDelivered)
                ? const Color(0xFFF0F4F2)
                : const Color(0xFFEEF1F3),
            appBar: AppHeaderBar.forScaffold(
              context,
              title: showPickedUp
                  ? 'Picked up'
                  : showDelivered
                      ? 'Order delivered'
                      : showPickupReady
                          ? 'Ready for pickup'
                          : 'Confirmation',
              showCart: false,
              onBack: _goHome,
              background: (showPickedUp || showDelivered)
                  ? AppHeaderBackground.accent
                  : AppHeaderBackground.standard,
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  child: provider.isLoading &&
                          provider.isAwaitingPaymentConfirmation
                      ? const Center(child: CircularProgressIndicator())
                      : order.stage == OrderTrackingStage.failed
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
                                  : order.stage == OrderTrackingStage.delivered
                                      ? _buildDeliveredBody(order, accent)
                                      : Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TrackingMap(
                                                order: order,
                                                accent: accent,
                                                showShopLocation: false,
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 16,
                                              right: 16,
                                              child: Material(
                                                elevation: 6,
                                                shadowColor: Colors.black
                                                    .withValues(alpha: 0.2),
                                                shape: const CircleBorder(),
                                                color: accent,
                                                child: InkWell(
                                                  onTap: _callSupport,
                                                  customBorder:
                                                      const CircleBorder(),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: Icon(
                                                      Icons.phone_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DraggableScrollableSheet(
                                              initialChildSize: 0.4,
                                              minChildSize: 0.3,
                                              maxChildSize: 0.88,
                                              builder:
                                                  (context, scrollController) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF8FAF9),
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.06),
                                                        blurRadius: 24,
                                                        offset:
                                                            const Offset(0, -4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: RefreshIndicator(
                                                    onRefresh: provider
                                                            .isAwaitingPaymentConfirmation
                                                        ? provider.retry
                                                        : provider
                                                            .refreshTracking,
                                                    color: accent,
                                                    child: ListView(
                                                      controller:
                                                          scrollController,
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          16, 8, 16, 16),
                                                      children: [
                                                        Center(
                                                          child: Container(
                                                            width: 32,
                                                            height: 3,
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    bottom: 8),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.grey
                                                                  .shade400,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2),
                                                            ),
                                                          ),
                                                        ),
                                                        _FadeInUp(
                                                          duration:
                                                              const Duration(
                                                            milliseconds: 380,
                                                          ),
                                                          child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 16,
                                                            vertical: 14,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: Colors.grey
                                                                  .shade100,
                                                              width: 1,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.04),
                                                                blurRadius: 10,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          order
                                                                              .stageLabel,
                                                                          style:
                                                                              GoogleFonts.poppins(
                                                                            fontSize:
                                                                                16,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color:
                                                                                const Color(0xFF1A1A1A),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            height:
                                                                                4),
                                                                        Text(
                                                                          'Order #${order.orderNumber}',
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            color:
                                                                                Colors.grey.shade600,
                                                                            letterSpacing:
                                                                                0.2,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  if (order.stage !=
                                                                          OrderTrackingStage
                                                                              .failed &&
                                                                      order.stage !=
                                                                          OrderTrackingStage
                                                                              .pendingPayment)
                                                                    Container(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: accent.withValues(
                                                                            alpha:
                                                                                0.1),
                                                                        borderRadius:
                                                                            BorderRadius.circular(8),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'}',
                                                                        style: GoogleFonts
                                                                            .poppins(
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              accent,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 10),
                                                              Text(
                                                                order.stage ==
                                                                        OrderTrackingStage
                                                                            .failed
                                                                    ? order
                                                                        .stageMessage
                                                                    : 'Arrives in ${order.estimatedDeliveryTime} • GHS ${order.totalAmount.toStringAsFixed(2)}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                  height: 1.35,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        ),
                                                        if (order.stage ==
                                                                OrderTrackingStage
                                                                    .outForDelivery &&
                                                            order.deliveryOtp !=
                                                                null &&
                                                            order.deliveryOtp!
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 8),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 16,
                                                              vertical: 14,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              border:
                                                                  Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade200,
                                                                width: 1,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.03),
                                                                  blurRadius: 8,
                                                                  offset:
                                                                      const Offset(
                                                                          0, 2),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  'DELIVERY CODE',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    letterSpacing:
                                                                        1.2,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 10),
                                                                Text(
                                                                  order
                                                                      .deliveryOtp!,
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    fontSize:
                                                                        22,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    letterSpacing:
                                                                        6,
                                                                    color:
                                                                        accent,
                                                                    height: 1.2,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 8),
                                                                Text(
                                                                  'Show to rider on delivery',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500,
                                                                    letterSpacing:
                                                                        0.2,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                        if (order.stage ==
                                                            OrderTrackingStage
                                                                .failed) ...[
                                                          const SizedBox(
                                                              height: 12),
                                                          _SheetBanner(
                                                            icon: Icons
                                                                .warning_amber_rounded,
                                                            message:
                                                                'Your payment could not be completed.',
                                                            actionLabel:
                                                                'Retry',
                                                            onAction: _goToCart,
                                                            accent: Colors
                                                                .red.shade700,
                                                          ),
                                                        ] else if (provider
                                                                    .errorMessage !=
                                                                null &&
                                                            provider
                                                                .errorMessage!
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 12),
                                                          _SheetBanner(
                                                            icon: Icons
                                                                .wifi_tethering_error_rounded,
                                                            message: provider
                                                                .errorMessage!,
                                                            actionLabel: provider
                                                                    .isAwaitingPaymentConfirmation
                                                                ? 'Check status'
                                                                : 'Refresh',
                                                            onAction: provider
                                                                    .isAwaitingPaymentConfirmation
                                                                ? provider.retry
                                                                : provider
                                                                    .refreshTracking,
                                                            accent: Colors
                                                                .orange
                                                                .shade700,
                                                          ),
                                                        ] else if (provider
                                                            .isAwaitingPaymentConfirmation) ...[
                                                          const SizedBox(
                                                              height: 12),
                                                          SizedBox(
                                                            width:
                                                                double.infinity,
                                                            child:
                                                                ElevatedButton
                                                                    .icon(
                                                              onPressed: provider
                                                                      .isRefreshing
                                                                  ? null
                                                                  : provider
                                                                      .retry,
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    accent,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                elevation: 0,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  vertical: 12,
                                                                ),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                              ),
                                                              icon: Icon(
                                                                provider.isRefreshing
                                                                    ? Icons
                                                                        .sync_rounded
                                                                    : Icons
                                                                        .refresh_rounded,
                                                                size: 20,
                                                              ),
                                                              label: Text(
                                                                provider.isRefreshing
                                                                    ? 'Checking'
                                                                    : 'Check status',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  letterSpacing:
                                                                      0.3,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                            height: 4),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .fromLTRB(
                                                                  9, 7, 9, 7),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.04),
                                                                blurRadius: 12,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Order progress',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize:
                                                                      11.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              OrderStatusTimeline(
                                                                steps: order
                                                                    .timelineSteps,
                                                                accent: accent,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (order.items
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 6),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .fromLTRB(
                                                                    12,
                                                                    10,
                                                                    12,
                                                                    10),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              border:
                                                                  Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade100,
                                                                width: 1,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.02),
                                                                  blurRadius: 6,
                                                                  offset:
                                                                      const Offset(
                                                                          0, 1),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      'Order items',
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        letterSpacing:
                                                                            0.3,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade600,
                                                                      ),
                                                                    ),
                                                                    Material(
                                                                      color: Colors
                                                                          .transparent,
                                                                      child:
                                                                          InkWell(
                                                                        onTap: () =>
                                                                            _showItemsSheet(order),
                                                                        borderRadius:
                                                                            BorderRadius.circular(4),
                                                                        child:
                                                                            Padding(
                                                                          padding:
                                                                              const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                4,
                                                                            vertical:
                                                                                2,
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            'View details',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 11,
                                                                              fontWeight: FontWeight.w500,
                                                                              color: accent,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                    height: 8),
                                                                ...order.items
                                                                    .asMap()
                                                                    .entries
                                                                    .map(
                                                                      (e) =>
                                                                          _OrderItemRow(
                                                                        item: e
                                                                            .value,
                                                                        isLast: e.key ==
                                                                            order.items.length -
                                                                                1,
                                                                      ),
                                                                    ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                            height: 10),
                                                        Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: InkWell(
                                                            onTap: _goHome,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: Container(
                                                              width: double
                                                                  .infinity,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                vertical: 12,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: accent,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .home_rounded,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 8),
                                                                  Text(
                                                                    'Back to Home',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          14,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
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
          final pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
              CurvedAnimation(
                  parent: _pulseController, curve: Curves.easeInOut));
          scale *= pulse.value;
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

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({required this.accent});

  final Color accent;

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + (i * 150)),
      )..repeat(reverse: true);
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.4, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
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
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: _animations[i].value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.accent
                        .withValues(alpha: 0.3 + (_animations[i].value * 0.5)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({
    required this.accent,
    required this.isRefreshing,
  });

  final Color accent;
  final bool isRefreshing;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
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
    if (widget.isRefreshing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 96,
        height: 96,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipOval(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: Image.asset(
                  'assets/images/png.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.local_pharmacy_rounded,
                    size: 44,
                    color: widget.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
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
