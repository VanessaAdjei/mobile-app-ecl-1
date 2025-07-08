// widgets/optimized_payment_widget.dart
// widgets/optimized_payment_widget.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cartprovider.dart';
import '../pages/CartItem.dart';
import '../services/payment_optimization_service.dart';
import '../services/performance_service.dart';
import 'loading_skeleton.dart';
import 'error_display.dart';

class OptimizedPaymentWidget extends StatefulWidget {
  final String? deliveryAddress;
  final String? contactNumber;
  final String deliveryOption;
  final VoidCallback? onPaymentSuccess;
  final VoidCallback? onPaymentFailure;

  const OptimizedPaymentWidget({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.onPaymentSuccess,
    this.onPaymentFailure,
  });

  @override
  State<OptimizedPaymentWidget> createState() => _OptimizedPaymentWidgetState();
}

class _OptimizedPaymentWidgetState extends State<OptimizedPaymentWidget> {
  final PaymentOptimizationService _paymentService =
      PaymentOptimizationService();
  final PerformanceService _performanceService = PerformanceService();

  String selectedPaymentMethod = 'Online Payment';
  bool _isProcessingPayment = false;
  String? _paymentError;
  String? _appliedPromoCode;
  double _discountAmount = 0.0;
  bool _isApplyingPromo = false;
  String? _promoError;
  bool _showAllItems = false;

  // User data
  Map<String, dynamic> _userData = {};
  bool _isLoadingUserData = true;

  // Promo code controller
  final TextEditingController _promoCodeController = TextEditingController();

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
    _performanceService.startTimer('payment_widget_init');
    _initializePaymentWidget();
  }

  Future<void> _initializePaymentWidget() async {
    try {
      await _paymentService.initialize();
      await _loadUserData();
    } catch (e) {
      developer.log('Failed to initialize payment widget: $e',
          name: 'PaymentWidget');
    } finally {
      _performanceService.stopTimer('payment_widget_init');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    _performanceService.startTimer('user_data_load');
    try {
      final userData = await _paymentService.getCachedUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
        });
      }
    } catch (e) {
      developer.log('Failed to load user data: $e', name: 'PaymentWidget');
    } finally {
      _performanceService.stopTimer('user_data_load');
    }
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
      final cart = Provider.of<CartProvider>(context, listen: false);
      final subtotal = cart.calculateSubtotal();

      final result =
          await _paymentService.validatePromoCode(promoCode, subtotal);

      if (mounted) {
        setState(() {
          if (result['success']) {
            _appliedPromoCode = promoCode;
            _discountAmount = result['discountAmount'] ?? 0.0;
            _promoError = null;
          } else {
            _promoError = result['message'] ?? 'Invalid promo code';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _promoError = 'Failed to apply promo code. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingPromo = false;
        });
      }
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

  Future<void> _processPayment() async {
    if (_isProcessingPayment) return;

    setState(() {
      _paymentError = null;
      _isProcessingPayment = true;
    });

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);

      final result = await _paymentService.processPayment(
        cart: cart,
        paymentMethod: selectedPaymentMethod,
        contactNumber: widget.contactNumber ?? _userData['phone'] ?? '',
        promoCode: _appliedPromoCode,
        discountAmount: _discountAmount,
      );

      if (mounted) {
        if (result['success']) {
          if (selectedPaymentMethod == 'Cash on Delivery') {
            // Handle COD success
            _showSuccessDialog(
                result['message'] ?? 'Order placed successfully!');
            widget.onPaymentSuccess?.call();
          } else {
            // Handle online payment redirect
            final redirectUrl = result['redirectUrl'];
            if (redirectUrl != null) {
              // Navigate to payment webview
              _navigateToPaymentWebView(redirectUrl, result);
            }
          }
        } else {
          setState(() {
            _paymentError = result['message'] ?? 'Payment failed';
          });
          widget.onPaymentFailure?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentError = e.toString();
        });
      }
      widget.onPaymentFailure?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _navigateToPaymentWebView(
      String redirectUrl, Map<String, dynamic> result) {
    // Import and navigate to payment webview
    // This would typically navigate to the existing PaymentWebView
    developer.log('Navigate to payment webview: $redirectUrl',
        name: 'PaymentWidget');
  }

  void _showSuccessDialog(String message) {
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
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 30,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade500,
                        Colors.green.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
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
                        Navigator.pop(context); // Close payment page
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return const LoadingSkeleton();
    }

    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final subtotal = cart.calculateSubtotal();
        final deliveryFee = 0.00;
        final total = subtotal + deliveryFee - _discountAmount;

        return Column(
          children: [
            // Order Items Section
            _buildOrderItemsSection(cart),
            const SizedBox(height: 8),

            // Order Summary Section
            _buildOrderSummarySection(cart, subtotal, deliveryFee, total),
            const SizedBox(height: 8),

            // Error Display
            if (_paymentError != null) ...[
              const SizedBox(height: 8),
              ErrorDisplay(
                title: 'Payment Error',
                message: "Please try again",
                showRetry: true,
                onRetry: () {
                  setState(() {
                    _paymentError = null;
                  });
                },
              ),
            ],

            // Payment Methods Section
            _buildPaymentMethodsSection(),

            // Payment Button
            _buildPaymentButton(cart, total),
          ],
        );
      },
    );
  }

  Widget _buildOrderItemsSection(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                  .map((item) => _buildOrderItem(item))
                  .toList(),
              if (cart.cartItems.length > 3) ...[
                const SizedBox(height: 4),
                _buildShowMoreButton(cart.cartItems.length),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Container(
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
                _getImageUrl(item.image),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
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
    );
  }

  Widget _buildShowMoreButton(int totalItems) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAllItems = !_showAllItems;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _showAllItems ? Colors.grey.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _showAllItems ? Colors.grey.shade300 : Colors.blue.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showAllItems ? Icons.expand_less : Icons.expand_more,
              color:
                  _showAllItems ? Colors.grey.shade600 : Colors.blue.shade600,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              _showAllItems ? 'Show less' : 'Show ${totalItems - 3} more items',
              style: TextStyle(
                color:
                    _showAllItems ? Colors.grey.shade700 : Colors.blue.shade700,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummarySection(
      CartProvider cart, double subtotal, double deliveryFee, double total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
            _buildPromoCodeSection(cart),

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

  Widget _buildPromoCodeSection(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
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
                Container(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _isApplyingPromo ? null : _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                Container(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _removePromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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

  Widget _buildPaymentMethodsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(CartProvider cart, double total) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Container(
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
              color: Colors.green.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isProcessingPayment ? null : _processPayment,
            child: Center(
              child: _isProcessingPayment
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedPaymentMethod == 'Cash on Delivery'
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedPaymentMethod == 'Cash on Delivery'
                              ? Icons.money
                              : Icons.payment,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedPaymentMethod == 'Cash on Delivery'
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
      ),
    );
  }

  String _getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    _paymentService.dispose();
    super.dispose();
  }
}
