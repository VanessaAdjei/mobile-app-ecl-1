// pages/paymentwebview.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_colors.dart';
import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../utils/payment_redirect_url.dart';
import '../utils/app_error_utils.dart';
import '../widgets/checkout_progress_stepper.dart';
import 'post_checkout_order_page.dart';

enum _PaymentOutcome { success, failed, none }

/// Classifies a redirect URL as a payment success/failure using whole path
/// segments and status query params — never loose substring matching.
///
/// Loose matching (`url.contains('complete')`) is unsafe: it also matches
/// `incomplete` and any URL with the word elsewhere, and it can read a failed
/// redirect as success. The server remains the source of truth (the
/// post-checkout page polls for the real status); this only drives navigation.
_PaymentOutcome classifyPaymentUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  final segments =
      uri?.pathSegments.map((s) => s.toLowerCase()).toList() ?? const <String>[];
  final query = uri?.queryParameters ?? const <String, String>{};
  final status =
      (query['status'] ?? query['payment_status'] ?? '').toLowerCase();

  // Check failure first so a failed redirect is never misread as success.
  if (segments.contains('payment-failed') ||
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'declined') {
    return _PaymentOutcome.failed;
  }

  // Success only on a whole path segment ('complete' is the redirect path) so
  // 'incomplete' or stray query text can never trigger it.
  if (segments.contains('payment-success') ||
      segments.contains('complete') ||
      status == 'success' ||
      status == 'completed') {
    return _PaymentOutcome.success;
  }

  return _PaymentOutcome.none;
}

class PaymentWebView extends StatefulWidget {
  /// Pre-resolved portal URL. When empty, [resolveRedirectUrl] is used.
  final String? url;
  final Future<String> Function()? resolveRedirectUrl;
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

  PaymentWebView({
    super.key,
    this.url,
    this.resolveRedirectUrl,
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
  }) : assert(
          url != null || resolveRedirectUrl != null,
          'Provide url or resolveRedirectUrl',
        );

  @override
  PaymentWebViewState createState() => PaymentWebViewState();
}

