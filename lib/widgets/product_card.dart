// widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/ProductModel.dart';
import '../pages/itemdetail.dart';

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
                        child: Container(
                          color: Colors.grey[100],
                          child: CachedNetworkImage(
                            imageUrl: getProductImageUrl(product.thumbnail),
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            maxWidthDiskCache: 300,
                            maxHeightDiskCache: 300,
                            fadeInDuration: Duration(milliseconds: 100),
                            fadeOutDuration: Duration(milliseconds: 100),
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
                        imageUrl: getProductImageUrl(productImage),
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
    if (product is Product) {
      return product.name;
    } else if (product is Map<String, dynamic>) {
      return product['name'] ?? 'Unknown Product';
    }
    return 'Unknown Product';
  }

  String _getProductImage() {
    if (product is Product) {
      return product.thumbnail;
    } else if (product is Map<String, dynamic>) {
      return product['thumbnail'] ?? product['image'] ?? '';
    }
    return '';
  }

  String _getProductPrice() {
    if (product is Product) {
      return product.price;
    } else if (product is Map<String, dynamic>) {
      return (product['price'] ?? product['selling_price'] ?? 0).toString();
    }
    return '0';
  }

  bool _isPrescribed() {
    if (product is Product) {
      return product.otcpom?.toLowerCase() == 'pom';
    } else if (product is Map<String, dynamic>) {
      return (product['otcpom'] ?? '').toString().toLowerCase() == 'pom';
    }
    return false;
  }

  String _getUrlName() {
    if (product is Product) {
      return product.urlName;
    } else if (product is Map<String, dynamic>) {
      return product['url_name'] ??
          product['url'] ??
          product['inventory']?['urlname'] ??
          product['route']?.split('/').last ??
          '';
    }
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: product['thumbnail'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 120,
                        memCacheHeight: 120,
                        maxWidthDiskCache: 120,
                        maxHeightDiskCache: 120,
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 100),
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade700,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Favorite button
                  if (showFavoriteButton)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color:
                                isFavorite ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  // Price tag
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'GHS ${_formatPrice(product['price'])}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Unknown Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (product['brand'] != null)
                      Text(
                        product['brand'],
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (product['stock'] != null && product['stock'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'In Stock',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
