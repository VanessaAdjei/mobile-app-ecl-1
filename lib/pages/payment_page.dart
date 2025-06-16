// pages/payment_page.dart
// pages/payment_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'homepage.dart';
import 'AppBackButton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'CartItem.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'order_tracking_page.dart';
import 'package:intl/intl.dart';

class ExpressPayChannel {
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.expresspay');

  static Future<Map?> startExpressPay(Map<String, String> params) async {
    try {
      final result = await _channel.invokeMethod('startExpressPay', params);
      if (result is String) {
        // If the native side returns a JSON string, decode it
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

  const PaymentPage({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
  });

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String selectedPaymentMethod = 'Online Payment';
  bool savePaymentMethod = false;
  bool _isProcessingPayment = false;
  String _userName = "User";
  String _userEmail = "No email available";
  String _phoneNumber = "No phone number available";
  String? _paymentError;
  String? _lastPaymentToken; // Store the token from expresspayment
  String expressPaymentForm =
      'https://eclcommerce.ernestchemists.com.gh/api/expresspayment';
  bool _paymentSuccess = false;

  final List<Map<String, dynamic>> paymentMethods = [
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print("Starting user data loading...");
      await _loadUserData();
      print("User data loading complete");
      print("Final values:");
      print("Name: $_userName");
      print("Email: $_userEmail");
      print("Phone: $_phoneNumber");
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUser();

      setState(() {
        _userName = userData?['name'] ?? "User";
        _userEmail = userData?['email'] ?? "No email available";
        _phoneNumber = userData?['phone'] ?? "";
      });
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        _userName = "User";
        _userEmail = "No email available";
        _phoneNumber = "";
      });
    }
  }

  void queryPayment(String token) {
    setState(() {
      _paymentError = 'Query payment is not implemented in platform channel.';
    });
  }

