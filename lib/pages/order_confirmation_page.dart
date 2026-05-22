// pages/order_confirmation_page.dart
// Legacy confirmation UI (kept for reference; checkout uses post_checkout_order_page).
import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/order_notification_service.dart';
import '../utils/payment_redirect_url.dart';
import 'app_back_button.dart';
import 'order_tracking_page.dart';

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
          if (_status?.toLowerCase() == 'success') ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Thank You!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We appreciate you choosing us for your health and wellness essentials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Remember, we are always ready to assist the best way possible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.checkPayment)),
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

      // Log full API response for payment status
      debugPrint('✅ [CHECK PAYMENT API] RESPONSE RECEIVED:');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📋 Full Response Body: ${response.body}');
      debugPrint('📋 Response Headers: ${response.headers}');
      debugPrint('🔍 Request Headers: ${headers}');
      debugPrint('🔍 Request Body: ${jsonEncode(requestBody)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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

          // Log full API response
          debugPrint('✅ [PAYMENT API] SUCCESS RESPONSE:');
          debugPrint('📊 Status Code: ${response.statusCode}');
          debugPrint('📋 Full Response Body: ${response.body}');
          debugPrint('📦 Parsed JSON: ${jsonEncode(data)}');
          debugPrint('🔑 Response Keys: ${data.keys.toList()}');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          return _processPaymentStatus(data);
        } catch (e) {
          debugPrint('❌ [PAYMENT API] ERROR PARSING RESPONSE:');
          debugPrint('   Error: $e');
          debugPrint('   Raw Body: ${response.body}');
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
