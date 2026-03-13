// widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../models/product_model.dart';
import '../models/product.dart' as models;
import '../services/homepage_optimization_service.dart';
import '../services/stock_utility_service.dart';
import 'wishlist_button.dart';

class HomeProductCard extends StatelessWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;
  final double? cardWidth;
  final bool showPrescriptionBadge;
  final VoidCallback? onTap;
  final bool showPrice;
  final bool showName;
  final bool showHero;
  final bool showWishlistButton;

  const HomeProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.cardWidth,
    this.showPrescriptionBadge = true,
    this.onTap,
    this.showPrice = true,
    this.showName = true,
    this.showHero = true,
    this.showWishlistButton = false,
  });

  // shorten product names so they dont get too long
  String _truncateProductName(String name) {
    if (name.length <= 18) return name;
    return '${name.substring(0, 20)}...';
  }

  @override
  Widget build(BuildContext context) {
    final isInStock = StockUtilityService.isProductInStock(product.quantity);

    if (isInStock) {
    } else {}

    final screenWidth = MediaQuery.of(context).size.width;

    final defaultFontSize =
        fontSize ?? (screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15));

    return Container(
      margin: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  // No boxShadow
                ),
                child: Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onTap ??
                          () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.itemDetail,
                              arguments: {
                                'urlName': product.urlName,
                                'isPrescribed':
                                    product.otcpom?.toLowerCase() == 'pom',
                              },
                            );
                          },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: showHero
                            ? Hero(
                                tag:
                                    'product-image-${product.id}-${product.urlName}',
                                child: Container(
                                  color: Colors.grey[100],
                                  child: CachedNetworkImage(
                                    imageUrl: HomepageOptimizationService()
                                        .getProductImageUrl(product.thumbnail),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    memCacheHeight: 300,
                                    maxWidthDiskCache: 300,
                                    maxHeightDiskCache: 300,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child:
                                            Icon(Icons.broken_image, size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: CachedNetworkImage(
                                  imageUrl: HomepageOptimizationService()
                                      .getProductImageUrl(product.thumbnail),
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  memCacheHeight: 300,
                                  maxWidthDiskCache: 300,
                                  maxHeightDiskCache: 300,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Icon(Icons.broken_image, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (showPrescriptionBadge &&
                        product.otcpom?.toLowerCase() == 'pom')
                      Positioned(
                        bottom: 8,
                        left: 2,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red[700],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Prescription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // stock indicator - only show for out of stock or low stock items
                    // print stuff to help diagnose stock tag issues
                    Builder(
                      builder: (context) {
                        final isOutOfStock =
                            !StockUtilityService.isProductInStock(
                                product.quantity);
                        final isLowStock =
                            StockUtilityService.isLowStock(product.quantity);
                        final shouldShowStockTag = isOutOfStock || isLowStock;

                        if (shouldShowStockTag) {
                          return Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? Colors.red[600]
                                    : Colors.orange[600],
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                isOutOfStock ? 'OUT OF STOCK' : 'LIMITED STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // Wishlist button
                    if (showWishlistButton)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: WishlistButton(
                          product: models.Product(
                            id: product.id,
                            name: product.name,
                            description: product.description,
                            urlName: product.urlName,
                            status: product.status,
                            batchNo: '',
                            price: product.price,
                            thumbnail: product.thumbnail,
                            quantity: product.quantity,
                            category: product.category,
                            route: product.route ?? '',
                            otcpom: product.otcpom ?? '',
                            drug: product.drug ?? '',
                            wellness: product.wellness ?? '',
                            selfcare: product.selfcare ?? '',
                            accessories: product.accessories ?? '',
                          ),
                          size: 14,
                          color: Colors.white,
                          activeColor: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showName)
                    Text(
                      _truncateProductName(product.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: defaultFontSize * 0.8,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  if (showPrice) ...[
                    Text(
                      'GHS ${product.price}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: defaultFontSize * 0.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                      ),
                    ),
                    // removed the old "In Stock" badge from bottom to avoid conflicts
                    SizedBox(height: 15), // Minimal margin after price
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Generic ProductCard for use across different pages
class GenericProductCard extends StatelessWidget {
  final dynamic product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;
  final double? cardWidth;
  final bool showPrescriptionBadge;
  final VoidCallback? onTap;
  final bool showPrice;
  final bool showFavoriteButton;

  const GenericProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.cardWidth,
    this.showPrescriptionBadge = true,
    this.onTap,
    this.showPrice = true,
    this.showFavoriteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultCardWidth =
        cardWidth ?? screenWidth * (screenWidth < 600 ? 0.35 : 0.38);
    final defaultFontSize =
        fontSize ?? (screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15));

    // get product data based on the format
    final String productName = _getProductName();
    final String productImage = _getProductImage();
    final String productPrice = _getProductPrice();
    final bool isPrescribed = _isPrescribed();
    final String urlName = _getUrlName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: defaultCardWidth,
          margin: EdgeInsets.zero, // No margin at all
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero, // No border radius for flush look
            boxShadow: [], // Remove shadow for flush look
          ),
          child: Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.zero,
                onTap: onTap ??
                    () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.itemDetail,
                        arguments: {
                          'urlName': urlName,
                          'isPrescribed': isPrescribed,
                        },
                      );
                    },
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: HomepageOptimizationService()
                            .getProductImageUrl(productImage),
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        maxWidthDiskCache: 200,
                        maxHeightDiskCache: 200,
                        fadeInDuration: Duration(milliseconds: 100),
                        fadeOutDuration: Duration(milliseconds: 100),
                        placeholder: (context, url) => Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(Icons.broken_image, size: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showPrescriptionBadge && isPrescribed)
                Positioned(
                  bottom: 4,
                  left: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(2),
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
        SizedBox(
          width: defaultCardWidth,
          child: Column(
            children: [
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: defaultFontSize * 0.7,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (showPrice)
                Text(
                  'GHS $productPrice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: defaultFontSize * 0.7,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getProductName() {
    if (product is Product) return product.name;
    if (product is Map) return product['name'] ?? '';
    return '';
  }

  String _getProductImage() {
    if (product is Product) return product.thumbnail;
    if (product is Map) return product['thumbnail'] ?? '';
    return '';
  }

  String _getProductPrice() {
    if (product is Product) return product.price.toString();
    if (product is Map) return product['price']?.toString() ?? '';
    return '';
  }

  bool _isPrescribed() {
    if (product is Product) return product.otcpom?.toLowerCase() == 'pom';
    if (product is Map) {
      return (product['otcpom']?.toLowerCase() ?? '') == 'pom';
    }
    return false;
  }

  String _getUrlName() {
    if (product is Product) return product.urlName;
    if (product is Map) return product['urlname'] ?? product['urlName'] ?? '';
    return '';
  }
}

String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return '';
  }

  // If it's already a full URL, return it
  if (url.startsWith('http')) {
    return url;
  }

  return ApiConfig.getProductImageUrl(url);
}

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  String _getProductName() {
    if (product is Product) return product.name;
    if (product is Map) return product['name'] ?? '';
    return '';
  }

  String _getProductImage() {
    if (product is Product) return product.thumbnail;
    if (product is Map) return product['thumbnail'] ?? '';
    return '';
  }

  String _getProductPrice() {
    if (product is Product) return product.price.toString();
    if (product is Map) return product['price']?.toString() ?? '';
    return '';
  }

  bool _isPrescribed() {
    if (product is Product) return product.otcpom?.toLowerCase() == 'pom';
    if (product is Map) {
      return (product['otcpom']?.toLowerCase() ?? '') == 'pom';
    }
    return false;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';

    double? numericPrice;
    if (price is String) {
      numericPrice = double.tryParse(price);
    } else if (price is int) {
      numericPrice = price.toDouble();
    } else if (price is double) {
      numericPrice = price;
    }

    if (numericPrice == null) return '0.00';
    return numericPrice.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        HomepageOptimizationService().getProductImageUrl(_getProductImage());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 7,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image, size: 48, color: Colors.grey[300]),
                    ),
                  ),
                  // prescribed medicine badge
                  if (_isPrescribed())
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Prescription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getProductName(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'GHS ${_formatPrice(_getProductPrice())}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Wishlist button
            if (showFavoriteButton)
              Positioned(
                top: 8,
                right: 8,
                child: WishlistButton(
                  product: product is models.Product
                      ? product
                      : models.Product(
                          id: _getProductId(),
                          name: _getProductName(),
                          description: '',
                          urlName: _getUrlName(),
                          status: '',
                          batchNo: '',
                          price: _getProductPrice(),
                          thumbnail: _getProductImage(),
                          quantity: '',
                          category: '',
                          route: '',
                        ),
                  size: 16,
                  color: Colors.white,
                  activeColor: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getProductId() {
    if (product is Product) return product.id;
    if (product is Map) return product['id'] ?? 0;
    return 0;
  }

  String _getUrlName() {
    if (product is Product) return product.urlName;
    if (product is Map) return product['urlname'] ?? product['urlName'] ?? '';
    return '';
  }
}