  Future<Map<String, dynamic>> _verifyPayment(
      String token, String transactionId) async {
    print('\n=== PAYMENT VERIFICATION START ===');
    print('Transaction ID: $transactionId');

    final authToken = await AuthService.getToken();
    if (authToken == null) {
      print('No auth token found');
      return {
        'verified': false,
        'status': 'error',
        'message': 'No auth token found',
      };
    }

    print('Using auth token: $authToken');

    try {
      final response = await http.post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-payment'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': await AuthService.getCurrentUserID(),
          'token': token,
          'transaction_id': transactionId,
        }),
      );

      print('Payment verification response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return {
            'verified': false,
            'status': 'error',
            'message': 'Empty response from server',
          };
        }

        try {
          final data = jsonDecode(response.body);
          final status = data['status']?.toString().toLowerCase() ?? '';
          final isDeclined =
              status.contains('declined') || status.contains('failed');

          return {
            'verified': !isDeclined,
            'status': data['status'] ?? 'unknown',
            'message': data['message'] ??
                (isDeclined
                    ? 'Payment was declined'
                    : 'Payment verified successfully'),
          };
        } catch (e) {
          print('Error parsing response: $e');
          return {
            'verified': false,
            'status': 'error',
            'message': 'Error parsing server response',
          };
        }
      }

      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification failed: ${response.statusCode}',
      };
    } catch (e) {
      print('Error verifying payment: $e');
      return {
        'verified': false,
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  Future<void> processPayment(CartProvider cart) async {
    setState(() {
      _paymentError = null;
      _isProcessingPayment = true;
    });

    try {
      print('Starting payment process...');

      // Calculate cart total
      final subtotal = cart.calculateSubtotal();
      final deliveryFee = 0.00;
      final total = subtotal + deliveryFee;

      print('Cart total: $total');

      String orderDesc = cart.cartItems
          .map((item) => '${item.quantity}x ${item.name}')
          .join(', ');

      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

      final nameParts = _userName.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final params = {
        'request': 'submit',
        'order_id': 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        'currency': 'GHS',
        'amount': total.toStringAsFixed(2),
        'order_desc': orderDesc,
        'user_name': _userEmail,
        'first_name': firstName,
        'last_name': lastName.isEmpty ? 'Customer' : lastName,
        'email': _userEmail,
        'phone_number': widget.contactNumber ?? _phoneNumber,
        'account_number': widget.contactNumber ?? _phoneNumber,
        'redirect_url':
            'https://eclcommerce.ernestchemists.com.gh/api/expresspayment',
        'payment_method':
            selectedPaymentMethod == 'Cash on Delivery' ? 'cod' : 'momo',
        'delivery_address': widget.deliveryAddress ?? 'No address provided',
        'delivery_option': widget.deliveryOption,
      };

      print('\n=== EXPRESSPAYMENT API REQUEST ===');
      print('Request Parameters:');
      print(const JsonEncoder.withIndent('  ').convert(params));
      print('\nSending request to ExpressPay...');

      Map? result;
      final purchasedItems = List<CartItem>.from(cart.cartItems);
      String? paymentToken;
      String? transactionId;
      bool isVerified = false;

      // For COD orders, skip the platform channel call
      if (selectedPaymentMethod == 'Cash on Delivery') {
        print('\n=== PROCESSING COD ORDER ===');
        print('Skipping payment gateway for COD order');
        result = {
          'success': true,
          'message': 'Cash on Delivery order placed successfully',
          'transaction_id': params['order_id'],
          'verified': true,
          'verification_status': 'pending'
        };
        transactionId = params['order_id'];
        isVerified = true;

        // Clear cart for COD order immediately
        print('Clearing cart for COD order');
        await _clearCartItems(cart);
      } else {
        print('DEBUG: About to call platform channel');
        final rawResponse = await ExpressPayChannel.startExpressPay(params);
        print('\n=== EXPRESSPAY API RESPONSE DETAILS ===');
        print('Raw Response Type: ${rawResponse.runtimeType}');
        print('Raw Response: $rawResponse');
        if (rawResponse is Map) {
          print('Response Keys: ${rawResponse.keys.toList()}');
          rawResponse.forEach((key, value) {
            print('$key: $value');
          });
        }
        result = rawResponse;

        // Extract token and transaction ID from response
        if (rawResponse != null && rawResponse is Map) {
          try {
            if (rawResponse.containsKey('token')) {
              paymentToken = rawResponse['token'].toString();
              print('Extracted payment token: $paymentToken');

              // Store the ExpressPay token
              final secureStorage = FlutterSecureStorage();
              await secureStorage.write(
                  key: 'expresspay_token', value: paymentToken);
              print('Stored ExpressPay token');
            }
            // Use order-id as transaction ID if available
            if (rawResponse.containsKey('order-id')) {
              transactionId = rawResponse['order-id'].toString();
              print('Using order-id as transaction ID: $transactionId');
            }

            // Check if we need to handle redirect
            if (rawResponse.containsKey('redirect-url')) {
              final redirectUrl = rawResponse['redirect-url'].toString();
              print('Redirect URL: $redirectUrl');

              // Launch the redirect URL
              if (await canLaunchUrl(Uri.parse(redirectUrl))) {
                await launchUrl(
                  Uri.parse(redirectUrl),
                  mode: LaunchMode.externalApplication,
                );
              }
            }
          } catch (e) {
            print('Error extracting payment details: $e');
          }
        }

        // If we have a token, store it for later verification
        if (paymentToken != null && transactionId != null) {
          try {
            print('Storing payment details for later verification');
            final secureStorage = FlutterSecureStorage();
            await secureStorage.write(
                key: 'expresspay_token', value: paymentToken);
            await secureStorage.write(
                key: 'expresspay_transaction_id', value: transactionId);
            print('Stored payment details for verification');
          } catch (e) {
            print('Error storing payment details: $e');
          }
        }
      }

      // Handle success states
      bool isSuccess = false;
      if (result != null) {
        isSuccess = result['status'] == 1 ||
            result['status'] == "1" ||
            result['status'] == true;
      }

      // Don't clear the cart - wait for manual verification
      if (isSuccess && selectedPaymentMethod != 'Cash on Delivery') {
        print(
            'Payment initiated successfully, waiting for manual verification');
      }

      // Always navigate to confirmation page with items
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationPage(
            paymentParams: params,
            purchasedItems: purchasedItems,
            initialStatus: 'pending',
            initialTransactionId: transactionId,
            paymentSuccess: false,
            paymentVerified: false,
            paymentToken: paymentToken,
            paymentMethod: selectedPaymentMethod,
          ),
        ),
        (route) => false,
      );
    } catch (e, stack) {
      print('\nERROR in ExpressPay API call:');
      print('Error: $e');
      print('Stack trace: $stack');
      setState(() {
        _paymentError = 'Payment Error: ${e.toString()}';
      });
      _showPaymentFailureDialog(e.toString());
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _clearCartItems(CartProvider cart) async {
    print('_clearCartItems called');
    print('Current cart items before clearing: ${cart.cartItems.length}');

    // Create a copy of the items to avoid concurrent modification
    final itemsToRemove = List<CartItem>.from(cart.cartItems);

    // Remove each item from both local and server cart
    for (var item in itemsToRemove) {
      print('Removing item from cart: ${item.name} (ID: ${item.id})');
      await cart.removeFromCart(item.id);
    }

    print('Cart cleared. Current cart items: ${cart.cartItems.length}');
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom header (modernized)
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
                  color: theme.appBarTheme.backgroundColor ??
                      Colors.green.shade700,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppBackButton(
                            backgroundColor: theme.primaryColor,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  _buildProgressStep("Cart",
                                      isActive: false,
                                      isCompleted: true,
                                      step: 1),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Delivery",
                                      isActive: false,
                                      isCompleted: true,
                                      step: 2),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Payment",
                                      isActive: true,
                                      isCompleted: false,
                                      step: 3),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Confirmation",
                                      isActive: false,
                                      isCompleted: false,
                                      step: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return SingleChildScrollView(
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
                            child: _buildPaymentMethods(),
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 20),
                          Animate(
                            effects: [
                              FadeEffect(duration: 400.ms),
                              SlideEffect(
                                  duration: 400.ms,
                                  begin: Offset(0, 0.1),
                                  end: Offset(0, 0))
                            ],
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor:
                                      Colors.green.withOpacity(0.5),
                                  disabledForegroundColor:
                                      Colors.white.withOpacity(0.7),
                                ),
                                onPressed: _isProcessingPayment
                                    ? null
                                    : () => processPayment(cart),
                                child: _isProcessingPayment
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'CONTINUE TO PAYMENT',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                              ),
                            ),
                          ),
                          if (_paymentError != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Animate(
                                effects: [
                                  FadeEffect(duration: 400.ms),
                                  SlideEffect(
                                      duration: 400.ms,
                                      begin: Offset(0, 0.1),
                                      end: Offset(0, 0))
                                ],
                                child: Text(
                                  _paymentError!,
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isProcessingPayment)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _paymentError ?? 'An error occurred with your payment',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 1,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressStep(String text,
      {required bool isActive, required bool isCompleted, required int step}) {
    final color = isCompleted
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight:
                isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ...paymentMethods.map((method) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(method['icon'], color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        method['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              value: method['name'],
              groupValue: selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  selectedPaymentMethod = value!;
                  // Clear error when payment method changes
                  _paymentError = null;
                });
              },
              activeColor: Colors.green,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final subtotal = cart.calculateSubtotal();
    final deliveryFee = 0.00;
    final total = subtotal + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', subtotal),
          _buildSummaryRow('Delivery Fee', deliveryFee),
          const Divider(),
          _buildSummaryRow('TOTAL', total, isHighlighted: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentFailureDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Payment Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('There was an error processing your payment:'),
              SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
              Text('Please try again or choose a different payment method.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentInProgressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment In Progress'),
          content: const Text(
              'A payment is already in progress. Please wait for the current payment to complete.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
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
  });

  @override
  _OrderConfirmationPageState createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  String? _status;
  String? _statusMessage;
  String? _transactionId;
  bool _isLoading = false;
  bool _paymentSuccess = false;
  bool _hasFetchedStatus = false;
  String? _paymentToken;

  Future<void> _clearCartItems(CartProvider cart) async {
    print('_clearCartItems called');
    print('Current cart items before clearing: ${cart.cartItems.length}');

    // Create a copy of the items to avoid concurrent modification
    final itemsToRemove = List<CartItem>.from(cart.cartItems);

    // Remove each item from both local and server cart
    for (var item in itemsToRemove) {
      print('Removing item from cart: ${item.name} (ID: ${item.id})');
      await cart.removeFromCart(item.id);
    }

    print('Cart cleared. Current cart items: ${cart.cartItems.length}');
  }

  @override
  void initState() {
    super.initState();
    print('OrderConfirmationPage: initState called');
    // For cash on delivery, always show success
    if (widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      _status = "success";
      _paymentSuccess = true;
      _statusMessage = "Order successfully placed! You will pay on delivery.";
    } else {
      _status = "pending";
      _paymentSuccess = false;
      _statusMessage =
          "Payment initiated. Please check status to verify payment.";
    }
    _transactionId = widget.initialTransactionId;
    _paymentToken = widget.paymentToken;
    _isLoading = false;
    print('Initial status: $_status');
    print('Initial transaction ID: $_transactionId');
    print('Initial payment success: $_paymentSuccess');
  }

  String getImageUrl(String? url) {
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
  Widget build(BuildContext context) {
    final total = widget.purchasedItems
        .fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          try {
            final result = await _fetchPaymentStatus();
            setState(() {
              _status = result['status'];
              _statusMessage = result['message'];
              _hasFetchedStatus = true;
            });
          } catch (e) {
            print('Error fetching status: $e');
          } finally {
            setState(() => _isLoading = false);
          }
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _status?.toLowerCase() == 'success'
                        ? [Colors.green.shade50, Colors.green.shade100]
                        : _status?.toLowerCase() == 'failed'
                            ? [Colors.red.shade50, Colors.red.shade100]
                            : [Colors.orange.shade50, Colors.orange.shade100],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _status?.toLowerCase() == 'success'
                            ? Icons.check_circle
                            : _status?.toLowerCase() == 'failed'
                                ? Icons.error
                                : Icons.pending,
                        color: _getStatusColor(_status),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getStatusLabel(_status),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_status),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getStatusMessage(_status),
                      style: TextStyle(
                        fontSize: 14,
                        color: _getStatusColor(_status).withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.paymentMethod != 'Cash on Delivery') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.payment,
                                  size: 18,
                                  color: _getStatusColor(_status),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.paymentMethod,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: _getStatusColor(_status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () async {
                                setState(() => _isLoading = true);
                                try {
                                  final result = await _fetchPaymentStatus();
                                  setState(() {
                                    _status = result['status'];
                                    _statusMessage = result['message'];
                                    _hasFetchedStatus = true;
                                  });
                                } catch (e) {
                                  print('Error fetching status: $e');
                                } finally {
                                  setState(() => _isLoading = false);
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    _getStatusColor(_status)),
                                          ),
                                        )
                                      : Icon(
                                          Icons.refresh,
                                          size: 18,
                                          color: _getStatusColor(_status),
                                        ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Check Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: _getStatusColor(_status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    if (widget.paymentMethod != 'Cash on Delivery') ...[
                      _buildStatusCard(),
                      const SizedBox(height: 12),
                    ],

                    // Order Items
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...widget.purchasedItems
                                .map((item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Product Image
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              getImageUrl(item.image),
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                print(
                                                    'Error loading image: $error');
                                                return Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color:
                                                              Colors.grey[400],
                                                          size: 20),
                                                      Text(
                                                        'No Image',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 10,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Product Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'GHS ${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Item Total
                                          Text(
                                            'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            const Divider(height: 24),
                            // Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'GHS ${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomePage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Continue Shopping',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Only show Track Order button for successful payments or COD
                        if (_paymentSuccess ||
                            widget.paymentMethod.toLowerCase() ==
                                'cash on delivery')
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderTrackingPage(
                                    orderDetails: {
                                      'order_id': _transactionId,
                                      'status': _status,
                                      'created_at':
                                          DateTime.now().toIso8601String(),
                                      'product_name': widget.purchasedItems
                                          .map((item) => item.name)
                                          .join(', '),
                                      'product_img': widget
                                              .purchasedItems.isNotEmpty
                                          ? widget.purchasedItems.first.image
                                          : '',
                                      'qty': widget.purchasedItems.fold(0,
                                          (sum, item) => sum + item.quantity),
                                      'price': widget.purchasedItems.isNotEmpty
                                          ? widget.purchasedItems.first.price
                                          : 0,
                                      'total_price': widget.purchasedItems.fold(
                                          0.0,
                                          (sum, item) =>
                                              sum +
                                              (item.price * item.quantity)),
                                    },
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              'Track Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_hasFetchedStatus) ...[
              Row(
                children: [
                  Icon(
                    _getStatusIcon(_status),
                    color: _getStatusColor(_status),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _getStatusLabel(_status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(_status),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _statusMessage ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return Colors.green;
    } else if (status?.toLowerCase() == 'failed') {
      return Colors.red;
    }
    return Colors.orange;
  }

  IconData _getStatusIcon(String? status) {
    if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return Icons.check_circle;
    } else if (status?.toLowerCase() == 'failed') {
      return Icons.error;
    }
    return Icons.pending;
  }

  String _getStatusLabel(String? status) {
    if (status?.toLowerCase() == 'success' ||
        widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return 'Order Successfully Placed';
    } else if (status?.toLowerCase() == 'failed') {
      return 'Payment Failed';
    }
    return 'Payment Pending';
  }

  String _getStatusMessage(String? status) {
    if (widget.paymentMethod.toLowerCase() == 'cash on delivery') {
      return 'Your order has been placed successfully. You will pay when the items are delivered.';
    } else if (status?.toLowerCase() == 'success') {
      return 'Your payment was successful and your order has been placed.';
    } else if (status?.toLowerCase() == 'failed') {
      return 'Your payment was not successful. Please try again or choose a different payment method.';
    }
    return 'Your payment is being processed. Please wait while we confirm your payment.';
  }

  Future<Map<String, dynamic>> _fetchPaymentStatus() async {
    try {
      print('\n=== PAYMENT STATUS CHECK START ===');
      print('Starting payment status check...');

      final tokenRaw = await AuthService.getToken();
      if (tokenRaw == null || tokenRaw.isEmpty) {
        throw Exception('Please log in to check payment status');
      }

      print('Using bearer token: $tokenRaw');
      final userId = await AuthService.getCurrentUserID();
      print('User ID: $userId');

      final response = await http.post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/check-payment'),
        headers: {
          'Authorization': 'Bearer $tokenRaw',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'token': _paymentToken,
          'transaction_id': _transactionId,
        }),
      );

      print('\nResponse Status Code: ${response.statusCode}');
      print('Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return {
            'verified': false,
            'status': 'error',
            'message': 'Empty response from server',
          };
        }

        try {
          final data = jsonDecode(response.body);
          final status = data['status']?.toString().toLowerCase() ?? '';
          final isDeclined =
              status.contains('declined') || status.contains('failed');

          if (!isDeclined) {
            // If payment is successful, clear the cart
            final cart = Provider.of<CartProvider>(context, listen: false);
            await _clearCartItems(cart);
          }

          return {
            'verified': !isDeclined,
            'status': data['status'] ?? 'unknown',
            'message': data['message'] ??
                (isDeclined
                    ? 'Payment was declined'
                    : 'Payment verified successfully'),
          };
        } catch (e) {
          print('Error parsing response: $e');
          return {
            'verified': false,
            'status': 'error',
            'message': 'Error parsing server response',
          };
        }
      }

      return {
        'verified': false,
        'status': 'error',
        'message': 'Payment verification failed: ${response.statusCode}',
      };
    } catch (e) {
      print('Error checking payment status: $e');
      return {
        'verified': false,
        'status': 'error',
        'message': e.toString(),
      };
    }
  }
}
