// widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/ProductModel.dart';
import '../pages/itemdetail.dart';
import '../services/homepage_optimization_service.dart';

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

  const HomeProductCard({
    Key? key,
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
  }) : super(key: key);

  // Truncate product names to keep them short
  String _truncateProductName(String name) {
    if (name.length <= 18) return name;
    return name.substring(0, 20) + '...';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultCardWidth =
        cardWidth ?? screenWidth * (screenWidth < 600 ? 0.35 : 0.38);
    final defaultFontSize =
        fontSize ?? (screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15));

    return Container(
      margin: EdgeInsets.zero, // No margin at all
      child: AspectRatio(
        aspectRatio: 10.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemPage(
                                  urlName: product.urlName,
                                  isPrescribed:
                                      product.otcpom?.toLowerCase() == 'pom',
                                ),
                              ),
                            );
                          },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: showHero
                            ? Hero(
                                tag: 'product-image-${product.id}-${product.urlName}',
                                child: Container(
                                  color: Colors.grey[100],
                                  child: CachedNetworkImage(
                                    imageUrl: HomepageOptimizationService().getProductImageUrl(product.thumbnail),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    memCacheHeight: 300,
                                    maxWidthDiskCache: 300,
                                    maxHeightDiskCache: 300,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(strokeWidth: 1),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Icon(Icons.broken_image, size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: CachedNetworkImage(
                                  imageUrl: HomepageOptimizationService().getProductImageUrl(product.thumbnail),
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  memCacheHeight: 300,
                                  maxWidthDiskCache: 300,
                                  maxHeightDiskCache: 300,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(strokeWidth: 1),
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
                            'Prescribed',
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
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
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
                    SizedBox(height: 15), // Small margin after price
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
    Key? key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.cardWidth,
    this.showPrescriptionBadge = true,
    this.onTap,
    this.showPrice = true,
    this.showFavoriteButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultCardWidth =
        cardWidth ?? screenWidth * (screenWidth < 600 ? 0.35 : 0.38);
    final defaultFontSize =
        fontSize ?? (screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15));

    // Extract product data based on the format
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemPage(
                            urlName: urlName,
                            isPrescribed: isPrescribed,
                          ),
                        ),
                      );
                    },
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: HomepageOptimizationService().getProductImageUrl(productImage),
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
                      'Prescribed',
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
    if (product is Map) return (product['otcpom']?.toLowerCase() ?? '') == 'pom';
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

  // Use the correct path 'product' (singular) instead of 'products'
  final finalUrl =
      'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  return finalUrl;
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

  String? _getProductBrand() {
    // No longer needed, but keep for compatibility if referenced elsewhere
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = HomepageOptimizationService().getProductImageUrl(_getProductImage());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.image, size: 48, color: Colors.grey[300]),
                ),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
          ],
        ),
      ),
    );
  }
}