class PaymentWebViewState extends State<PaymentWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isResolvingPortal = false;
  bool _isShowingDialog = false;
  String? _loadError;

  Future<void> _checkAndRefreshAuth() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        // if no token, show error and go back to payment page
        if (mounted) {
          AppErrorUtils.showSnack(
              context, 'Session expired. Please log in again.');
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
      PostCheckoutOrderPage.route(
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
    _checkAndRefreshAuth().then((_) {
      if (mounted) _bootstrapWebView();
    });
  }

  Future<void> _bootstrapWebView() async {
    try {
      var targetUrl = widget.url?.trim() ?? '';
      if (targetUrl.isEmpty && widget.resolveRedirectUrl != null) {
        setState(() {
          _isResolvingPortal = true;
          _isLoading = true;
          _loadError = null;
        });
        targetUrl = (await widget.resolveRedirectUrl!()).trim();
      }

      if (!mounted) return;

      final resolved = parsePaymentRedirectUrl(targetUrl) ?? targetUrl;
      if (resolved.isEmpty) {
        setState(() {
          _loadError =
              'Could not open the payment portal. Please go back and try again.';
          _isLoading = false;
          _isResolvingPortal = false;
        });
        return;
      }

      setState(() => _isResolvingPortal = false);
      _initializeWebView(resolved);
    } catch (e, st) {
      debugPrint('Payment portal resolve failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadError = _portalErrorMessage(e);
        _isLoading = false;
        _isResolvingPortal = false;
      });
    }
  }

  String _portalErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') || message.contains('timed out')) {
      return 'The payment portal is taking longer than usual. '
          'Please check your connection and try again.';
    }
    if (message.contains('socket') || message.contains('network')) {
      return 'Network error while connecting to the payment portal. '
          'Please check your connection and try again.';
    }
    return 'Could not connect to the payment portal. Please try again.';
  }

  Widget _buildLoadingOverlay() {
    return _PaymentPortalLoadingView(
      isConnecting: _isResolvingPortal,
    );
  }

  @override
  void dispose() {
    // clean up webview resources so we dont leak memory
    _controller?.clearCache();
    super.dispose();
  }

  // set up webview with crash prevention
  void _initializeWebView(String portalUrl) {
    final resolved = parsePaymentRedirectUrl(portalUrl) ?? portalUrl.trim();
    final parsed = Uri.tryParse(resolved);
    if (parsed == null ||
        !parsed.hasScheme ||
        (!parsed.scheme.toLowerCase().startsWith('http'))) {
      setState(() {
        _loadError = 'Invalid payment link. Please go back and try again.';
        _isLoading = false;
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadError = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);

            if (!mounted) return;

            // check for completion urls
            final outcome = classifyPaymentUrl(url);
            if (outcome == _PaymentOutcome.success) {
              widget.onPaymentComplete?.call(true, null);
              _navigateToConfirmation(true);
            } else if (outcome == _PaymentOutcome.failed) {
              widget.onPaymentComplete?.call(false, null);
              _navigateToConfirmation(false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (!mounted) return NavigationDecision.prevent;

            // check if the url means payment is done
            final outcome = classifyPaymentUrl(request.url);
            if (outcome == _PaymentOutcome.success) {
              widget.onPaymentComplete?.call(true, null);
              _navigateToConfirmation(true);
              return NavigationDecision.prevent;
            } else if (outcome == _PaymentOutcome.failed) {
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
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36');
    _controller = controller;
    try {
      controller.loadRequest(parsed);
    } catch (e, st) {
      debugPrint('PaymentWebView loadRequest failed: $e\n$st');
      setState(() {
        _loadError = 'Could not open the payment page. Please try again.';
        _isLoading = false;
        _controller = null;
      });
    }
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
        backgroundColor: const Color(0xFFF4FAF7),
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
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
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
                              activeStep: 3,
                              completedSteps: {1, 2},
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFF4FAF7)),
                      if (_loadError != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.wifi_off_rounded,
                                      size: 28,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Could not open payment portal',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _loadError!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (widget.resolveRedirectUrl != null) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: FilledButton.icon(
                                        onPressed: _bootstrapWebView,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Try again',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (_controller != null)
                        WebViewWidget(controller: _controller!),
                      if (_isLoading && _loadError == null)
                        _buildLoadingOverlay(),
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
}

class _PaymentPortalLoadingView extends StatefulWidget {
  const _PaymentPortalLoadingView({required this.isConnecting});

  /// True while waiting for the ExpressPay redirect URL from the server.
  final bool isConnecting;

  @override
  State<_PaymentPortalLoadingView> createState() =>
      _PaymentPortalLoadingViewState();
}

class _PaymentPortalLoadingViewState extends State<_PaymentPortalLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get _activeStep => widget.isConnecting ? 2 : 3;

  @override
  Widget build(BuildContext context) {
    final title = widget.isConnecting
        ? 'Connecting to ExpressPay'
        : 'Opening secure checkout';
    final subtitle = widget.isConnecting
        ? 'Setting up your encrypted payment session…'
        : 'Loading the payment page — almost there';

    return ColoredBox(
      color: const Color(0xFFF4FAF7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = 0.12 + (_pulseController.value * 0.1);
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEF9F3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: glow),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/png.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.local_pharmacy_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1F1C),
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _PortalLoadingSteps(activeStep: _activeStep),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEEF9F3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secure payment via ExpressPay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalLoadingSteps extends StatelessWidget {
  const _PortalLoadingSteps({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PortalStep(
          label: 'Prepare',
          icon: Icons.receipt_long_outlined,
          state: activeStep > 1
              ? _PortalStepState.complete
              : _PortalStepState.active,
        ),
        Expanded(child: _PortalStepLine(isActive: activeStep > 1)),
        _PortalStep(
          label: 'Connect',
          icon: Icons.link_rounded,
          state: activeStep > 2
              ? _PortalStepState.complete
              : activeStep == 2
                  ? _PortalStepState.active
                  : _PortalStepState.upcoming,
        ),
        Expanded(child: _PortalStepLine(isActive: activeStep > 2)),
        _PortalStep(
          label: 'Open',
          icon: Icons.open_in_browser_rounded,
          state: activeStep >= 3
              ? _PortalStepState.active
              : _PortalStepState.upcoming,
        ),
      ],
    );
  }
}

enum _PortalStepState { upcoming, active, complete }

class _PortalStep extends StatelessWidget {
  const _PortalStep({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _PortalStepState state;

  @override
  Widget build(BuildContext context) {
    final isComplete = state == _PortalStepState.complete;
    final isActive = state == _PortalStepState.active;

    final bg = isComplete || isActive
        ? AppColors.primary.withValues(alpha: 0.12)
        : Colors.grey.shade100;
    final border = isActive
        ? AppColors.primary
        : isComplete
            ? AppColors.primary.withValues(alpha: 0.35)
            : Colors.grey.shade300;
    final iconColor = isComplete || isActive
        ? AppColors.primaryDark
        : Colors.grey.shade500;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: isActive ? 1.5 : 1),
          ),
          child: Icon(
            isComplete ? Icons.check_rounded : icon,
            size: 15,
            color: iconColor,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primaryDark : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _PortalStepLine extends StatelessWidget {
  const _PortalStepLine({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.45)
            : Colors.grey.shade200,
      ),
    );
  }
}
