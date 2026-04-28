import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/models/cart_item.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/pages/app_back_button.dart';
import 'package:eclapp/providers/cart_provider.dart';
import 'package:eclapp/providers/order_tracking_provider.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/services/order_notification_service.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:eclapp/widgets/live_tracking_placeholder_card.dart';
import 'package:eclapp/widgets/order_status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      onOrderConfirmed: _handleConfirmedOrder,
    )..initialize();

    // When a push (order_status/delivery) arrives, refresh tracking immediately.
    OrderTrackingProvider.onOrderStatusUpdateFromPush = () {
      _provider.refreshTracking();
    };
  }

  @override
  void dispose() {
    OrderTrackingProvider.onOrderStatusUpdateFromPush = null;
    _provider.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmedOrder(OrderTrackingModel order) async {
    if (!mounted) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.clearCart();

    await _storeOrderAmounts(order);
    await _createOrderNotification(order);
  }

  Future<void> _storeOrderAmounts(OrderTrackingModel order) async {
    final orderId = order.transactionId;
    if (orderId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('order_total_$orderId', order.totalAmount);

    if (widget.initialTransactionId != orderId &&
        widget.initialTransactionId.isNotEmpty) {
      await prefs.setDouble(
        'order_total_${widget.initialTransactionId}',
        order.totalAmount,
      );
    }
  }

  Future<void> _createOrderNotification(OrderTrackingModel order) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) return;

    await OrderNotificationService.createOrderPlacedNotification({
      'id': order.orderId,
      'transaction_id': order.transactionId,
      'order_number': order.orderNumber,
      'total_amount': order.totalAmount.toStringAsFixed(2),
      'status': order.stageLabel,
      'payment_method': order.paymentMethod,
      'items': order.items
          .map((item) => {
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'imageUrl': item.imageUrl,
                'batchNo': item.batchNo,
              })
          .toList(),
      'created_at': order.createdAt.toIso8601String(),
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
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  void _goToCart() {
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
                // Success Icon with subtle shadow
                Container(
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

          return Scaffold(
            backgroundColor: const Color(0xFFEEF1F3),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade600,
                      Colors.green.shade700,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              leading: AppBackButton(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                iconColor: Colors.white,
                onPressed: _goHome,
              ),
              title: Text(
                'Confirmation',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
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
                          : order.stage == OrderTrackingStage.delivered
                              ? _buildDeliveredBody(order, accent)
                              : provider.isAwaitingPaymentConfirmation
                                  ? _buildPendingBody(order, provider, accent)
                                  : Stack(
                                      children: [
                                        Positioned.fill(
                                          child: TrackingMap(
                                              order: order, accent: accent),
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
                                          builder: (context, scrollController) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAF9),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(20),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.06),
                                                    blurRadius: 24,
                                                    offset: const Offset(0, -4),
                                                  ),
                                                ],
                                              ),
                                              child: RefreshIndicator(
                                                onRefresh: provider
                                                        .isAwaitingPaymentConfirmation
                                                    ? provider.retry
                                                    : provider.refreshTracking,
                                                color: accent,
                                                child: ListView(
                                                  controller: scrollController,
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          16, 8, 16, 16),
                                                  children: [
                                                    Center(
                                                      child: Container(
                                                        width: 32,
                                                        height: 3,
                                                        margin: const EdgeInsets
                                                            .only(bottom: 8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade400,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(2),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey.shade100,
                                                          width: 1,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
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
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      order
                                                                          .stageLabel,
                                                                      style: GoogleFonts
                                                                          .poppins(
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: const Color(
                                                                            0xFF1A1A1A),
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
                                                                        color: Colors
                                                                            .grey
                                                                            .shade600,
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
                                                                    vertical: 4,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: accent
                                                                        .withValues(
                                                                            alpha:
                                                                                0.1),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child: Text(
                                                                    '${order.totalQuantity} item${order.totalQuantity == 1 ? '' : 's'}',
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
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
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey
                                                                  .shade600,
                                                              height: 1.35,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (order.stage ==
                                                            OrderTrackingStage
                                                                .outForDelivery &&
                                                        order.deliveryOtp !=
                                                            null &&
                                                        order.deliveryOtp!
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Container(
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
                                                                  .circular(12),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey.shade200,
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
                                                                fontSize: 10,
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
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                letterSpacing:
                                                                    6,
                                                                color: accent,
                                                                height: 1.2,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 8),
                                                            Text(
                                                              'Show to rider on delivery',
                                                              style: TextStyle(
                                                                fontSize: 11,
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
                                                        actionLabel: 'Retry',
                                                        onAction: _goToCart,
                                                        accent:
                                                            Colors.red.shade700,
                                                      ),
                                                    ] else if (provider
                                                                .errorMessage !=
                                                            null &&
                                                        provider.errorMessage!
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
                                                            .orange.shade700,
                                                      ),
                                                    ] else if (provider
                                                        .isAwaitingPaymentConfirmation) ...[
                                                      const SizedBox(
                                                          height: 12),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child:
                                                            ElevatedButton.icon(
                                                          onPressed: provider
                                                                  .isRefreshing
                                                              ? null
                                                              : provider.retry,
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                accent,
                                                            foregroundColor:
                                                                Colors.white,
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
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
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
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors.grey
                                                                  .shade700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          OrderStatusTimeline(
                                                            steps: order
                                                                .timelineSteps,
                                                            accent: accent,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (order
                                                        .items.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                                12, 10, 12, 10),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey.shade100,
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
                                                                        FontWeight
                                                                            .w600,
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
                                                                        _showItemsSheet(
                                                                            order),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(4),
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
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
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              accent,
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
                                                                    item:
                                                                        e.value,
                                                                    isLast: e
                                                                            .key ==
                                                                        order.items.length -
                                                                            1,
                                                                  ),
                                                                ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 10),
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: _goHome,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        child: Container(
                                                          width:
                                                              double.infinity,
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
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
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
        width: 88,
        height: 88,
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
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.asset(
              'assets/images/png.png',
              fit: BoxFit.contain,
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
