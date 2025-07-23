// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
// pages/optimized_cart.dart
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
import '../services/universal_page_optimization_service.dart';
import '../widgets/optimized_product_card.dart';
import 'cart_item.dart';

class OptimizedCart extends StatefulWidget {
  const OptimizedCart({super.key});

  @override
  _OptimizedCartState createState() => _OptimizedCartState();
}

class _OptimizedCartState extends State<OptimizedCart> {
  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();

  String deliveryOption = 'Delivery';
  String? selectedRegion;
  String? selectedCity;
  String? selectedTown;
  double deliveryFee = 0.00;

  TextEditingController addressController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  Timer? _syncTimer;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    _optimizationService.trackPagePerformance('cart', 'initialization');

    try {
      // Check auth status and load cart data concurrently
      final futures = await Future.wait([
        _checkAuthStatus(),
        _loadCartData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _optimizationService.getErrorMessage(e);
        });
      }
    } finally {
      _optimizationService.stopPagePerformanceTracking(
          'cart', 'initialization');
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

  Future<void> _loadCartData() async {
    // Cart data is managed by CartProvider, so we just need to ensure it's loaded
    // The optimization service will handle caching and performance monitoring
    await Future.delayed(
        const Duration(milliseconds: 100)); // Allow provider to initialize
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void _showTopSnackBar(BuildContext context, String message,
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
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => overlayEntry.remove(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Timer(duration ?? const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        leading: const AppBackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _optimizationService.buildLoadingWidget(
        message: 'Loading cart...',
      );
    }

    if (_error != null) {
      return _optimizationService.buildErrorWidget(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _initializeCart();
        },
      );
    }

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cartItems = cartProvider.cartItems;
        final totalItems = cartItems.length;

        if (totalItems == 0) {
          return _optimizationService.buildEmptyStateWidget(
            message: 'Your cart is empty',
            icon: Icons.shopping_cart_outlined,
            onAction: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            ),
            actionText: 'Start Shopping',
          );
        }

        return Column(
          children: [
            // Cart items list
            Expanded(
              child: _buildCartItemsList(cartItems, cartProvider),
            ),

            // Cart summary
            _buildCartSummary(cartItems, cartProvider),
          ],
        );
      },
    );
  }

  Widget _buildCartItemsList(
      List<CartItem> cartItems, CartProvider cartProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return _buildCartItemCard(item, cartProvider);
      },
    );
  }

  Widget _buildCartItemCard(CartItem item, CartProvider cartProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _optimizationService.getOptimizedImage(
                  imageUrl: _getProductImageUrl(item.image),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'GHS ${item.price}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Quantity controls
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          final index = cartProvider.cartItems.indexOf(item);
                          if (index != -1) {
                            _optimizationService.debounceOperation(
                              'update_quantity_${item.productId}',
                              () => cartProvider.updateQuantity(
                                  index, item.quantity - 1),
                            );
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 20,
                        color: Colors.grey[600],
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          final index = cartProvider.cartItems.indexOf(item);
                          if (index != -1) {
                            _optimizationService.debounceOperation(
                              'update_quantity_${item.productId}',
                              () => cartProvider.updateQuantity(
                                  index, item.quantity + 1),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 20,
                        color: Colors.green[600],
                      ),

                      const Spacer(),

                      // Remove button
                      IconButton(
                        onPressed: () {
                          _optimizationService.debounceOperation(
                            'remove_item_${item.productId}',
                            () {
                              cartProvider.removeFromCart(item.id);
                              _showTopSnackBar(
                                  context, 'Item removed from cart');
                            },
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                        iconSize: 20,
                        color: Colors.red[600],
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

  Widget _buildCartSummary(
      List<CartItem> cartItems, CartProvider cartProvider) {
    final subtotal = cartItems.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    final total = subtotal + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Delivery option
          Row(
            children: [
              const Text(
                'Delivery Option:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: deliveryOption,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'Delivery', child: Text('Delivery')),
                    DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      deliveryOption = value!;
                      deliveryFee = value == 'Delivery' ? 10.00 : 0.00;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(fontSize: 16)),
              Text('GHS ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Fee:', style: TextStyle(fontSize: 16)),
              Text('GHS ${deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
            ],
          ),

          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'GHS ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Checkout button
          ElevatedButton(
            onPressed: () => _proceedToCheckout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Proceed to Checkout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout() {
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeliveryPage()),
      );
    }
  }

  String _getProductImageUrl(String? imagePath) {
    return _optimizationService.getOptimizedImageUrl(imagePath);
  }
}
