// pages/clearance_item_detail.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/cart_item.dart';
import 'package:eclapp/models/product_model.dart';
import 'bottomnav.dart';
import '../providers/cart_provider.dart';
import 'package:html/parser.dart' show parse;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'homepage.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/optimized_quantity_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_page_optimization_service.dart';
import '../services/clearance_sale_api_service.dart';
import 'prescription.dart';

class ClearanceItemDetailPage extends StatefulWidget {
  final ClearanceProduct product;

  const ClearanceItemDetailPage({
    super.key,
    required this.product,
  });

  @override
  State<ClearanceItemDetailPage> createState() =>
      _ClearanceItemDetailPageState();
}

class _ClearanceItemDetailPageState extends State<ClearanceItemDetailPage>
    with TickerProviderStateMixin {
  late Future<List<Product>> _relatedProductsFuture;
  int quantity = 1;
  final int maxQuantity = 99;
  final uuid = Uuid();
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;
  final List<String> _productImages = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // Optimization variables
  bool _showSkeleton = true;
  Timer? _skeletonTimer;
  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize optimization service
    _initializeOptimization();

    // Load data with skeleton
    _loadDataWithSkeleton();
  }

  void _initializeOptimization() {
    _optimizationService.trackPagePerformance(
        'clearance_item_detail_${widget.product.id}', 'load');
  }

  void _loadDataWithSkeleton() async {
    _skeletonTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSkeleton = false;
        });
      }
    });

    // Load related products
    _relatedProductsFuture =
        _fetchRelatedProductsWithCache(widget.product.urlName);

    // Simulate loading time
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _showSkeleton = false;
      });
      _optimizationService.stopPagePerformanceTracking(
          'clearance_item_detail_${widget.product.id}', 'load');
    }
  }

  @override
  void dispose() {
    _imagePageController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _skeletonTimer?.cancel();
    super.dispose();
  }

  void _navigateToPrescriptionUpload() async {
    debugPrint('🔍 Navigating to PrescriptionUploadPage...');

    // Get auth token for prescription upload
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Convert ClearanceProduct to Map for prescription page
    final productMap = {
      'id': widget.product.id,
      'name': widget.product.name,
      'price': widget.product.clearancePrice,
      'image': widget.product.thumbnail,
      'batch_no': widget.product.batchNo,
      'url_name': widget.product.urlName,
      'product': {
        'id': widget.product.id,
        'name': widget.product.name,
        'thumbnail': widget.product.thumbnail,
      }
    };

    debugPrint('🔍 Product map created: ${productMap['name']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionUploadPage(
          item: productMap,
          token: token,
        ),
      ),
    );
    debugPrint('🔍 Navigation completed');
  }

  Future<List<Product>> _fetchRelatedProductsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'related_products_$urlName',
      () => fetchRelatedProducts(urlName),
      pageName: 'clearance_item_detail',
    );
    return result ?? [];
  }

  void _addToCartWithQuantity(
      BuildContext context, ClearanceProduct product) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    debugPrint('🔍 ADDING CLEARANCE PRODUCT TO CART ===');
    debugPrint('Product ID: ${product.id}');
    debugPrint('Product Name: ${product.name}');
    debugPrint('Batch Number: ${product.batchNo}');
    debugPrint('Price: ${product.clearancePrice}');
    debugPrint('URL Name: ${product.urlName}');
    debugPrint('Quantity: ${this.quantity}');
    debugPrint('========================');

    try {
      // Ensure a valid image is always set
      final String defaultImage = 'assets/images/default_product.png';
      final String image =
          (product.thumbnail.isNotEmpty) ? product.thumbnail : defaultImage;
      final cartItem = CartItem(
        // Use server cart ID only; start with empty and update after server response
        id: '',
        productId: product.id.toString(),
        originalProductId: product.id.toString(),
        name: product.name,
        price: product.clearancePrice,
        quantity: this.quantity,
        image: image,
        batchNo: product.batchNo,
        urlName: product.urlName,
        totalPrice: product.clearancePrice * this.quantity,
      );

      debugPrint('🔍 CREATED CART ITEM ===');
      debugPrint('Cart Item ID: ${cartItem.id}');
      debugPrint('Cart Item Quantity: ${cartItem.quantity}');
      debugPrint('Cart Item Total Price: ${cartItem.totalPrice}');
      debugPrint('========================');

      // Store the original quantity for the success message
      final originalQuantity = this.quantity;

      // Reset quantity to 1 BEFORE adding to cart
      setState(() {
        quantity = 1;
      });

      debugPrint('✅ Quantity reset to 1 before adding to cart');
      debugPrint('🔍 Current quantity after reset: $quantity');

      cartProvider.addToCart(cartItem);

      if (mounted) {
        await _flyToCartAnimation(context);
        _showSuccessSnackBar(context,
            '${originalQuantity}x ${product.name} has been added to cart');
        _scaleController.forward().then((_) => _scaleController.reverse());
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        String displayMessage;

        if (errorMessage.contains('out of stock') ||
            errorMessage.contains('unavailable') ||
            errorMessage.contains('only has') ||
            errorMessage.contains('units available') ||
            errorMessage.contains('Unable to verify stock')) {
          // Clean up the error message for display
          displayMessage = errorMessage
              .replaceAll('Exception: ', '')
              .replaceAll('Error: ', '')
              .trim();
        } else {
          displayMessage = 'Error adding item to cart. Please try again.';
        }

        _showErrorSnackBar(context, displayMessage);
      }
    }
  }

  Future<void> _flyToCartAnimation(BuildContext context) async {
    final overlay = Overlay.of(context);

    final addToCartBox = context.findRenderObject() as RenderBox?;
    final scaffoldBox =
        Scaffold.maybeOf(context)?.context.findRenderObject() as RenderBox?;

    final start = addToCartBox != null && scaffoldBox != null
        ? addToCartBox.localToGlobal(addToCartBox.size.centerLeft(Offset.zero))
        : Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height - 80);
    final end = Offset(MediaQuery.of(context).size.width - 40, 40);

    final animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    final curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    final tween = Tween<Offset>(begin: start, end: end);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final pos = tween.evaluate(curvedAnimation);
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: Icon(
                Icons.add_shopping_cart,
                color: Colors.green.shade700,
                size: 36,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    overlay.insert(entry);
    await animationController.forward();
    entry.remove();
    animationController.dispose();
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<List<Product>> fetchRelatedProducts(String urlName) async {
    try {
      final response = await http
          .get(
        Uri.parse(ApiConfig.getRelatedProductsUrl(urlName)),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('The request timed out. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data.containsKey('data') && data['data'] is List) {
            return (data['data'] as List)
                .map((item) {
                  try {
                    String otcpom = item['otcpom'] ?? '';
                    if (otcpom.isEmpty) {
                      final cachedProducts = ProductCache.cachedProducts;
                      final matchingProduct = cachedProducts.firstWhere(
                        (product) =>
                            product.urlName ==
                            (item['url_name'] ??
                                item['product']?['url_name'] ??
                                ''),
                        orElse: () => Product(
                          id: 0,
                          name: '',
                          description: '',
                          urlName: '',
                          status: '',
                          price: '0',
                          thumbnail: '',
                          quantity: '',
                          category: '',
                          route: '',
                          batch_no: '',
                        ),
                      );
                      if (matchingProduct.id != 0) {
                        otcpom = matchingProduct.otcpom ?? '';
                      }
                    }

                    return Product(
                      id: item['product_id'] ?? item['id'] ?? 0,
                      name: item['name'] ??
                          item['product_name'] ??
                          (item['product'] != null
                              ? item['product']['name'] ?? ''
                              : ''),
                      description: item['description'] ??
                          (item['product'] != null
                              ? item['product']['description'] ?? ''
                              : ''),
                      urlName: item['url_name'] ??
                          (item['product'] != null
                              ? item['product']['url_name'] ?? ''
                              : ''),
                      status: item['status'] ??
                          (item['product'] != null
                              ? item['product']['status'] ?? ''
                              : ''),
                      batch_no: item['batch_no'] ?? '',
                      price: item['price']?.toString() ?? '0.00',
                      thumbnail: item['thumbnail'] ??
                          item['product_img'] ??
                          (item['product'] != null
                              ? item['product']['thumbnail'] ??
                                  item['product']['product_img'] ??
                                  ''
                              : ''),
                      quantity: item['qty_in_stock']?.toString() ??
                          item['quantity']?.toString() ??
                          '',
                      category: item['category'] ?? '',
                      route: '',
                      otcpom: otcpom,
                      uom: item['uom'] ??
                          item['unit_of_measure'] ??
                          (item['product'] != null
                              ? item['product']['uom'] ??
                                  item['product']['unit_of_measure'] ??
                                  ''
                              : ''),
                    );
                  } catch (e) {
                    return null;
                  }
                })
                .where((product) => product != null)
                .cast<Product>()
                .toList();
          }
          return [];
        } catch (e) {
          return [];
        }
      } else if (response.statusCode == 404) {
        return [];
      } else {
        return [];
      }
    } on TimeoutException {
      return [];
    } on SocketException {
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade600,
                Colors.green.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: BackButtonUtils.withConfirmation(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          title: 'Leave Product',
          message: 'Are you sure you want to leave this product page?',
        ),
        title: Text(
          widget.product.name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: _showSkeleton
          ? _buildLoadingSkeleton()
          : InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Product Image Gallery
                    _buildProductImageGallery(),

                    // Product Info Card
                    _buildProductInfoCard(theme),

                    // Quantity Selector
                    _buildQuantitySelector(),

                    // Action Buttons
                    _buildActionButtons(),

                    // Related Products
                    _buildRelatedProductsSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 140, color: Colors.white),
                  SizedBox(height: 6),
                  Container(height: 22, width: 90, color: Colors.white),
                  SizedBox(height: 12),
                  Container(
                      height: 14, width: double.infinity, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImageGallery() {
    final imageUrls =
        _productImages.isNotEmpty ? _productImages : [widget.product.thumbnail];
    return GestureDetector(
      onTap: () => FullScreenImageViewer.show(
        context,
        imageUrls: imageUrls,
        initialIndex: _currentImageIndex,
      ),
      child: Animate(
        effects: [
          FadeEffect(duration: 400.ms),
          SlideEffect(
              duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
        ],
        child: Container(
          height: 220,
          margin: EdgeInsets.symmetric(vertical: 2),
          child: Stack(
            children: [
              PageView.builder(
                controller: _imagePageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemCount:
                    _productImages.isNotEmpty ? _productImages.length : 1,
                itemBuilder: (context, index) {
                  final imageUrl = _productImages.isNotEmpty
                      ? _productImages[index]
                      : widget.product.thumbnail;

                  return Center(
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Hero(
                          tag:
                              'clearance-product-image-${widget.product.id}-${widget.product.urlName}',
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.green.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.medical_services,
                                      size: 50,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.medical_services,
                                    size: 50,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Image indicators
              if (_productImages.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _productImages.length,
                      (index) => Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index
                              ? Colors.green.shade600
                              : Colors.white.withValues(alpha: 0.5),
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

  Widget _buildProductInfoCard(ThemeData theme) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 100.ms),
        SlideEffect(
            duration: 400.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0),
            delay: 100.ms)
      ],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clearance Sale Badge
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Chip(
                  label: Text(
                    'CLEARANCE SALE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: Colors.green.shade600,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                ),
              ),

              // Product name
              Text(
                widget.product.name,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: 4),

              // Price with discount
              Row(
                children: [
                  Text(
                    'GHS ${widget.product.clearancePrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'GHS ${widget.product.originalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${widget.product.discountPercentage.toStringAsFixed(0)}% OFF',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // Description
              if (widget.product.description.isNotEmpty)
                ProductDescription(description: widget.product.description),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 300.ms),
        SlideEffect(
            duration: 400.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0),
            delay: 300.ms)
      ],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantity',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OptimizedRemoveButton(
                        onPressed: quantity > 1
                            ? () {
                                setState(() {
                                  quantity--;
                                });
                              }
                            : null,
                        isEnabled: quantity > 1,
                        size: 36.0,
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              quantity.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OptimizedAddButton(
                        onPressed: quantity < maxQuantity
                            ? () {
                                setState(() {
                                  quantity++;
                                });
                              }
                            : null,
                        isEnabled: quantity < maxQuantity,
                        size: 36.0,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Total: GHS ${(widget.product.clearancePrice * quantity).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Animate(
        effects: [
          FadeEffect(duration: 400.ms, delay: 400.ms),
          SlideEffect(
              duration: 400.ms,
              begin: Offset(0, 0.1),
              end: Offset(0, 0),
              delay: 400.ms)
        ],
        child: Container(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.product.isPrescribed == true
                        ? [Colors.red.shade600, Colors.red.shade800]
                        : [Colors.green.shade600, Colors.green.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: widget.product.isPrescribed == true
                          ? Colors.red.shade200.withValues(alpha: 0.3)
                          : Colors.green.shade200.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final cartItems = cartProvider.cartItems;

                    final existingItem = cartItems.firstWhere(
                      (item) =>
                          item.name.toLowerCase() ==
                              widget.product.name.toLowerCase() &&
                          item.batchNo == widget.product.batchNo,
                      orElse: () => CartItem(
                        id: '',
                        productId: '',
                        name: '',
                        price: 0.0,
                        quantity: 0,
                        image: '',
                        batchNo: '',
                        urlName: '',
                        totalPrice: 0.0,
                      ),
                    );

                    final isInCart = existingItem.id.isNotEmpty;
                    final cartQuantity = isInCart ? existingItem.quantity : 0;

                    return ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();

                        // Check if product is prescribed
                        if (widget.product.isPrescribed == true) {
                          _navigateToPrescriptionUpload();
                        } else {
                          _addToCartWithQuantity(context, widget.product);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              widget.product.isPrescribed == true
                                  ? Icons.medical_services
                                  : (isInCart
                                      ? Icons.shopping_cart
                                      : Icons.add_shopping_cart),
                              color: Colors.white,
                              size: 16),
                          SizedBox(width: 4),
                          Text(
                            widget.product.isPrescribed == true
                                ? 'Upload Prescription'
                                : (isInCart
                                    ? 'In Cart (${cartQuantity})'
                                    : 'Add to Cart'),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )));
  }

  Widget _buildRelatedProductsSection() {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 500.ms),
        SlideEffect(
            duration: 400.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0),
            delay: 500.ms)
      ],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(
                  bottom: BorderSide(color: Colors.green.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Related Products',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          'You might also like these',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6),
            FutureBuilder<List<Product>>(
              future: _relatedProductsFuture,
              builder: (context, relatedSnapshot) {
                if (relatedSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildRelatedProductsSkeleton();
                }

                if (relatedSnapshot.hasError) {
                  return _buildEmptyState(
                    icon: Icons.error_outline,
                    title: 'Failed to load related products',
                    message: 'Please try again later',
                    color: Colors.green.shade400,
                  );
                }

                final relatedProducts = relatedSnapshot.data ?? [];
                if (relatedProducts.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No related products',
                    message:
                        'We couldn\'t find any related products at the moment',
                    color: Colors.grey.shade400,
                  );
                }

                return SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    itemCount: relatedProducts.length,
                    itemBuilder: (context, index) => _buildRelatedProductCard(
                        relatedProducts[index], context),
                  ),
                );
              },
            ),
            SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSkeleton() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 130,
          margin: EdgeInsets.only(right: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductCard(Product product, BuildContext context) {
    final imageUrl = product.thumbnail.startsWith('http')
        ? product.thumbnail
        : ApiConfig.getProductImageUrl(product.thumbnail);

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClearanceItemDetailPage(
              product: ClearanceProduct(
                id: product.id,
                name: product.name,
                description: product.description,
                urlName: product.urlName,
                status: product.status,
                batchNo: product.batch_no,
                originalPrice: double.tryParse(product.price) ?? 0.0,
                clearancePrice: double.tryParse(product.price) ?? 0.0,
                discountAmount: 0.0,
                discountPercentage: 0.0,
                thumbnail: product.thumbnail,
                quantity: product.quantity,
                category: product.category,
                route: product.route ?? '',
                isPrescribed: (product.otcpom ?? '').toLowerCase() == 'pom',
                otcpom: product.otcpom,
                drug: null,
                wellness: null,
                selfcare: null,
                accessories: null,
              ),
            ),
          ),
        );
      },
      child: Animate(
        effects: [
          ScaleEffect(
            duration: 120.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.03, 1.03),
            curve: Curves.easeOut,
          ),
        ],
        child: Container(
          width: 140,
          margin: EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image section
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                      child: product.thumbnail.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.medical_services,
                                  size: 36,
                                  color: Colors.grey[400],
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.medical_services,
                                size: 36,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                    // Prescribed medicine badge
                    if (product.otcpom?.toLowerCase() == 'pom')
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Prescription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.urlName
                            .replaceAll('-', ' ')
                            .split(' ')
                            .map((word) => word.isNotEmpty
                                ? word[0].toUpperCase() + word.substring(1)
                                : '')
                            .join(' '),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'GHS ${product.price}',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.uom != null && product.uom!.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          'per ${product.uom}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

class ProductDescription extends StatefulWidget {
  final String description;

  const ProductDescription({
    super.key,
    required this.description,
  });

  @override
  State<ProductDescription> createState() => _ProductDescriptionState();
}

class _ProductDescriptionState extends State<ProductDescription> {
  bool isExpanded = false;
  late String _plainDescription;

  @override
  void initState() {
    super.initState();
    _plainDescription = _stripHtmlTags(widget.description);
  }

  String _stripHtmlTags(String html) {
    return parse(html).body?.text.trim() ?? html;
  }

  @override
  Widget build(BuildContext context) {
    final displayContent = !isExpanded && _plainDescription.length > 100
        ? '${_plainDescription.substring(0, 100)}...'
        : _plainDescription;

    if (_plainDescription.isEmpty) {
      return const Text(
        'No description available.',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 13,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayContent,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        if (_plainDescription.length > 100)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 30),
              ),
              onPressed: () => setState(() => isExpanded = !isExpanded),
              child: Text(
                isExpanded ? 'Read Less' : 'Read More',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _buildRelatedProductsSkeleton() {
  return SizedBox(
    height: 160,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 10),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        width: 130,
        margin: EdgeInsets.only(right: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildEmptyState({
  required IconData icon,
  required String title,
  required String message,
  required Color color,
}) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        Icon(icon, size: 36, color: color),
        SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 1),
        Text(
          message,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildRelatedProductCard(Product product, BuildContext context) {
  final imageUrl = product.thumbnail.startsWith('http')
      ? product.thumbnail
      : ApiConfig.getProductImageUrl(product.thumbnail);

  return GestureDetector(
    onTap: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClearanceItemDetailPage(
            product: ClearanceProduct(
              id: product.id,
              name: product.name,
              description: product.description,
              urlName: product.urlName,
              status: product.status,
              batchNo: product.batch_no,
              originalPrice: double.tryParse(product.price) ?? 0.0,
              clearancePrice: double.tryParse(product.price) ?? 0.0,
              discountAmount: 0.0,
              discountPercentage: 0.0,
              thumbnail: product.thumbnail,
              quantity: product.quantity,
              category: product.category,
              route: product.route ?? '',
              isPrescribed: (product.otcpom ?? '').toLowerCase() == 'pom',
              otcpom: product.otcpom,
              drug: null,
              wellness: null,
              selfcare: null,
              accessories: null,
            ),
          ),
        ),
      );
    },
    child: Animate(
      effects: [
        ScaleEffect(
          duration: 120.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10)),
                    child: product.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green.shade600,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.medical_services,
                                size: 36,
                                color: Colors.grey[400],
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.medical_services,
                              size: 36,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  // Prescribed medicine badge
                  if (product.otcpom?.toLowerCase() == 'pom')
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Prescription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.urlName
                          .replaceAll('-', ' ')
                          .split(' ')
                          .map((word) => word.isNotEmpty
                              ? word[0].toUpperCase() + word.substring(1)
                              : '')
                          .join(' '),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'GHS ${product.price}',
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.uom != null && product.uom!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        'per ${product.uom}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  );
}
