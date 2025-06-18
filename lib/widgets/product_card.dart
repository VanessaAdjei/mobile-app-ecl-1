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

  const HomeProductCard({
    Key? key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
    this.cardWidth,
    this.showPrescriptionBadge = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultCardWidth =
        cardWidth ?? screenWidth * (screenWidth < 600 ? 0.35 : 0.38);
    final defaultFontSize =
        fontSize ?? (screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Card is only the image (square) - more compact
        Container(
          width: defaultCardWidth,
          margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.008, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
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
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: getProductImageUrl(product.thumbnail),
                        fit: BoxFit.cover,
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
              ),
              if (showPrescriptionBadge &&
                  product.otcpom?.toLowerCase() == 'pom')
                Positioned(
                  bottom: 8,
                  left: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
        // Name and price beneath the card - minimal spacing
        SizedBox(
          width: defaultCardWidth,
          child: Column(
            children: [
              const SizedBox(height: 1),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: defaultFontSize * 0.95,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'GHS ${product.price}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: defaultFontSize * 0.95,
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
          margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.008, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap ??
                    () {
                      if (urlName.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemPage(
                              urlName: urlName,
                              isPrescribed: isPrescribed,
                            ),
                          ),
                        );
                      }
                    },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: getProductImageUrl(productImage),
                        fit: BoxFit.cover,
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
              ),
              if (showPrescriptionBadge && isPrescribed)
                Positioned(
                  bottom: 8,
                  left: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
              if (showFavoriteButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: Colors.grey[600],
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
              const SizedBox(height: 1),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: defaultFontSize * 0.95,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (showPrice && productPrice.isNotEmpty)
                Text(
                  'GHS $productPrice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: defaultFontSize * 0.95,
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
          product['inventory']?['urlname'] ??
          product['route']?.split('/').last ??
          '';
    }
    return '';
  }
}

String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    print('Empty or null URL provided');
    return '';
  }

  // If it's already a full URL, return it
  if (url.startsWith('http')) {
    print('Full URL provided: $url');
    return url;
  }

  // Use the correct path 'product' (singular) instead of 'products'
  final finalUrl =
      'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  print('Original URL: $url');
  print('Final URL: $finalUrl');
  return finalUrl;
}
