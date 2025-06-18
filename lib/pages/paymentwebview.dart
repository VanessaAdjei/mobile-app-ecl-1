// pages/paymentwebview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_page.dart';
import 'CartItem.dart';
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
  _PaymentWebViewState createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

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
    } catch (e) {
      print('Error checking auth state: $e');
    }
  }

  void _navigateToConfirmation(bool success) async {
    // Check auth state before navigation
    await _checkAndRefreshAuth();

    if (!mounted) return;

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

  @override
  void initState() {
    super.initState();
    _checkAndRefreshAuth(); // Check auth state when page loads

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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('WillPopScope triggered');

        if (!mounted) return false;

        // Show confirmation dialog
        final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Cancel Payment'),
                content: Text('Are you sure you want to cancel this payment?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      print('Dialog: No pressed');
                      Navigator.pop(context, false);
                    },
                    child: Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      print('Dialog: Yes pressed');
                      Navigator.pop(context, true);
                    },
                    child: Text('Yes'),
                  ),
                ],
              ),
            ) ??
            false;

        print('Dialog result: $shouldPop');
        if (shouldPop) {
          print('Attempting to navigate back to PaymentPage');
          // Simply pop back to the previous screen (payment page)
          Navigator.pop(context, false);
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              print('AppBar back button pressed');

              if (!mounted) return;

              // Show confirmation dialog
              final shouldPop = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Cancel Payment'),
                      content:
                          Text('Are you sure you want to cancel this payment?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            print('Dialog: No pressed');
                            Navigator.pop(context, false);
                          },
                          child: Text('No'),
                        ),
                        TextButton(
                          onPressed: () {
                            print('Dialog: Yes pressed');
                            Navigator.pop(context, true);
                          },
                          child: Text('Yes'),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              print('Dialog result: $shouldPop');
              if (shouldPop) {
                print('Attempting to navigate back to PaymentPage');
                // Simply pop back to the previous screen (payment page)
                Navigator.pop(context, false);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
