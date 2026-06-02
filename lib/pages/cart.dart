// pages/cart.dart
import 'package:flutter/material.dart';

import '../models/cart_item.dart';

import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'delivery_page.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_back_button.dart';
import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../services/auth_service.dart';
import 'signinpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/cart/cart_checkout_bottom_bar.dart';
import '../widgets/cart/remove_from_cart_dialog.dart';
import '../widgets/cart_quantity_stepper.dart';
import '../widgets/checkout_progress_stepper.dart';
import '../services/delivery_service.dart';
import '../config/app_colors.dart';
import '../utils/app_error_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  CartState createState() => CartState();
}

class CartState extends State<Cart> {
  static const Color _cartBg = Color(0xFFF4FAF7);
  static const Color _cartBorder = Color(0xFFE5E7EB);
  static const Color _cartGreenBorder = Color(0xFFBBEAD3);
  static const Color _cartGreenTint = Color(0xFFEEF9F3);
  static const Color _cartInk = Color(0xFF1F2937);
  static const Color _cartMuted = Color(0xFF6B7280);

  String deliveryOption = 'Delivery';

  String? selectedRegion;
  String? selectedCity;
  String? selectedTown;
  double deliveryFee = 0.00;

  TextEditingController addressController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  Timer? _syncTimer;
  bool _isLoggedIn = false;
  final ScrollController _cartScrollController = ScrollController();
  bool _showScrollHint = false;
  bool _cartListCanScroll = false;

