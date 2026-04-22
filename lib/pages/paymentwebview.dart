// pages/paymentwebview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/cart_item.dart';
import 'post_checkout_order_page.dart';
import '../services/auth_service.dart';

class PaymentWebView extends StatefulWidget {
  final String url;
  final Function(bool success, String? token)? onPaymentComplete;
  final Map<String, dynamic> paymentParams;
  final List<CartItem> purchasedItems;
  final String paymentMethod;
  final String deliveryAddress;
  final String contactNumber;
  final String deliveryOption;
  final String estimatedDeliveryTime;
  final double? deliveryFee;
  final double discount;

  const PaymentWebView({
    super.key,
    required this.url,
    required this.paymentParams,
    required this.purchasedItems,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.contactNumber,
    required this.deliveryOption,
    required this.estimatedDeliveryTime,
    this.deliveryFee,
    required this.discount,
    this.onPaymentComplete,
  });

  @override
  PaymentWebViewState createState() => PaymentWebViewState();
}

class PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isShowingDialog = false;

  Future<void> _checkAndRefreshAuth() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        // if no token, show error and go back to payment page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      debugPrint('Auth refresh check failed: $e');
    }
  }

  void _navigateToConfirmation(bool success) async {
    // check auth state before navigating
    await _checkAndRefreshAuth();

    if (!mounted) return;

    // first close the webview
    Navigator.pop(context);

    // then go to the unified post-checkout order page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCheckoutOrderPage(
          paymentParams: widget.paymentParams,
          purchasedItems: widget.purchasedItems,
          initialTransactionId:
              widget.paymentParams['order_id']?.toString() ?? '',
          paymentMethod: widget.paymentMethod,
          deliveryAddress: widget.deliveryAddress,
          contactNumber: widget.contactNumber,
          deliveryOption: widget.deliveryOption,
          estimatedDeliveryTime: widget.estimatedDeliveryTime,
          deliveryFee: widget.deliveryFee,
          discount: widget.discount,
          initialStatus: success ? 'pending' : 'failed',
        ),
      ),
    );
  }

  // show webview error dialog
  void _showWebViewError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to payment page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkAndRefreshAuth(); // Check auth state when page loads

    _initializeWebView();
  }

  @override
  void dispose() {
    // clean up webview resources so we dont leak memory
    _controller.clearCache();
    super.dispose();
  }

  // set up webview with crash prevention
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            setState(() => _isLoading = false);
            // check auth state after page loads
            await _checkAndRefreshAuth();

            if (!mounted) return;

            // check for completion urls
            if (url.contains('payment-success') || url.contains('complete')) {
              widget.onPaymentComplete?.call(true, null);
              _navigateToConfirmation(true);
            } else if (url.contains('payment-failed')) {
              widget.onPaymentComplete?.call(false, null);
              _navigateToConfirmation(false);
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            // check auth state before navigating
            await _checkAndRefreshAuth();

            if (!mounted) return NavigationDecision.prevent;

            // check if the url means payment is done
            if (request.url.contains('payment-success') ||
                request.url.contains('complete')) {
              widget.onPaymentComplete?.call(true, null);
              _navigateToConfirmation(true);
              return NavigationDecision.prevent;
            } else if (request.url.contains('payment-failed')) {
              widget.onPaymentComplete?.call(false, null);
              _navigateToConfirmation(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
            debugPrint('WebView Error Code: ${error.errorCode}');

            // handle specific error codes
            if (error.errorCode == -6) {
              // Network error - show user-friendly message
              _showWebViewError(
                  'Network connection error. Please check your internet connection and try again.');
            } else if (error.errorCode == -8) {
              // timeout error
              _showWebViewError('Connection timeout. Please try again.');
            } else {
              // generic error
              _showWebViewError(
                  'Payment page loading error. Please try again.');
            }
          },
        ),
      )
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!mounted) return;

        debugPrint('🔍 PopScope triggered - didPop: $didPop');

        // only show cancel dialog if theyre actually trying to exit
        // if didPop is true, the system handled it automatically
        // we only want to show dialog when they manually try to exit
        if (didPop) {
          debugPrint('🔍 PopScope handled automatically - not showing dialog');
          return;
        }

        // use a flag so we dont show multiple dialogs
        if (_isShowingDialog) return;
        _isShowingDialog = true;

        try {
          // wait a tiny bit to prevent navigation conflicts
          await Future.delayed(const Duration(milliseconds: 100));

          debugPrint('🔍 Showing cancel payment dialog from PopScope');

          if (!context.mounted) return;

          // show confirmation dialog with error handling
          final shouldPop = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cancel Payment?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your payment will not be processed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text('No'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          if (shouldPop == true && mounted) {
            // wait a tiny bit to prevent navigation conflicts
            await Future.delayed(const Duration(milliseconds: 100));

            if (context.mounted) {
              try {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, false);
                } else {
                  Navigator.of(context).maybePop(false);
                }
              } catch (e) {
                debugPrint('Error popping from dialog: $e');
                // last fallback
                try {
                  Navigator.of(context).maybePop(false);
                } catch (finalError) {
                  debugPrint('Final dialog fallback failed: $finalError');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error showing cancel dialog: $e');
          // if dialog fails, just go back with safety checks
          if (context.mounted) {
            try {
              if (Navigator.canPop(context)) {
                Navigator.pop(context, false);
              } else {
                Navigator.of(context).maybePop(false);
              }
            } catch (e) {
              debugPrint('Error popping after dialog error: $e');
              // last fallback, just try to go back
              try {
                Navigator.of(context).maybePop(false);
              } catch (finalError) {
                debugPrint('Final navigation fallback failed: $finalError');
              }
            }
          }
        } finally {
          _isShowingDialog = false;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Stack(
          children: [
            Column(
              children: [
                // nice header
                Builder(
                  builder: (context) {
                    final topPadding = MediaQuery.of(context).padding.top;
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
                          // header with back button and title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white, size: 20),
                                  onPressed: () async {
                                    debugPrint(
                                        '🔍 Back button pressed manually');
                                    final shouldPop = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => Dialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        backgroundColor: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                color: Colors.orange.shade700,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Cancel Payment?',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade900,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Your payment will not be processed.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        foregroundColor: Colors
                                                            .grey.shade700,
                                                        side: BorderSide(
                                                            color: Colors
                                                                .grey.shade300),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10),
                                                      ),
                                                      child: Text('No'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: Colors
                                                            .grey.shade800,
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10),
                                                        elevation: 0,
                                                      ),
                                                      child: Text('Cancel'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                    if (shouldPop == true && mounted) {
                                      // wait a tiny bit to prevent navigation conflicts
                                      await Future.delayed(
                                          const Duration(milliseconds: 100));

                                      if (context.mounted &&
                                          Navigator.canPop(context)) {
                                        try {
                                          Navigator.pop(context, false);
                                        } catch (e) {
                                          debugPrint(
                                              'Error popping from back button: $e');
                                          Navigator.of(context).maybePop(false);
                                        }
                                      }
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Payment',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
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
                                vertical: 16, horizontal: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                    );
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: 2,
            ),
            shape: BoxShape.circle,
            boxShadow: isCompleted || isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: Colors.white)
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
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight:
                isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
