// pages/cart.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:eclapp/pages/homepage.dart';
import 'cartprovider.dart';
import 'delivery_page.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_back_button.dart';
import 'auth_service.dart';
import 'signinpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/optimized_quantity_button.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  CartState createState() => CartState();
}

class CartState extends State<Cart> {
  String deliveryOption = 'Delivery';

  String? selectedRegion;
  String? selectedCity;
  String? selectedTown;
  double deliveryFee = 0.00;

  TextEditingController addressController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  Timer? _syncTimer;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    // Disable automatic server sync to prevent quantity override
    // Local cart is now the source of truth
    // Server sync will happen during checkout
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Don't sync immediately - let the protection mechanism handle it
      // Cart items loaded successfully
    });
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
    _syncTimer?.cancel();
    addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration}) {
    final overlay = Overlay.of(context);

    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green[900],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration ?? const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  // Improved helper to get the full product image URL for all possible formats
  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    if (url.startsWith('http')) {
      return url;
    }

    if (url.startsWith('/uploads/')) {
      final fullUrl = 'https://adm-ecommerce.ernestchemists.com.gh$url';

      return fullUrl;
    }

    if (url.startsWith('/storage/')) {
      final fullUrl = 'https://eclcommerce.ernestchemists.com.gh$url';

      return fullUrl;
    }

    // Otherwise, treat as filename
    final fullUrl =
        'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';

    return fullUrl;
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

  Future<bool> _confirmRemove(BuildContext context, String itemName) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 36,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Remove from cart?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    itemName.length > 50 ? '${itemName.substring(0, 50)}...' : itemName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This item will be removed from your cart.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Keep'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // Use a safer navigation approach
          await Future.delayed(Duration(milliseconds: 100));
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
              (route) => false,
            );
          }
        }
      },
      child: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: Stack(
              children: [
                Column(
                  children: [
                    // Enhanced header with better design
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
                                horizontal: 16, vertical: 6),
                            child: Row(
                              children: [
                                BackButtonUtils.simple(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Shopping Cart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
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
                                vertical: 10, horizontal: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildProgressStep("Cart",
                                      isActive: true,
                                      isCompleted: true,
                                      step: 1),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Delivery",
                                      isActive: false,
                                      isCompleted: false,
                                      step: 2),
                                  _buildProgressLine(isActive: false),
                                  _buildProgressStep("Payment",
                                      isActive: false,
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
                    ),
                    // Guest reminder info bar
                    FutureBuilder<bool>(
                      future: _showGuestReminder(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data == true) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: Colors.green.shade100, width: 1.5),
                              ),
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Icon on the left
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.person_outline,
                                          color: Colors.green.shade700,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    // Text in the middle
                                    Expanded(
                                      child: Text(
                                        "You're shopping as a guest.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Login button on the right
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade700,
                                        side: BorderSide(
                                            color: Colors.green.shade400),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        minimumSize: Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        "Log in",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        // Navigate to login screen directly (no loading dialog needed)
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SignInScreen(),
                                            ));

                                        // After returning from login, check if user is now logged in
                                        if (mounted) {
                                          final isNowLoggedIn =
                                              await AuthService.isLoggedIn();
                                          setState(() {
                                            _isLoggedIn = isNowLoggedIn;
                                          });

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
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                    Expanded(
                      child: cart.cartItems.isEmpty
                          ? _buildEmptyCart()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: cart.cartItems.length,
                              itemBuilder: (context, index) =>
                                  _buildCartItem(cart, index),
                            ),
                    ),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order Summary
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (cart.cartItems.length !=
                                    cart.getSelectedItems().length)
                                  Text(
                                    '${cart.getSelectedItems().length} of ${cart.cartItems.length} items selected',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'GHS ${cart.calculateSubtotal().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Checkout Button
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: cart.getSelectedItems().isNotEmpty
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.green.shade700,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade300,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: (cart.isAnyItemUpdating ||
                                    cart.getSelectedItems().isEmpty)
                                ? null
                                : () async {
                                    if (!_isLoggedIn) {
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_checkout,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PROCEED TO CHECKOUT',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 40,
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
            boxShadow: isCompleted || isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 12, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight:
                isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200, width: 2),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Looks like you haven\'t added any items to your cart yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade600,
                      Colors.green.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(),
                        ),
                      );
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Shopping',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildCartItem(CartProvider cart, int index) {
    final item = cart.cartItems[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: item.isSelected ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: item.isSelected
            ? null
            : Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Product Image - Compact Design with Placeholder
            SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: getImageUrl(item.image),
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                  maxWidthDiskCache: 200,
                  maxHeightDiskCache: 200,
                  fadeInDuration: Duration(milliseconds: 300),
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No Image',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  httpHeaders: {
                    'User-Agent': 'Mozilla/5.0 (compatible; Flutter)',
                  },
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isSelected
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Quantity Controls - Compact Design
                  Row(
                    children: [
                      // Quantity selector - fixed width to prevent overflow
                      Container(
                        constraints: BoxConstraints(maxWidth: 110),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Loading indicator when item is being updated
                            if (cart.isItemUpdating(item.id))
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            item.quantity > 1
                                ? OptimizedRemoveButton(
                                    onPressed: cart.isItemUpdating(item.id)
                                        ? null
                                        : () {
                                            debugPrint(
                                                '🔍 Cart: Minus button pressed for ${item.name}');
                                            debugPrint(
                                                '🔍 Cart: Current quantity: ${item.quantity}');
                                            debugPrint(
                                                '🔍 Cart: New quantity will be: ${item.quantity - 1}');
                                            debugPrint(
                                                '🔍 Cart: Item index: $index');
                                            debugPrint(
                                                '🔍 Cart: Item ID: ${item.id}');

                                            // Use item ID instead of index for reliable updates
                                            cart.updateQuantityById(
                                                item.id, item.quantity - 1);
                                          },
                                    isEnabled: !cart.isItemUpdating(item.id),
                                    size: 28.0,
                                  )
                                : OptimizedDeleteButton(
                                    onPressed: () async {
                                      debugPrint(
                                          '🔍 Cart: Delete button pressed for ${item.name}');
                                      final confirmed = await _confirmRemove(
                                          context, item.name);
                                      if (confirmed) {
                                        cart.removeFromCart(item.id);
                                      }
                                    },
                                    isEnabled: true,
                                    size: 28.0,
                                  ),
                            Container(
                              constraints: BoxConstraints(minWidth: 18),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            OptimizedAddButton(
                              onPressed: cart.isItemUpdating(item.id)
                                  ? null
                                  : () {
                                      cart.updateQuantityById(
                                          item.id, item.quantity + 1);
                                    },
                              isEnabled: !cart.isItemUpdating(item.id),
                              size: 28.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Total price - fit content
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Delete button - pushed to end
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final confirmed =
                                await _confirmRemove(context, item.name);
                            if (confirmed) {
                              cart.removeFromCart(item.id);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                              size: 16,
                            ),
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
    );
  }
}