  @override
  void initState() {
    super.initState();
    _cartScrollController.addListener(_onCartScroll);
    _checkAuthStatus();
    // Warm store list so delivery fee can show instantly on the delivery step.
    unawaited(DeliveryService.getStoresForFeeEstimate());

    // Disable automatic server sync to prevent quantity override
    // Local cart is now the source of truth
    // Server sync will happen during checkout
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Don't sync immediately - let the protection mechanism handle it
      // Cart items loaded successfully
      _updateScrollHint();
    });
  }

  void _onCartScroll() => _updateScrollHint();

  void _updateScrollHint() {
    if (!mounted || !_cartScrollController.hasClients) return;
    final position = _cartScrollController.position;
    if (!position.hasContentDimensions) return;

    // Only when content actually extends past the viewport (not padding slack).
    final hasScrollableContent = position.maxScrollExtent > 1.0;
    final nearTop = position.pixels <= 8;
    final showHint = hasScrollableContent && nearTop;

    if (hasScrollableContent != _cartListCanScroll ||
        showHint != _showScrollHint) {
      setState(() {
        _cartListCanScroll = hasScrollableContent;
        _showScrollHint = showHint;
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
        if (isLoggedIn) {
          // Clear guest_info_collected flag on login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('guest_info_collected', false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cartScrollController.removeListener(_onCartScroll);
    _cartScrollController.dispose();
    _syncTimer?.cancel();
    addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration, bool isError = false}) {
    AppErrorUtils.showSnack(
      context,
      message,
      isError: isError,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  // Improved helper to get the full product image URL for all possible formats
  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    return ApiConfig.getImageOrStorageUrl(url);
  }

  /// Back from cart: pop when opened on a stack (e.g. product page); otherwise home tab.
  void _handleCartBack() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.home);
  }

  Future<bool> _showGuestReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_id');
    final guestInfoCollected = prefs.getBool('guest_info_collected') ?? false;
    if (guestId != null &&
        guestId.isNotEmpty &&
        !_isLoggedIn &&
        guestInfoCollected) {
      return true;
    }
    return false;
  }

  Future<bool> _confirmRemove(BuildContext context, CartItem item) {
    return showRemoveFromCartDialog(
      context,
      itemName: item.name,
      imageUrl: getImageUrl(item.image),
      price: item.price,
      quantity: item.quantity,
    );
  }

  BoxDecoration _cartCardDecoration({bool selected = true}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _cartGreenBorder : _cartBorder,
        ),
      );

  Widget _buildCartSummaryHeader(CartProvider cart) {
    final count = cart.cartItems.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Your items',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _cartGreenTint,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _cartGreenBorder),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleCartBack();
      },
      child: Consumer2<CartProvider, AuthProvider>(
        builder: (context, cart, auth, child) {
          // Sync local _isLoggedIn with AuthProvider status
          _isLoggedIn = auth.isLoggedIn;
          return Scaffold(
            backgroundColor: _cartBg,
            body: Stack(
              children: [
                Column(
                  children: [
                    // Header + progress steps
                    Container(
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
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header with back button and title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                BackButtonUtils.custom(
                                  onPressed: _handleCartBack,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Shopping Cart',
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
                                'Confirmation'
                              ],
                              activeStep: 1,
                              completedSteps: {1},
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Guest reminder info bar
                    FutureBuilder<bool>(
                      future: _showGuestReminder(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data == true) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _cartGreenTint,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cartGreenBorder),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _cartGreenBorder),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: AppColors.primaryDark,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "You're shopping as a guest.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryDark,
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Log in',
                                      style: GoogleFonts.poppins(fontSize: 10),
                                    ),
                                    onPressed: () async {
                                        // Use named route for login and ensure returnTo is passed
                                        await Navigator.pushNamed(
                                          context,
                                          AppRoutes.signIn,
                                          arguments: {
                                            'returnTo': AppRoutes.cart
                                          },
                                        );

                                        // After returning from login, check if user is now logged in
                                        if (mounted) {
                                          final isNowLoggedIn =
                                              await AuthService.isLoggedIn();
                                          setState(() {
                                            _isLoggedIn = isNowLoggedIn;
                                          });

                                          // Sync AuthProvider so app-wide auth state is correct
                                          try {
                                            await Provider.of<AuthProvider>(
                                                    context,
                                                    listen: false)
                                                .refreshAuthState();
                                          } catch (_) {}

                                          // If user successfully logged in, merge guest cart
                                          if (isNowLoggedIn) {
                                            final userId = await AuthService
                                                .getCurrentUserID();
                                            if (userId != null) {
                                              final cart =
                                                  Provider.of<CartProvider>(
                                                      context,
                                                      listen: false);

                                              // Show quick merging message
                                              showTopSnackBar(
                                                context,
                                                'Merging cart items...',
                                                duration: Duration(seconds: 1),
                                              );

                                              // Fast merge (now non-blocking)
                                              await cart.mergeGuestCartOnLogin(
                                                  userId);

                                              // Show success message
                                              showTopSnackBar(
                                                context,
                                                'Welcome back!',
                                                duration: Duration(seconds: 3),
                                              );

                                              // Refresh the cart display
                                              setState(() {});
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                    Expanded(
                      child: cart.cartItems.isEmpty
                          ? _buildEmptyCart()
                          : _buildScrollableCartList(cart),
                    ),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: cart.cartItems.isEmpty
                ? null
                : CartCheckoutBottomBar(
                    subtotal: cart.calculateSubtotal(),
                    selectedQuantity: cart.selectedItemsCount,
                    selectedLineCount: cart.getSelectedItems().length,
                    totalLineCount: cart.cartItems.length,
                    checkoutButton: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: (cart.isAnyItemUpdating ||
                                cart.getSelectedItems().isEmpty)
                            ? null
                            : () async {
                                    // Fresh check from AuthService to avoid stale state issues
                                    final actuallyLoggedIn =
                                        await AuthService.isLoggedIn();

                                    if (!actuallyLoggedIn) {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final guestId =
                                          prefs.getString('guest_id');
                                      final guestInfoCollected = prefs.getBool(
                                              'guest_info_collected') ??
                                          false;
                                      if ((guestId == null ||
                                              guestId.isEmpty) ||
                                          !guestInfoCollected) {
                                        final result = await showDialog<String>(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (context) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            backgroundColor: Colors.white,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 28),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            18),
                                                    child: Icon(
                                                      Icons
                                                          .shopping_cart_checkout,
                                                      color:
                                                          Colors.green.shade700,
                                                      size: 38,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 18),
                                                  Text(
                                                    'Proceed to Checkout',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    'Please login to continue to checkout, or checkout as a guest.',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.grey,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 24),
                                                  SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Wrap(
                                                      spacing: 12,
                                                      alignment:
                                                          WrapAlignment.center,
                                                      children: [
                                                        OutlinedButton.icon(
                                                          icon: Icon(
                                                            Icons.login,
                                                            color: Colors
                                                                .green.shade700,
                                                            size: 15,
                                                          ),
                                                          label: Text(
                                                            'Login',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .green
                                                                  .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                Colors.green
                                                                    .shade700,
                                                            side: BorderSide(
                                                              color: Colors
                                                                  .green
                                                                  .shade700,
                                                              width: 1.2,
                                                            ),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              vertical: 8,
                                                              horizontal: 16,
                                                            ),
                                                            minimumSize:
                                                                Size(0, 0),
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop('login');
                                                          },
                                                        ),
                                                        ElevatedButton.icon(
                                                          icon: Icon(
                                                            Icons
                                                                .person_outline,
                                                            color: Colors.white,
                                                            size: 15,
                                                          ),
                                                          label: Text(
                                                            'Guest checkout',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors.green
                                                                    .shade700,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              vertical: 8,
                                                              horizontal: 16,
                                                            ),
                                                            minimumSize:
                                                                Size(0, 0),
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                          ),
                                                          onPressed: () async {
                                                            final prefs =
                                                                await SharedPreferences
                                                                    .getInstance();
                                                            String? guestId =
                                                                prefs.getString(
                                                                    'guest_id');
                                                            if (guestId ==
                                                                    null ||
                                                                guestId
                                                                    .isEmpty) {
                                                              // generate guest id
                                                              await AuthService
                                                                  .generateGuestId();
                                                            }
                                                            await prefs.setBool(
                                                                'guest_info_collected',
                                                                true);
                                                            Navigator.of(
                                                                    context)
                                                                .pop('guest');
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                        if (result == 'login') {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  SignInScreen(),
                                            ),
                                          );
                                          // After returning, re-check auth status
                                          final isNowLoggedIn =
                                              await AuthService.isLoggedIn();
                                          setState(() {
                                            _isLoggedIn = isNowLoggedIn;
                                          });
                                          // Sync AuthProvider so delivery/payment pages see correct auth
                                          try {
                                            await Provider.of<AuthProvider>(
                                                    context,
                                                    listen: false)
                                                .refreshAuthState();
                                          } catch (_) {}
                                          // Sync cart with backend after login
                                          if (isNowLoggedIn) {
                                            final userId = await AuthService
                                                .getCurrentUserID();
                                            if (userId != null) {
                                              await Provider.of<CartProvider>(
                                                      context,
                                                      listen: false)
                                                  .mergeGuestCartOnLogin(
                                                      userId);
                                            }
                                            // Don't sync immediately after login - let the protection mechanism handle it
                                            // await Provider.of<CartProvider>(
                                            //         context,
                                            //         listen: false)
                                            //     .syncWithApi();
                                          }
                                          return;
                                        } else if (result == 'guest') {
                                          // Proceed as guest
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const DeliveryPage(),
                                            ),
                                          );
                                          return;
                                        } else {
                                          // Dialog dismissed, do nothing
                                          return;
                                        }
                                      } else {
                                        // guest_id exists and guest info collected, proceed directly
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DeliveryPage(),
                                          ),
                                        );
                                        return;
                                      }
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DeliveryPage(),
                                      ),
                                    );
                                  },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      disabledBackgroundColor:
                                          const Color(0xFFD1D5DB),
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: Colors.white70,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.shopping_cart_checkout_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Checkout',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildScrollableCartList(CartProvider cart) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollHint();
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          _updateScrollHint();
        }
        return false;
      },
      child: Stack(
        children: [
          Scrollbar(
            controller: _cartScrollController,
            thumbVisibility: _cartListCanScroll,
            radius: const Radius.circular(4),
            thickness: 4,
            child: ListView.builder(
              controller: _cartScrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: cart.cartItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildCartSummaryHeader(cart);
                return _buildCartItem(cart, index - 1);
              },
            ),
          ),
          if (_showScrollHint)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _cartBg.withValues(alpha: 0),
                            _cartBg,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: _cartBg,
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Scroll for more items',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cartGreenTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: _cartGreenBorder),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 42,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _cartInk,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Browse products and add items to get started.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _cartMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.home,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(
                    'Start shopping',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(CartProvider cart, int index) {
    final item = cart.cartItems[index];
    final lineTotal = item.price * item.quantity;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      decoration: _cartCardDecoration(selected: item.isSelected),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _cartGreenTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cartGreenBorder.withValues(alpha: 0.7)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CachedNetworkImage(
                  imageUrl: getImageUrl(item.image),
                  fit: BoxFit.contain,
                  memCacheWidth: 120,
                  memCacheHeight: 120,
                  maxWidthDiskCache: 120,
                  maxHeightDiskCache: 120,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (context, url) => Center(
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primary.withValues(alpha: 0.35),
                      size: 18,
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primary.withValues(alpha: 0.35),
                      size: 18,
                    ),
                  ),
                  httpHeaders: const {
                    'User-Agent': 'Mozilla/5.0 (compatible; Flutter)',
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isSelected ? _cartInk : _cartMuted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final confirmed =
                                await _confirmRemove(context, item);
                            if (confirmed) {
                              cart.removeFromCart(
                                item.id,
                                rowIndex: index,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.red.shade400,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'GHS ${item.price.toStringAsFixed(2)} each',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: _cartMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CartQuantityStepper(
                        quantity: item.quantity,
                        onDecrement: () {
                          cart.updateQuantityById(
                            item.id,
                            item.quantity - 1,
                            rowIndex: index,
                          );
                        },
                        onRemoveWhenOne: () async {
                          final confirmed =
                              await _confirmRemove(context, item);
                          if (confirmed) {
                            cart.removeFromCart(
                              item.id,
                              rowIndex: index,
                            );
                          }
                        },
                        onIncrement: () {
                          cart.updateQuantityById(
                            item.id,
                            item.quantity + 1,
                            rowIndex: index,
                          );
                        },
                      ),
                      const Spacer(),
                      Text(
                        'GHS ${lineTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
    );
  }
}
