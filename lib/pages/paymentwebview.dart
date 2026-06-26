// pages/paymentwebview.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';
import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../utils/checkout_log.dart';
import '../utils/payment_redirect_url.dart';
import '../config/api_config.dart';
import '../utils/app_error_utils.dart';
import '../utils/expresspay_amount_guard.dart';
import '../widgets/checkout_progress_stepper.dart';
import 'post_checkout_order_page.dart';

enum _PaymentOutcome { success, failed, pending, none }

/// Classifies a redirect URL as a payment success/failure using whole path
/// segments and status query params — never loose substring matching.
///
/// Loose matching (`url.contains('complete')`) is unsafe: it also matches
/// `incomplete` and any URL with the word elsewhere, and it can read a failed
/// redirect as success. The server remains the source of truth (the
/// post-checkout page polls for the real status); this only drives navigation.
_PaymentOutcome classifyPaymentUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  final segments = uri?.pathSegments.map((s) => s.toLowerCase()).toList() ??
      const <String>[];
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

  // Pending — user should leave ExpressPay and wait on the in-app confirmation page.
  if (segments.contains('payment-pending') ||
      status == 'pending' ||
      status == 'processing') {
    return _PaymentOutcome.pending;
  }

  final host = uri?.host.toLowerCase() ?? '';
  if (host.contains('expresspay')) {
    if (segments.any((segment) => segment.contains('pending'))) {
      return _PaymentOutcome.pending;
    }
    if (segments.any(
      (segment) =>
          segment.contains('success') ||
          segment.contains('complete') ||
          segment.contains('callback') ||
          segment.contains('receipt') ||
          segment.contains('thank'),
    )) {
      return _PaymentOutcome.success;
    }
  }

  // Any navigation back to the merchant site (ExpressPay redirect_url target).
  if (isMerchantPaymentReturnUrl(rawUrl)) {
    return _PaymentOutcome.success;
  }

  // Success on configured ExpressPay return URL (e.g. http://eclcommerce.test/).
  if (matchesPaymentRedirectUrl(rawUrl, ApiConfig.paymentRedirectUrl)) {
    return _PaymentOutcome.success;
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

  const PaymentWebView({
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
  bool _checkoutNavigationStarted = false;
  bool _webViewTornDown = false;
  int _expressPayScanAttempts = 0;
  String? _lastExpressPayScanUrl;
  String? _initialExpressPayCheckoutUrl;
  static const int _maxExpressPayScanAttempts = 8;

  void _onExpressPayUrlChanged(String url, {required String source}) {
    if (_webViewTornDown || _checkoutNavigationStarted || !mounted) return;

    final lower = url.toLowerCase();
    if (lower.contains('checkout.php') &&
        _initialExpressPayCheckoutUrl == null) {
      _initialExpressPayCheckoutUrl = url;
    }

    _evaluatePaymentUrl(url, source: source);

    if (_shouldScanExpressPayPage(url)) {
      _lastExpressPayScanUrl = null;
      _expressPayScanAttempts = 0;
      unawaited(_scanExpressPayPage(url));
    }
  }

  bool _shouldScanExpressPayPage(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('expresspay')) return false;

    // Don't spam scans on the initial checkout form before the user pays.
    if (expressPayUrlIsCheckoutEntry(url) &&
        (_initialExpressPayCheckoutUrl == null ||
            url == _initialExpressPayCheckoutUrl)) {
      return false;
    }

    return true;
  }

  Future<void> _tearDownWebView({bool forReinit = false}) async {
    if (_webViewTornDown && !forReinit) return;
    _webViewTornDown = true;

    final controller = _controller;
    _controller = null;
    if (mounted) setState(() {});

    if (controller == null) return;

    try {
      await controller.runJavaScript(disposeExpressPayNavigationHookJs);
    } catch (e) {
      debugPrint('[EXPRESS PAY] Nav hook dispose skipped: $e');
    }

    try {
      await controller.loadRequest(Uri.parse('about:blank'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    } catch (e) {
      debugPrint('[EXPRESS PAY] WebView blank load skipped: $e');
    }

    try {
      await controller.clearCache();
    } catch (e) {
      debugPrint('[EXPRESS PAY] WebView cache clear skipped: $e');
    }
  }

  Future<void> _exitWebView([dynamic result]) async {
    await _tearDownWebView();
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      Navigator.of(context).maybePop(result);
    }
  }

  Future<void> _injectExpressPayNavigationHook() async {
    final controller = _controller;
    if (_webViewTornDown || controller == null || !mounted) return;
    try {
      await controller.runJavaScript(injectExpressPayNavigationHookJs);
    } catch (e) {
      debugPrint('[EXPRESS PAY] Navigation hook skipped: $e');
    }
  }

  void _handlePaymentOutcome(_PaymentOutcome outcome) {
    if (_checkoutNavigationStarted || !mounted) return;

    switch (outcome) {
      case _PaymentOutcome.success:
      case _PaymentOutcome.pending:
        widget.onPaymentComplete?.call(true, null);
        _navigateToConfirmation(pending: true);
        break;
      case _PaymentOutcome.failed:
        widget.onPaymentComplete?.call(false, null);
        _navigateToConfirmation(pending: false);
        break;
      case _PaymentOutcome.none:
        break;
    }
  }

  /// Scans ExpressPay pages for success/pending/failure when redirect never fires.
  Future<void> _scanExpressPayPage(String url) async {
    if (_webViewTornDown || _checkoutNavigationStarted || !mounted) return;
    if (!_shouldScanExpressPayPage(url)) return;

    if (_lastExpressPayScanUrl != url) {
      _lastExpressPayScanUrl = url;
      _expressPayScanAttempts = 0;
    }
    if (_expressPayScanAttempts >= _maxExpressPayScanAttempts) return;

    _expressPayScanAttempts++;

    final controller = _controller;
    if (controller == null) return;

    try {
      final delayMs = 700 + (_expressPayScanAttempts * 500);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (_checkoutNavigationStarted || !mounted) return;

      final raw = await controller.runJavaScriptReturningResult(
        extractExpressPayPageTextJs,
      );
      final normalizedText = normalizeWebViewJsString(raw);

      final signal = expressPayPageSignal(normalizedText, pageUrl: url);
      debugPrint(
        '[EXPRESS PAY] Page scan $_expressPayScanAttempts/$_maxExpressPayScanAttempts '
        'on $url → ${signal.name} (textLen=${normalizedText.length})',
      );

      switch (signal) {
        case ExpressPayPageSignal.success:
        case ExpressPayPageSignal.pending:
          _handlePaymentOutcome(
            signal == ExpressPayPageSignal.pending
                ? _PaymentOutcome.pending
                : _PaymentOutcome.success,
          );
          return;
        case ExpressPayPageSignal.failed:
          _handlePaymentOutcome(_PaymentOutcome.failed);
          return;
        case ExpressPayPageSignal.none:
          if (_expressPayScanAttempts < _maxExpressPayScanAttempts) {
            unawaited(_scanExpressPayPage(url));
          }
          return;
      }
    } catch (e) {
      debugPrint('[EXPRESS PAY] Page scan skipped: $e');
      if (_expressPayScanAttempts < _maxExpressPayScanAttempts) {
        unawaited(_scanExpressPayPage(url));
      }
    }
  }

  void _evaluatePaymentUrl(String url, {required String source}) {
    if (_checkoutNavigationStarted || !mounted) return;

    final outcome = classifyPaymentUrl(url);
    checkoutLog('[EXPRESS PAY] URL ($source): $url → ${outcome.name}');

    if (outcome != _PaymentOutcome.none) {
      _handlePaymentOutcome(outcome);
    }
  }

  Future<void> _checkAndRefreshAuth() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        // if no token, show error and go back to payment page
        if (mounted) {
          AppErrorUtils.showSnack(
              context, 'Session expired. Please log in again.');
          unawaited(_exitWebView(false));
        }
      }
    } catch (e) {
      debugPrint('Auth refresh check failed: $e');
    }
  }

  void _navigateToConfirmation({required bool pending}) async {
    if (_checkoutNavigationStarted) return;
    _checkoutNavigationStarted = true;

    // check auth state before navigating
    await _checkAndRefreshAuth();

    if (!mounted) return;

    await _tearDownWebView();
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
        initialStatus: pending ? 'pending' : 'failed',
      ),
    );
  }

  // show webview error dialog
  void _showWebViewError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final t = dialogContext.appColors;
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: t.border),
          ),
          title: Text(
            'Payment Error',
            style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
          ),
          content: Text(message, style: TextStyle(color: t.muted)),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _exitWebView();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: t.isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showCancelPaymentDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogTheme = dialogContext.appColors;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: dialogTheme.border),
          ),
          backgroundColor: dialogTheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payment_outlined,
                    color: dialogTheme.isDark
                        ? Colors.orange.shade300
                        : Colors.orange.shade800,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Leave checkout?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dialogTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your payment will not be processed if you leave now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: dialogTheme.muted,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dialogTheme.ink,
                          side: BorderSide(color: dialogTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text('Stay'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                        child: const Text('Leave'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

      var resolved = parsePaymentRedirectUrl(targetUrl) ?? targetUrl;
      final expectedAmount = double.tryParse(
        widget.paymentParams['amount']?.toString().replaceAll(',', '') ?? '',
      );
      if (expectedAmount != null && expectedAmount > 0) {
        resolved = alignExpressPayCheckoutUrl(resolved, expectedAmount);
      }
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
      await _initializeWebView(resolved);
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
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      final detail = raw.substring('Exception: '.length).trim();
      if (detail.isNotEmpty &&
          (detail.contains('delivery fee') ||
              detail.contains('ExpressPay would charge'))) {
        return detail;
      }
    }

    final message = raw.toLowerCase();
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

  Future<void> _onBackPressed() async {
    final shouldPop = await _showCancelPaymentDialog(context);
    if (shouldPop == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) await _exitWebView(false);
    }
  }

  Widget _buildHeader(BuildContext context, AppThemeColors theme) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            Color(0xFF1B5E20),
            AppColors.primary,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -6,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 12, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _onBackPressed,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Secure checkout',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Complete payment on ExpressPay',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: CheckoutProgressStepper(
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
        ],
      ),
    );
  }

  Widget _buildPortalErrorCard(AppThemeColors theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: Colors.orange.shade700,
                  child: const SizedBox(width: 4),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade700,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Could not open payment portal',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.muted,
                            height: 1.4,
                          ),
                        ),
                        if (widget.resolveRedirectUrl != null) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: FilledButton.icon(
                              onPressed: _bootstrapWebView,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_tearDownWebView());
    super.dispose();
  }

  // set up webview with crash prevention
  Future<void> _initializeWebView(String portalUrl) async {
    if (_controller != null) {
      await _tearDownWebView(forReinit: true);
    }
    _webViewTornDown = false;
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
      ..addJavaScriptChannel(
        'EclPaymentNav',
        onMessageReceived: (JavaScriptMessage message) {
          if (_webViewTornDown || !mounted) return;
          final payload = message.message.trim();
          if (payload.isEmpty) return;
          _onExpressPayUrlChanged(
            payload,
            source: 'js-channel',
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (_webViewTornDown || !mounted) return;
            setState(() {
              _isLoading = true;
              _loadError = null;
            });
            _onExpressPayUrlChanged(url, source: 'page-started');
          },
          onPageFinished: (String url) async {
            if (_webViewTornDown || !mounted) return;
            setState(() => _isLoading = false);

            if (!mounted || _webViewTornDown) return;

            await _injectExpressPayNavigationHook();
            _onExpressPayUrlChanged(url, source: 'page-finished');
          },
          onUrlChange: (UrlChange change) {
            if (_webViewTornDown || !mounted) return;
            final url = change.url;
            if (url == null || url.isEmpty) return;
            _onExpressPayUrlChanged(url, source: 'url-change');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_webViewTornDown || !mounted) {
              return NavigationDecision.prevent;
            }

            _onExpressPayUrlChanged(request.url, source: 'navigation');

            if (_checkoutNavigationStarted) {
              return NavigationDecision.prevent;
            }

            final outcome = classifyPaymentUrl(request.url);
            if (outcome == _PaymentOutcome.success ||
                outcome == _PaymentOutcome.pending ||
                outcome == _PaymentOutcome.failed) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (_webViewTornDown || !mounted) return;
            if (_checkoutNavigationStarted) {
              debugPrint(
                '[EXPRESS PAY] Ignoring WebView error after checkout handoff: '
                '${error.description}',
              );
              return;
            }

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
    final theme = context.appColors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!mounted) return;

        if (didPop) {
          return;
        }

        // use a flag so we dont show multiple dialogs
        if (_isShowingDialog) return;
        _isShowingDialog = true;

        try {
          // wait a tiny bit to prevent navigation conflicts
          await Future.delayed(const Duration(milliseconds: 100));

          if (!context.mounted) return;

          // show confirmation dialog with error handling
          final shouldPop = await _showCancelPaymentDialog(context);

          if (shouldPop == true && mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (context.mounted) {
              await _exitWebView(false);
            }
          }
        } catch (e) {
          debugPrint('Error showing cancel dialog: $e');
          if (context.mounted) {
            await _exitWebView(false);
          }
        } finally {
          _isShowingDialog = false;
        }
      },
      child: Scaffold(
        backgroundColor: theme.pageBg,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.isDark
                  ? [theme.pageBg, theme.pageBg]
                  : [
                      AppColors.primary.withValues(alpha: 0.04),
                      theme.pageBg,
                    ],
              stops: const [0.0, 0.28],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context, theme),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_loadError != null)
                      _buildPortalErrorCard(theme)
                    else if (_controller != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.isDark ? 0.25 : 0.06,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: WebViewWidget(controller: _controller!),
                          ),
                        ),
                      ),
                    if (_isLoading && _loadError == null)
                      _buildLoadingOverlay(),
                  ],
                ),
              ),
            ],
          ),
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
    final theme = context.appColors;
    final title = widget.isConnecting
        ? 'Connecting to ExpressPay'
        : 'Opening secure checkout';
    final subtitle = widget.isConnecting
        ? 'Setting up your encrypted payment session…'
        : 'Loading the payment page — almost there';

    return ColoredBox(
      color: theme.pageBg.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: theme.isDark ? 0.14 : 0.1,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ColoredBox(
                    color: AppColors.primary,
                    child: SizedBox(width: 4),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final glow =
                                  0.12 + (_pulseController.value * 0.1);
                              return Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.accentTint,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: glow),
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
                                    'assets/images/app_logo.png',
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
                                      border: Border.all(
                                        color: theme.surface,
                                        width: 2,
                                      ),
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
                              color: theme.ink,
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
                              color: theme.muted,
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
                              backgroundColor: theme.accentTint,
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
                                color: theme.isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primaryDark,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Secure payment via ExpressPay',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
    final t = context.appColors;
    final isComplete = state == _PortalStepState.complete;
    final isActive = state == _PortalStepState.active;

    final bg = isComplete || isActive
        ? AppColors.primary.withValues(alpha: t.isDark ? 0.18 : 0.12)
        : t.fieldBg;
    final border = isActive
        ? AppColors.primary
        : isComplete
            ? AppColors.primary.withValues(alpha: 0.35)
            : t.border;
    final iconColor = isComplete || isActive
        ? (t.isDark ? AppColors.primaryLight : AppColors.primaryDark)
        : t.muted;

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
            color: isActive
                ? (t.isDark ? AppColors.primaryLight : AppColors.primaryDark)
                : t.muted,
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
    final t = context.appColors;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: isActive ? AppColors.primary.withValues(alpha: 0.45) : t.border,
      ),
    );
  }
}
