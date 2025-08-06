// pages/paymentwebview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_page.dart';
import 'cart_item.dart';
import 'auth_service.dart';

class PaymentWebView extends StatefulWidget {
  final String url;
  final Function(bool success, String? token)? onPaymentComplete;
  final Map<String, dynamic> paymentParams;
  final List<CartItem> purchasedItems;
  final String paymentMethod;

  const PaymentWebView({
    super.key,
    required this.url,
    required this.paymentParams,
    required this.purchasedItems,
    required this.paymentMethod,
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
        // If no token, show error and return to payment page
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
    } catch (e) {}
  }

  void _navigateToConfirmation(bool success) async {
    // Check auth state before navigation
    await _checkAndRefreshAuth();

    if (!mounted) return;

    // Don't create notification here - wait for actual payment verification
    // The notification will be created in OrderConfirmationPage after verification

    // First pop the WebView
    Navigator.pop(context);

    // Then push the confirmation page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderConfirmationPage(
          paymentParams: widget.paymentParams,
          purchasedItems: widget.purchasedItems,
          initialStatus: success ? 'pending' : 'error',
          initialTransactionId: widget.paymentParams['order_id'],
          paymentSuccess: success,
          paymentVerified: false,
          paymentToken: null,
          paymentMethod: widget.paymentMethod,
        ),
      ),
    );
  }

  /// Show WebView error dialog
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
    // Clean up WebView resources to prevent memory leaks
    _controller.clearCache();
    super.dispose();
  }

  /// Initialize WebView with crash prevention
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
            // Check auth state after page loads
            await _checkAndRefreshAuth();

            if (!mounted) return;

            // Check for completion URLs
            if (url.contains('payment-success') || url.contains('complete')) {
              widget.onPaymentComplete?.call(true, null);
              _navigateToConfirmation(true);
            } else if (url.contains('payment-failed')) {
              widget.onPaymentComplete?.call(false, null);
              _navigateToConfirmation(false);
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            // Check auth state before navigation
            await _checkAndRefreshAuth();

            if (!mounted) return NavigationDecision.prevent;

            // Check if the URL indicates payment completion
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

            // Handle specific error codes
            if (error.errorCode == -6) {
              // Network error - show user-friendly message
              _showWebViewError(
                  'Network connection error. Please check your internet connection and try again.');
            } else if (error.errorCode == -8) {
              // Timeout error
              _showWebViewError('Connection timeout. Please try again.');
            } else {
              // Generic error
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

        // Only show cancel dialog if user is actually trying to exit
        // If didPop is true, it means the system handled the pop automatically
        // We only want to show dialog when user manually tries to exit
        if (didPop) {
          debugPrint('🔍 PopScope handled automatically - not showing dialog');
          return;
        }

        // Use a flag to prevent multiple dialogs
        if (_isShowingDialog) return;
        _isShowingDialog = true;

        try {
          // Add a small delay to prevent navigation conflicts
          await Future.delayed(const Duration(milliseconds: 100));

          debugPrint('🔍 Showing cancel payment dialog from PopScope');

          // Show confirmation dialog with error handling
          final shouldPop = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Cancel Payment?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Are you sure you want to cancel this payment?',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(
                                  color: Colors.red.shade700, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                            ),
                            child: Text('No'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              elevation: 1,
                              shadowColor: Colors.transparent,
                            ),
                            child: Text('Yes, Cancel'),
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
            // Add a small delay to prevent navigation conflicts
            await Future.delayed(const Duration(milliseconds: 100));

            if (mounted) {
              try {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, false);
                } else {
                  Navigator.of(context).maybePop(false);
                }
              } catch (e) {
                debugPrint('Error popping from dialog: $e');
                // Final fallback
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
          // If dialog fails, just pop back with safety checks
          if (mounted) {
            try {
              if (Navigator.canPop(context)) {
                Navigator.pop(context, false);
              } else {
                Navigator.of(context).maybePop(false);
              }
            } catch (e) {
              debugPrint('Error popping after dialog error: $e');
              // Final fallback - just try to go back
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
                // Enhanced header with better design
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
                          // Header with back button and title
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
                                                BorderRadius.circular(20)),
                                        backgroundColor: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 28, vertical: 32),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(18),
                                                child: Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.red.shade700,
                                                  size: 38,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Cancel Payment?',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Are you sure you want to cancel this payment?',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 28),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        foregroundColor:
                                                            Colors.red.shade700,
                                                        side: BorderSide(
                                                            color: Colors
                                                                .red.shade700,
                                                            width: 1.2),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10,
                                                                horizontal: 8),
                                                      ),
                                                      child: Text('No'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.red.shade700,
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
                                                                vertical: 10,
                                                                horizontal: 8),
                                                        elevation: 1,
                                                        shadowColor:
                                                            Colors.transparent,
                                                      ),
                                                      child:
                                                          Text('Yes, Cancel'),
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
                                      // Add a small delay to prevent navigation conflicts
                                      await Future.delayed(
                                          const Duration(milliseconds: 100));

                                      if (mounted &&
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
