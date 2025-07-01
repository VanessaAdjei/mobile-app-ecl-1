// widgets/optimized_item_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../pages/ProductModel.dart';
import '../pages/cartprovider.dart';
import '../pages/CartItem.dart';
import '../services/item_detail_optimization_service.dart';
import '../services/performance_service.dart';
import 'error_display.dart';
import 'loading_skeleton.dart';
import 'performance_monitor.dart';

class OptimizedItemDetailWidget extends StatefulWidget {
  final String urlName;
  final bool isPrescribed;
  final VoidCallback? onBackPressed;
  final VoidCallback? onCartPressed;

  const OptimizedItemDetailWidget({
    super.key,
    required this.urlName,
    this.isPrescribed = false,
    this.onBackPressed,
    this.onCartPressed,
  });

  @override
  State<OptimizedItemDetailWidget> createState() =>
      _OptimizedItemDetailWidgetState();
}

class _OptimizedItemDetailWidgetState extends State<OptimizedItemDetailWidget>
    with TickerProviderStateMixin {
  late final ItemDetailOptimizationService _itemDetailService;
  late final PerformanceService _performanceService;

  late Future<Product> _productFuture;
  late Future<List<Product>> _relatedProductsFuture;
  late Future<List<String>> _imagesFuture;

  int quantity = 1;
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;
  List<String> _productImages = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _quantityController;

  // Loading states
  bool _isLoadingProduct = false;
  bool _isLoadingRelated = false;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();

    _itemDetailService = ItemDetailOptimizationService();
    _performanceService = PerformanceService();

    _imagePageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _quantityController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _initializeData();
  }

  Future<void> _initializeData() async {
    _performanceService.startTimer('item_detail_widget_init');

    try {
      await _itemDetailService.initialize();

      // Load data concurrently
      _productFuture = _itemDetailService.getProductDetails(widget.urlName);
      _relatedProductsFuture =
          _itemDetailService.getRelatedProducts(widget.urlName);
      _imagesFuture = _itemDetailService.getProductImages(widget.urlName);

      // Preload images for better UX
      _itemDetailService.preloadProductImages(context, widget.urlName);

      _performanceService.stopTimer('item_detail_widget_init');
    } catch (e) {
      _performanceService.stopTimer('item_detail_widget_init');
      _performanceService.trackError(
          'item_detail_widget_init_error', e.toString());
    }
  }

  @override
  void dispose() {
    _imagePageController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _productFuture = _itemDetailService.getProductDetails(widget.urlName,
          forceRefresh: true);
      _relatedProductsFuture = _itemDetailService
          .getRelatedProducts(widget.urlName, forceRefresh: true);
      _imagesFuture = _itemDetailService.getProductImages(widget.urlName,
          forceRefresh: true);
    });

    await Future.wait([_productFuture, _relatedProductsFuture, _imagesFuture]);
  }

  void _addToCart(BuildContext context, Product product) async {
    if (_isAddingToCart) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    _performanceService.startTimer('add_to_cart');

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: product.id.toString(),
        name: product.name,
        price: double.tryParse(product.price) ?? 0.0,
        quantity: quantity,
        image: product.thumbnail,
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: (double.tryParse(product.price) ?? 0.0) * quantity,
      );

      cartProvider.addToCart(cartItem);
      _performanceService.trackUserInteraction('product_added_to_cart');

      if (mounted) {
        _showSuccessSnackBar('${product.name} has been added to cart');
        _scaleController.forward().then((_) => _scaleController.reverse());
      }
    } catch (e) {
      _performanceService.trackError('add_to_cart_error', e.toString());
      if (mounted) {
        _showErrorSnackBar('Error adding item to cart: $e');
      }
    } finally {
      _performanceService.stopTimer('add_to_cart');
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _incrementQuantity() {
    if (quantity < 99) {
      setState(() {
        quantity++;
      });
      _quantityController.forward().then((_) => _quantityController.reverse());
    }
  }

  void _decrementQuantity() {
    if (quantity > 1) {
      setState(() {
        quantity--;
      });
      _quantityController.forward().then((_) => _quantityController.reverse());
    }
  }

  void _shareProduct(Product product) {
    final shareText =
        'Check out this product: ${product.name}\nPrice: ${product.price}';
    Share.share(shareText, subject: product.name);
    _performanceService.trackUserInteraction('product_shared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Product>(
          future: _productFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final product = snapshot.data!;
            return SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Gallery
                  _buildProductImageGallery(product),

                  // Product Info Card
                  _buildProductInfoCard(product),

                  // Quantity Selector
                  _buildQuantitySelector(product),

                  // Action Buttons
                  _buildActionButtons(product),

                  // Related Products
                  _buildRelatedProductsSection(product),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.green.shade800,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
      ),
      title: FutureBuilder<Product>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Text(
              snapshot.data!.name,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          }
          return Text(
            'Product Details',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.shopping_cart, color: Colors.white),
          onPressed: widget.onCartPressed,
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return LoadingSkeleton(
      child: Column(
        children: [
          // Image skeleton
          Container(
            height: 240,
            width: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: 16),

          // Product info skeleton
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
                SizedBox(height: 6),
                Container(height: 14, width: 180, color: Colors.white),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Quantity selector skeleton
          Container(
            height: 36,
            width: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          SizedBox(height: 16),

          // Button skeleton
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return ErrorDisplay(
      error: error,
      onRetry: _refreshData,
      onBack: widget.onBackPressed ?? () => Navigator.pop(context),
    );
  }

  Widget _buildProductImageGallery(Product product) {
    return FutureBuilder<List<String>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        final images = snapshot.data ?? [product.thumbnail];

        return Animate(
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
                // Image PageView
                PageView.builder(
                  controller: _imagePageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemCount: images.isNotEmpty ? images.length : 1,
                  itemBuilder: (context, index) {
                    final imageUrl =
                        images.isNotEmpty ? images[index] : product.thumbnail;

                    return Center(
                      child: Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Hero(
                            tag: 'product-image-${product.id}',
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
                if (images.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? Colors.green.shade600
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductInfoCard(Product product) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 100.ms),
        SlideEffect(
            duration: 400.ms,
            delay: 100.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0))
      ],
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              product.name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),

            // Price
            Row(
              children: [
                Text(
                  '₵${product.price}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
                Spacer(),
                if (product.status.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.status.toLowerCase() == 'active'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: product.status.toLowerCase() == 'active'
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // Description
            if (product.description.isNotEmpty) ...[
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                product.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                maxLines: isDescriptionExpanded ? null : 3,
                overflow: isDescriptionExpanded ? null : TextOverflow.ellipsis,
              ),
              if (product.description.length > 100)
                TextButton(
                  onPressed: () {
                    setState(() {
                      isDescriptionExpanded = !isDescriptionExpanded;
                    });
                  },
                  child: Text(
                    isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: GoogleFonts.poppins(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(height: 16),
            ],

            // Product details
            if (product.category.isNotEmpty ||
                product.batch_no.isNotEmpty ||
                product.uom.isNotEmpty) ...[
              Text(
                'Product Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              _buildDetailRow('Category', product.category),
              if (product.batch_no.isNotEmpty)
                _buildDetailRow('Batch Number', product.batch_no),
              if (product.uom.isNotEmpty) _buildDetailRow('Unit', product.uom),
              if (product.quantity.isNotEmpty)
                _buildDetailRow('Stock', product.quantity),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 200.ms),
        SlideEffect(
            duration: 400.ms,
            delay: 200.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0))
      ],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'Quantity:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Spacer(),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _decrementQuantity,
                    icon: Icon(Icons.remove, size: 20),
                    constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Container(
                    width: 50,
                    child: Center(
                      child: Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _incrementQuantity,
                    icon: Icon(Icons.add, size: 20),
                    constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Product product) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: 300.ms),
        SlideEffect(
            duration: 400.ms,
            delay: 300.ms,
            begin: Offset(0, 0.1),
            end: Offset(0, 0))
      ],
      child: Container(
        margin: EdgeInsets.all(16),
        child: Column(
          children: [
            // Add to cart button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    _isAddingToCart ? null : () => _addToCart(context, product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: _isAddingToCart
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Adding...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 12),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: () => _shareProduct(product),
                icon: Icon(Icons.share, size: 20),
                label: Text(
                  'Share Product',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSection(Product product) {
    return FutureBuilder<List<Product>>(
      future: _relatedProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildRelatedProductsSkeleton();
        }

        final relatedProducts = snapshot.data ?? [];
        if (relatedProducts.isEmpty) {
          return SizedBox.shrink();
        }

        return Animate(
          effects: [
            FadeEffect(duration: 400.ms, delay: 400.ms),
            SlideEffect(
                duration: 400.ms,
                delay: 400.ms,
                begin: Offset(0, 0.1),
                end: Offset(0, 0))
          ],
          child: Container(
            margin: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Related Products',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: relatedProducts.length,
                    itemBuilder: (context, index) {
                      final relatedProduct = relatedProducts[index];
                      return Container(
                        width: 150,
                        margin: EdgeInsets.only(right: 12),
                        child: _buildRelatedProductCard(relatedProduct),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRelatedProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OptimizedItemDetailWidget(
              urlName: product.urlName,
              isPrescribed: widget.isPrescribed,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                child: product.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.thumbnail,
                        fit: BoxFit.cover,
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
                            size: 30,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.medical_services,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),

            // Product info
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₵${product.price}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSkeleton() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
