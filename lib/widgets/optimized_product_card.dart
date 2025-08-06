// widgets/optimized_product_card.dart
import 'package:flutter/material.dart';
import '../pages/product_model.dart';
import '../pages/itemdetail.dart';
import '../services/advanced_performance_service.dart';
import '../services/stock_utility_service.dart';

class OptimizedProductCard extends StatefulWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;
  final bool showPrice;
  final bool showName;
  final bool showHero;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const OptimizedProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.showPrice = true,
    this.showName = true,
    this.showHero = true,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<OptimizedProductCard> createState() => _OptimizedProductCardState();
}

class _OptimizedProductCardState extends State<OptimizedProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;

  final AdvancedPerformanceService _performanceService =
      AdvancedPerformanceService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItemPage(
            urlName: widget.product.urlName,
            isPrescribed: widget.product.otcpom?.toLowerCase() == 'pom',
          ),
        ),
      );
    }
  }

  void _onHover(bool isHovered) {
    if (mounted) {
      setState(() {
        _isHovered = isHovered;
      });

      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print product info
    debugPrint('🔍 PRODUCT CARD DEBUG ===');
    debugPrint('Product: ${widget.product.name}');
    debugPrint('Quantity field: "${widget.product.quantity}"');

    debugPrint('========================');

    final fontSize = widget.fontSize ?? 14.0;
    final padding = widget.padding ?? 8.0;
    final imageHeight = widget.imageHeight ?? 120.0;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: GestureDetector(
                onTap: _onTap,
                child: Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: _isHovered ? 0.15 : 0.08),
                        blurRadius: _isHovered ? 8 : 4,
                        offset: Offset(0, _isHovered ? 4 : 2),
                        spreadRadius: _isHovered ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section
                      Expanded(
                        flex: 3,
                        child: Stack(
                          children: [
                            // Product image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: double.infinity,
                                height: imageHeight,
                                child: _performanceService.getOptimizedImage(
                                  imageUrl: _getProductImageUrl(
                                      widget.product.thumbnail),
                                  width: double.infinity,
                                  height: imageHeight,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                  placeholder: (context, url) =>
                                      _buildImagePlaceholder(),
                                  errorWidget: (context, url, error) =>
                                      _buildImageError(),
                                ),
                              ),
                            ),

                            // Prescription badge on card
                            if (widget.product.otcpom?.toLowerCase() == 'pom')
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[600],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'POM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fontSize * 0.6,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                            if (!StockUtilityService.isProductInStock(
                                widget.product.quantity))
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[600],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Out of Stock',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fontSize * 0.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Product name
                      if (widget.showName)
                        Expanded(
                          flex: 1,
                          child: Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSize * 0.8,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),

                      // Price section
                      if (widget.showPrice)
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GHS ${widget.product.price}',
                                style: TextStyle(
                                  fontSize: fontSize * 0.9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              if (StockUtilityService.isProductInStock(
                                  widget.product.quantity))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In Stock',
                                    style: TextStyle(
                                      fontSize: fontSize * 0.5,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  String _getProductImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    if (imagePath.startsWith('/uploads/')) {
      return 'https://adm-ecommerce.ernestchemists.com.gh$imagePath';
    }

    if (imagePath.startsWith('/storage/')) {
      return 'https://eclcommerce.ernestchemists.com.gh$imagePath';
    }

    return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$imagePath';
  }
}

// Optimized product card for homepage with different styling
class OptimizedHomeProductCard extends StatelessWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;
  final bool showPrice;
  final bool showName;
  final bool showHero;
  final VoidCallback? onTap;

  const OptimizedHomeProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.showPrice = true,
    this.showName = true,
    this.showHero = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedProductCard(
      product: product,
      fontSize: fontSize,
      padding: padding,
      imageHeight: imageHeight,
      showPrice: showPrice,
      showName: showName,
      showHero: showHero,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

// Optimized product card for grid layouts
class OptimizedGridProductCard extends StatelessWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;
  final bool showPrice;
  final bool showName;
  final VoidCallback? onTap;

  const OptimizedGridProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.showPrice = true,
    this.showName = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedProductCard(
      product: product,
      fontSize: fontSize,
      padding: padding,
      imageHeight: imageHeight,
      showPrice: showPrice,
      showName: showName,
      showHero: false, // Disable hero animation for grid
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
    );
  }
}
