// pages/cart.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eclapp/pages/homepage.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'delivery_page.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:core';
import 'AppBackButton.dart';
import 'auth_service.dart';
import 'signinpage.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  String deliveryOption = 'Delivery';

  String? selectedRegion;
  String? selectedCity;
  String? selectedTown;
  double deliveryFee = 0.00;

  TextEditingController addressController = TextEditingController();
  TextEditingController _promoController = TextEditingController();

  Timer? _syncTimer;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    // Initial sync with server
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cart = Provider.of<CartProvider>(context, listen: false);
      await cart.syncWithApi();

      // Log cart items after sync
      for (var item in cart.cartItems) {}
    });

    // Start periodic sync every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        Provider.of<CartProvider>(context, listen: false).syncWithApi();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
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
                  color: Colors.black.withOpacity(0.1),
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

  Map<String, Map<String, Map<String, double>>> locationFees = {
    'Greater Accra': {
      'Accra': {'Madina': 0.00, 'Osu': 0.50},
      'Tema': {'Community 1': 0.00, 'Community 2': 0.00},
    },
    'Ashanti': {
      'Kumasi': {'Adum': 0.50, 'Asokwa': 0.50, 'Ahodwo': 0.00},
      'Ejisu': {'Ejisu Town': 0.00, 'Besease': 0.50},
    },
    'Western': {
      'Takoradi': {'Market Circle': 0.00, 'Anaji': 0.00, 'Effia': 0.00},
    },
  };

  List<String> regions = ['Greater Accra', 'Ashanti', 'Western'];
  Map<String, List<String>> cities = {
    'Greater Accra': ['Accra', 'Tema'],
    'Ashanti': ['Kumasi'],
    'Western': ['Takoradi'],
  };

  Map<String, List<String>> towns = {
    'Accra': ['Madina', 'Osu'],
    'Tema': ['Community 1', 'Community 2'],
    'Kumasi': ['Adum', 'Asokwa'],
    'Takoradi': ['Market Circle', 'Anaji'],
  };

  List<String> pickupLocations = ['Site 1', 'Site 2', 'Site 3', 'Site 4'];

  // Improved helper to get the full product image URL for all possible formats
  String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$url';
    }
    if (url.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$url';
    }
    // Otherwise, treat as filename
    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer<CartProvider>(
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
                          color: Colors.black.withOpacity(0.15),
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
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              AppBackButton(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                onPressed: () {
                                  debugPrint("Back tapped");
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => HomePage()),
                                    );
                                  }
                                },
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Shopping Cart',
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
                              vertical: 16, horizontal: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildProgressStep("Cart",
                                    isActive: true, isCompleted: true, step: 1),
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
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'GHS ${cart.calculateSubtotal().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Checkout Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: cart.cartItems.isNotEmpty
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
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: cart.cartItems.isEmpty
                              ? null
                              : () async {
                                  if (!_isLoggedIn) {
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 28),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(18),
                                                child: Icon(
                                                  Icons.shopping_cart_checkout,
                                                  color: Colors.green.shade700,
                                                  size: 38,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Proceed to Checkout',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Would you like to continue as a guest or login for a faster checkout experience?',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 24),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  ElevatedButton.icon(
                                                    icon: Icon(
                                                      Icons.person_outline,
                                                      size: 15,
                                                    ),
                                                    label: Text(
                                                      'Guest Checkout',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 0.1,
                                                      ),
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.green.shade700,
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 1,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 8,
                                                        horizontal: 16,
                                                      ),
                                                      minimumSize: Size(0, 0),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      shadowColor:
                                                          Colors.transparent,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop('guest');
                                                    },
                                                  ),
                                                  const SizedBox(width: 10),
                                                  OutlinedButton.icon(
                                                    icon: Icon(
                                                      Icons.login,
                                                      color:
                                                          Colors.green.shade700,
                                                      size: 15,
                                                    ),
                                                    label: Text(
                                                      'Login',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .green.shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          Colors.green.shade700,
                                                      side: BorderSide(
                                                        color: Colors
                                                            .green.shade700,
                                                        width: 1.2,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 8,
                                                        horizontal: 16,
                                                      ),
                                                      minimumSize: Size(0, 0),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop('login');
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                    if (result == 'guest') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const DeliveryPage(),
                                        ),
                                      );
                                    } else if (result == 'login') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SignInScreen(),
                                        ),
                                      );
                                      // After returning, re-check auth status
                                      final isNowLoggedIn =
                                          await AuthService.isLoggedIn();
                                      setState(() {
                                        _isLoggedIn = isNowLoggedIn;
                                      });
                                    }
                                    return;
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_checkout,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PROCEED TO CHECKOUT',
                                  style: const TextStyle(
                                    fontSize: 15,
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
    );
  }

  Widget _buildProgressLine({required bool isActive}) {
    return Container(
      width: 50,
      height: 1,
      color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
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
            boxShadow: isCompleted || isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
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
            fontSize: 9,
            fontWeight:
                isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Looks like you haven\'t added any items to your cart yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
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
                    color: Colors.green.withOpacity(0.3),
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
    );
  }

  Widget _buildCartItem(CartProvider cart, int index) {
    final item = cart.cartItems[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Product Image - Compact Design
            Container(
              width: 50,
              height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: getImageUrl(item.image),
                  fit: BoxFit.cover,
                  memCacheWidth: 100, // 2x for high DPI
                  memCacheHeight: 100,
                  maxWidthDiskCache: 100,
                  maxHeightDiskCache: 100,
                  fadeInDuration: Duration(milliseconds: 200),
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.shade600),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.image_not_supported,
                        color: Colors.grey.shade400, size: 20),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'GHS ${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Quantity Controls - Compact Design
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  if (item.quantity > 1) {
                                    cart.updateQuantity(
                                        index, item.quantity - 1);
                                  } else {
                                    cart.removeFromCart(item.id);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    item.quantity > 1
                                        ? Icons.remove
                                        : Icons.delete_outline,
                                    size: 14,
                                    color: item.quantity > 1
                                        ? Colors.grey.shade700
                                        : Colors.red.shade400,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  cart.updateQuantity(index, item.quantity + 1);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
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
