// pages/itemdetail.dart
import 'package:eclapp/pages/prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../models/cart_item.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/config/api_config.dart';
import '../config/app_colors.dart';
import 'package:eclapp/utils/product_image_url.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/services/auth_service.dart';
import 'bottomnav.dart';
import '../providers/cart_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/optimized_quantity_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_page_optimization_service.dart';

import 'homepage.dart';

/// CMS filenames often embed unix time `.../product/_1699123456_Name.png` — newer first
/// surfaces the current photo when the API still lists an older/broken file first.
int? _uploadEpochFromImageUrl(String url) {
  final m = RegExp(r'_(\d{10,13})_').firstMatch(url);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

bool _looksLikePlaceholderImageUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('placeholder') ||
      u.contains('no-image') ||
      u.contains('no_image') ||
      u.contains('default_product') ||
      u.contains('image-not-available') ||
      u.contains('/0.png') ||
      u.contains('/0.jpg');
}

/// Prefer real uploads and newer files; push placeholder-like URLs to the end.
List<String> orderProductGalleryUrlsForDisplay(List<String> urls) {
  if (urls.length < 2) return urls;
  final copy = List<String>.from(urls);
  copy.sort((a, b) {
    final pa = _looksLikePlaceholderImageUrl(a);
    final pb = _looksLikePlaceholderImageUrl(b);
    if (pa != pb) return pa ? 1 : -1;
    final ea = _uploadEpochFromImageUrl(a);
    final eb = _uploadEpochFromImageUrl(b);
    if (ea != null && eb != null && ea != eb) return eb.compareTo(ea);
    if (ea != null && eb == null) return -1;
    if (ea == null && eb != null) return 1;
    return 0;
  });
  return copy;
}

/// Builds absolute image URLs from product `images` array and inventory fallbacks.
List<String> _extractResolvedProductGalleryUrls(
  dynamic imagesField,
  Map<String, dynamic> inventoryData,
) {
  final out = <String>[];
  void push(dynamic raw) {
    final coerced = coerceProductImageSource(raw);
    if (coerced.isEmpty) return;
    final url = ApiConfig.getProductImageUrl(coerced);
    if (url.isNotEmpty && !out.contains(url)) out.add(url);
  }

  if (imagesField is List) {
    final mapItems = <Map<String, dynamic>>[];
    final otherItems = <dynamic>[];
    for (final item in imagesField) {
      if (item is Map) {
        mapItems.add(Map<String, dynamic>.from(item));
      } else {
        otherItems.add(item);
      }
    }
    bool isPrimary(Map<String, dynamic> m) {
      return m['is_primary'] == true ||
          m['primary'] == true ||
          m['is_default'] == true ||
          m['default'] == true;
    }

    int mapImageId(Map<String, dynamic> m) {
      final v = m['id'] ?? m['image_id'] ?? m['media_id'];
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    mapItems.sort((a, b) {
      final pa = isPrimary(a);
      final pb = isPrimary(b);
      if (pa != pb) return pa ? -1 : 1;
      final ida = mapImageId(a);
      final idb = mapImageId(b);
      if (ida != idb) return idb.compareTo(ida);
      final urlA = (a['url'] ?? a['src'] ?? '').toString();
      final urlB = (b['url'] ?? b['src'] ?? '').toString();
      final ea = _uploadEpochFromImageUrl(urlA);
      final eb = _uploadEpochFromImageUrl(urlB);
      if (ea != null && eb != null && ea != eb) return eb.compareTo(ea);
      return 0;
    });
    for (final m in mapItems) {
      push(m);
    }
    for (final item in otherItems) {
      push(item);
    }
  }
  if (out.isEmpty) {
    push(inventoryData['image']);
    push(inventoryData['thumbnail']);
    push(inventoryData['product_img']);
  }
  return orderProductGalleryUrlsForDisplay(out);
}

/// When [imagesField] is not a list, still try product-level image keys.
List<String> _galleryUrlsFromProductAndInventory(
  Map<String, dynamic> productData,
  Map<String, dynamic> inventoryData,
) {
  final fromList =
      _extractResolvedProductGalleryUrls(productData['images'], inventoryData);
  if (fromList.isNotEmpty) return fromList;
  final out = <String>[];
  void push(dynamic raw) {
    final coerced = coerceProductImageSource(raw);
    if (coerced.isEmpty) return;
    final url = ApiConfig.getProductImageUrl(coerced);
    if (url.isNotEmpty && !out.contains(url)) out.add(url);
  }

  push(productData['thumbnail']);
  push(productData['image']);
  push(productData['product_img']);
  push(inventoryData['image']);
  push(inventoryData['thumbnail']);
  push(inventoryData['product_img']);
  return orderProductGalleryUrlsForDisplay(out);
}

class ItemPage extends StatefulWidget {
  final String urlName;
  final bool isPrescribed;

  const ItemPage({
    super.key,
    required this.urlName,
    this.isPrescribed = false,
  });

  @override
  State<ItemPage> createState() => ItemPageState();
}

class ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  late Future<Product> _productFuture;
  late Future<List<Product>> _relatedProductsFuture;
  int quantity = 1;
  final int maxQuantity = 99; // Maximum quantity limit
  final uuid = Uuid();
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;

  /// When image URLs change (refresh / new product), reset [PageView] off a stale page index.
  String _appliedGallerySig = '';

  // controllers for animations
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // Debouncing for quantity buttons to prevent spam clicking
  DateTime? _lastQuantityUpdateTime;
  static const Duration _quantityUpdateCooldown = Duration(milliseconds: 500);

  // stuff for making things faster
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

    // set up the optimization service
    _initializeOptimization();

    // load data at the same time, show skeleton for a bit
    _loadDataWithSkeleton();
  }

  void _initializeOptimization() {
    // start tracking how fast this page loads
    _optimizationService.trackPagePerformance(
        'item_detail_${widget.urlName}', 'load');
  }

  void _loadDataWithSkeleton() async {
    // show skeleton for at least 800ms
    _skeletonTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSkeleton = false;
        });
      }
    });

    // load data at the same time
    _productFuture = _fetchProductDetailsWithCache(widget.urlName);
    _relatedProductsFuture = _fetchRelatedProductsWithCache(widget.urlName);

    // wait for both to finish
    try {
      await Future.wait([_productFuture, _relatedProductsFuture]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    // make sure skeleton showed for at least 800ms
    if (_skeletonTimer?.isActive == true) {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (mounted) {
      setState(() {
        _showSkeleton = false;
      });

      // stop tracking performance
      _optimizationService.stopPagePerformanceTracking(
          'item_detail_${widget.urlName}', 'load');
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

  Future<Product> _fetchProductDetailsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'product_details_$urlName',
      () => fetchProductDetails(urlName),
      pageName: 'item_detail',
    );
    return result ??
        Product(
          id: 0,
          name: 'Product not found',
          description: '',
          urlName: urlName,
          status: '',
          price: '0.00',
          thumbnail: '',
          quantity: '',
          category: '',
          route: '',
          batch_no: '',
          uom: '',
        );
  }

  Future<List<Product>> _fetchRelatedProductsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'related_products_$urlName',
      () => fetchRelatedProducts(urlName),
      pageName: 'item_detail',
    );
    return result ?? [];
  }

  void _addToCartWithQuantity(BuildContext context, Product product) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

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
        price: double.tryParse(product.price) ?? 0.0,
        quantity: this.quantity,
        image: image,
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: (double.tryParse(product.price) ?? 0.0) * this.quantity,
      );

      // reset quantity to 1 before adding to cart
      setState(() {
        quantity = 1;
      });

      cartProvider.addToCart(cartItem);

      if (context.mounted) {
        await _flyToCartAnimation(context);
        if (context.mounted) {
          _scaleController.forward().then((_) => _scaleController.reverse());
        }
      }
    } catch (e) {
      if (context.mounted) {
        // check if the error is about stock/quantity
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

    // find where the add to cart button and cart icon are on screen
    final addToCartBox = context.findRenderObject() as RenderBox?;
    final scaffoldBox =
        Scaffold.maybeOf(context)?.context.findRenderObject() as RenderBox?;

    // if we cant find them, just use center bottom and top right
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
        backgroundColor: Colors.red.shade600,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<Product> fetchProductDetails(String urlName) async {
    try {
      final response = await http
          .get(
        Uri.parse(ApiConfig.getProductDetailsUrl(urlName)),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('The request timed out. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data.containsKey('data')) {
            final productData = data['data']['product'] ?? {};
            final inventoryData = data['data']['inventory'] ?? {};

            if (productData.isEmpty || inventoryData.isEmpty) {
              throw Exception('Product data is incomplete or missing');
            }

            // get the product id from wherever it is in the response
            final productId = productData['product_id'] ??
                productData['id'] ??
                inventoryData['product_id'] ??
                inventoryData['id'] ??
                inventoryData['inventory_id'] ??
                0;

            if (productId == 0) {
              throw Exception('Invalid product ID');
            }

            // check everywhere the otcpom might be
            String otcpom = productData['otcpom'] ??
                inventoryData['otcpom'] ??
                productData['route'] ??
                inventoryData['route'] ??
                '';

            // if we cant find otcpom in the api response, try getting it from cached products
            if (otcpom.isEmpty) {
              final cachedProducts = ProductCache.cachedProducts;
              final matchingProduct = cachedProducts.firstWhere(
                (product) => product.urlName == inventoryData['url_name'],
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

            // get the unit of measure from wherever it might be
            final uom = productData['uom'] ??
                inventoryData['uom'] ??
                productData['unit_of_measure'] ??
                inventoryData['unit_of_measure'] ??
                '';

            List<String> tags = [];
            if (productData['tags'] != null && productData['tags'] is List) {
              tags = List<String>.from(
                  productData['tags'].map((tag) => tag.toString()));
            }

            final invMap = inventoryData is Map<String, dynamic>
                ? inventoryData
                : <String, dynamic>{};
            final prodMap = productData is Map<String, dynamic>
                ? productData
                : <String, dynamic>{};
            final galleryUrls =
                _galleryUrlsFromProductAndInventory(prodMap, invMap);

            final extractedName =
                _extractProductName(inventoryData['url_name'] ?? '');

            final product = Product.fromJson({
              'id': productId,
              'name': extractedName,
              'description': productData['description'] ?? '',
              'url_name': inventoryData['url_name'] ?? '',
              'status': inventoryData['status'] ?? '',
              'price': inventoryData['price']?.toString() ?? '0.00',
              'thumbnail': galleryUrls.isNotEmpty ? galleryUrls.first : '',
              'gallery_images': galleryUrls,
              'tags': tags,
              'quantity': inventoryData['stock']?.toString() ?? '',
              'category': (productData['categories'] != null &&
                      productData['categories'].isNotEmpty)
                  ? productData['categories'][0]['description'] ?? ''
                  : '',
              'otcpom': otcpom,
              'route': productData['route'] ?? '',
              'batch_no': inventoryData['batch_no'] ?? '',
              'uom': uom,
            });

            if (kDebugMode) {
              debugPrint(
                'item_detail: loaded "$urlName" → "${product.name}" (${product.price})',
              );
            }

            return product;
          } else {
            throw Exception('Invalid response format: missing data field');
          }
        } catch (e) {
          throw Exception('Failed to parse product data: $e');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Product not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error occurred. Please try again later.');
      } else {
        throw Exception(
            'Failed to load product details: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your internet connection and try again.');
    } on SocketException {
      throw Exception(
          'No internet connection. Please check your network settings.');
    } catch (e) {
      throw Exception('Could not load product: $e');
    }
  }

  // get a clean product name from the url name
  String _extractProductName(String urlName) {
    if (urlName.isEmpty) return 'Unknown Product';

    // remove common suffixes that arent part of the name
    String cleanName = urlName;

    // remove random letter/number suffixes (like a8cfddbcd6)
    cleanName = cleanName.replaceAll(RegExp(r'-[a-f0-9]{8,}$'), '');

    // remove numbers at the end that arent part of the name
    cleanName = cleanName.replaceAll(RegExp(r'-\d+$'), '');

    // turn kebab-case into title case
    final finalName = cleanName
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');

    return finalName;
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
                    // try to get otcpom from cached products if not in api response
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

  /// Titles for [EclExpandableSliverAppBar] (toolbar / hero / subtitle).
  void _itemPageHeaderCopy(
    AsyncSnapshot<Product> snapshot, {
    required void Function(String toolbar, String hero, String? subtitle) out,
  }) {
    if (snapshot.hasError) {
      out('Product', 'Product', 'Couldn\'t load details');
      return;
    }
    if (snapshot.hasData) {
      final p = snapshot.data!;
      final full = p.name.trim();
      final name = full.isEmpty ? 'Product' : full;
      const maxToolbar = 28;
      final line =
          name.length > maxToolbar ? '${name.substring(0, maxToolbar)}…' : name;
      // Same string for toolbar + hero so the bar never shows a second title line.
      out(line, line, null);
      return;
    }
    out('Product', 'Product', 'Loading details…');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE5EDE8),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _productFuture = _fetchProductDetailsWithCache(widget.urlName);
            _relatedProductsFuture =
                _fetchRelatedProductsWithCache(widget.urlName);
          });
          await _productFuture;
          await _relatedProductsFuture;
        },
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: FutureBuilder<Product>(
          future: _productFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError && kDebugMode) {
              debugPrint('item_detail FutureBuilder: ${snapshot.error}');
            }

            var toolbarT = 'Product';
            var heroT = 'Product';
            String? subtitleT = 'Loading details…';
            _itemPageHeaderCopy(
              snapshot,
              out: (t, h, s) {
                toolbarT = t;
                heroT = h;
                subtitleT = s;
              },
            );

            late final Widget bodySliver;
            if (snapshot.hasError) {
              bodySliver = SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(snapshot.error.toString()),
              );
            } else if (!snapshot.hasData) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                bodySliver = SliverToBoxAdapter(child: _buildLoadingSkeleton());
              } else {
                bodySliver = SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState('No product data available'),
                );
              }
            } else if (_showSkeleton) {
              bodySliver = SliverToBoxAdapter(child: _buildLoadingSkeleton());
            } else {
              final product = snapshot.data!;
              bodySliver = SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductImageGallery(product),
                    _buildProductInfoCard(product, theme),
                    _buildActionButtons(product),
                    _buildQuantitySelector(product),
                    _buildRelatedProductsSection(product),
                  ],
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                EclExpandableSliverAppBar(
                  toolbarTitle: toolbarT,
                  heroTitle: heroT,
                  heroSubtitle: subtitleT,
                  centerTitle: false,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: BackButtonUtils.withConfirmation(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      title: 'Leave Product',
                      message:
                          'Are you sure you want to leave this product page?',
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CartIconButton(
                          iconColor: Colors.white,
                          iconSize: 22,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 8),
                  sliver: bodySliver,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // image skeleton
            Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(height: 8),

            // product info skeleton
            Container(
              padding: EdgeInsets.all(8),
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

            SizedBox(height: 8),

            // quantity selector skeleton
            Container(
              height: 36,
              width: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            SizedBox(height: 16),

            // button skeleton
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
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(error),
              size: 56,
              color: _getErrorColor(error),
            ),
            SizedBox(height: 12),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              _getErrorMessage(error),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _productFuture =
                          _fetchProductDetailsWithCache(widget.urlName);
                      _relatedProductsFuture =
                          _fetchRelatedProductsWithCache(widget.urlName);
                    });
                  },
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 18),
                  label: Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  /// Absolute URLs for gallery + single thumbnail fallback.
  List<String> _resolvedGalleryUrls(Product product) {
    final fromGallery = orderProductGalleryUrlsForDisplay(
      product.galleryImages
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => ApiConfig.getProductImageUrl(e))
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    if (fromGallery.isNotEmpty) return fromGallery;
    final t = product.thumbnail.trim();
    if (t.isEmpty) return <String>[];
    final u = ApiConfig.getProductImageUrl(t);
    return u.isEmpty ? <String>[] : [u];
  }

  Widget _buildProductImageGallery(Product product) {
    final imageUrls = _resolvedGalleryUrls(product);
    final gallerySig = '${product.id}|${imageUrls.join('\x1E')}';
    if (_appliedGallerySig != gallerySig) {
      _appliedGallerySig = gallerySig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_imagePageController?.hasClients ?? false) {
          _imagePageController!.jumpToPage(0);
        }
        if (_currentImageIndex != 0) {
          setState(() => _currentImageIndex = 0);
        }
      });
    }

    return GestureDetector(
      onTap: imageUrls.isEmpty
          ? null
          : () => FullScreenImageViewer.show(
                context,
                imageUrls: imageUrls,
                initialIndex: _currentImageIndex.clamp(0, imageUrls.length - 1),
              ),
      child: Animate(
        effects: [
          FadeEffect(duration: 400.ms),
        ],
        child: Container(
          height: 220,
          margin: EdgeInsets.symmetric(vertical: 2),
          child: Stack(
            children: [
              // image pageview
              PageView.builder(
                controller: _imagePageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = imageUrls.isEmpty ? '' : imageUrls[index];

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
                          tag: 'product-image-${product.id}-${product.urlName}',
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

              // image indicators (dots)
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      imageUrls.length,
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

  Widget _buildProductInfoCard(Product product, ThemeData theme) {
    final isPrescription =
        widget.isPrescribed || product.otcpom?.toLowerCase() == 'pom';

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
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrescription
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isPrescription
                  ? Colors.red.shade100
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prescription badge and category
              Row(
                children: [
                  if (isPrescription) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medical_services_rounded,
                              color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text(
                            'Prescription',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                  ],
                  if (product.category.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),

              // Name is shown only in [EclExpandableSliverAppBar] to avoid duplicating titles.
              const SizedBox(height: 6),

              // Price
              Row(
                children: [
                  Text(
                    'GHS ${double.parse(product.price).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                  if (product.uom != null && product.uom!.isNotEmpty) ...[
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        product.uom!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Prescription information section
              if (isPrescription) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.red.shade800, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This medication requires a valid prescription from a licensed healthcare provider.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Description (always show if available)
              if (product.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    child: ProductDescription(description: product.description),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => CartProvider.selectQuantityForProduct(
        cart,
        productName: product.name,
        batchNo: product.batch_no,
      ),
      builder: (context, cartQuantity, _) {
        if (cartQuantity <= 0) {
          return const SizedBox.shrink();
        }

        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final productNameNorm =
            CartProvider.normalizeProductName(product.name);
        final cartItems = cartProvider.cartItems;
        final existingItem = cartItems.cast<CartItem>().where(
              (item) =>
                  CartProvider.normalizeProductName(item.name) ==
                      productNameNorm &&
                  item.batchNo == product.batch_no,
            );
        final match =
            existingItem.isNotEmpty ? existingItem.first : null;
        if (match == null) {
          return const SizedBox.shrink();
        }
        final line = match;
        final itemIndex = cartItems.indexWhere((item) =>
            CartProvider.normalizeProductName(item.name) == productNameNorm &&
            item.batchNo == product.batch_no);

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
                Row(
                  children: [
                    Text(
                      'Quantity in Cart',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (product.uom != null && product.uom!.isNotEmpty) ...[
                      SizedBox(width: 4),
                      Text(
                        '(${product.uom})',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
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
                            onPressed: (cartQuantity > 1 &&
                                    !cartProvider.isItemUpdating(line.id))
                                ? () {
                                    // Prevent spam clicking
                                    final now = DateTime.now();
                                    if (_lastQuantityUpdateTime != null &&
                                        now.difference(
                                                _lastQuantityUpdateTime!) <
                                            _quantityUpdateCooldown) {
                                      return;
                                    }
                                    _lastQuantityUpdateTime = now;

                                    // Remove one from cart (use index when id empty)
                                    if (line.id.isNotEmpty) {
                                      cartProvider.updateQuantityById(
                                          line.id, cartQuantity - 1);
                                    } else if (itemIndex >= 0) {
                                      cartProvider.updateQuantity(
                                          itemIndex, cartQuantity - 1);
                                    }
                                  }
                                : null,
                            isEnabled: cartQuantity > 1 &&
                                !cartProvider.isItemUpdating(line.id),
                            size: 36.0,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cartQuantity.toString(),
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
                            onPressed: (cartQuantity < maxQuantity &&
                                    !cartProvider.isItemUpdating(line.id))
                                ? () async {
                                    // Prevent spam clicking
                                    final now = DateTime.now();
                                    if (_lastQuantityUpdateTime != null &&
                                        now.difference(
                                                _lastQuantityUpdateTime!) <
                                            _quantityUpdateCooldown) {
                                      return;
                                    }
                                    _lastQuantityUpdateTime = now;

                                    // Add haptic feedback
                                    HapticFeedback.mediumImpact();

                                    // Add one more via check-auth (no remove-from-cart).
                                    final incrementItem = CartItem(
                                      id: line.id,
                                      productId: product.id.toString(),
                                      originalProductId: product.id.toString(),
                                      serverProductId: line.serverProductId,
                                      name: line.name,
                                      price: line.price,
                                      quantity: 1,
                                      image: line.image,
                                      batchNo: product.batch_no.isNotEmpty
                                          ? product.batch_no
                                          : line.batchNo,
                                      urlName: line.urlName,
                                      totalPrice: line.price,
                                    );
                                    cartProvider.addToCart(incrementItem);

                                    // Play cart animation
                                    if (mounted) {
                                      await _flyToCartAnimation(context);
                                      _scaleController.forward().then(
                                          (_) => _scaleController.reverse());
                                    }
                                  }
                                : null,
                            isEnabled: cartQuantity < maxQuantity &&
                                !cartProvider.isItemUpdating(line.id),
                            size: 36.0,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Total: GHS ${(double.parse(product.price) * cartQuantity).toStringAsFixed(2)}',
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
      },
    );
  }

  Widget _buildActionButtons(Product product) {
    return Animate(
        effects: [
          FadeEffect(duration: 400.ms, delay: 400.ms),
          SlideEffect(
              duration: 400.ms,
              begin: Offset(0, 0.1),
              end: Offset(0, 0),
              delay: 400.ms)
        ],
        child: Selector<CartProvider, bool>(
          selector: (_, cart) => CartProvider.selectIsProductInCart(
            cart,
            productName: product.name,
            batchNo: product.batch_no,
          ),
          builder: (context, isInCart, _) {
            if (isInCart) {
              return const SizedBox.shrink();
            }

            final isPrescription =
                widget.isPrescribed || product.otcpom?.toLowerCase() == 'pom';

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: SizedBox(
                width: double.infinity,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: isPrescription
                        ? Colors.red.shade700
                        : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (isPrescription
                                ? Colors.red.shade700
                                : Colors.green.shade600)
                            .withValues(alpha: 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      // add haptic feedback
                      HapticFeedback.mediumImpact();

                      if (isPrescription) {
                        final token = await AuthService.getToken();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionUploadPage(
                              token: token ?? 'guest-temp-token',
                              item: {
                                'product': {
                                  'name': product.name,
                                  'thumbnail': product.thumbnail,
                                  'id': product.id,
                                },
                                'price': product.price,
                                'batch_no': product.batch_no,
                              },
                            ),
                          ),
                        );
                      } else {
                        _addToCartWithQuantity(context, product);
                      }
                    },
                    // style argument removed (duplicate)
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPrescription) ...[
                          Icon(Icons.upload_file_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Upload Prescription',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.shopping_cart_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ));
  }

  Widget _buildRelatedProductsSection(Product product) {
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
                    color: Colors.red.shade500,
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

  String _getErrorMessage(String error) {
    if (error.contains('timed out') || error.contains('SocketException')) {
      return 'Please check your internet connection and try again.';
    } else if (error.contains('404')) {
      return 'This product could not be found.';
    } else if (error.contains('500')) {
      return 'Our servers are experiencing issues. Please try again later.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  IconData _getErrorIcon(String error) {
    if (error.contains('timed out') || error.contains('SocketException')) {
      return Icons.wifi_off;
    } else if (error.contains('404')) {
      return Icons.search_off;
    } else if (error.contains('500')) {
      return Icons.error_outline;
    }
    return Icons.error_outline;
  }

  Color _getErrorColor(String error) {
    if (error.contains('timed out') || error.contains('SocketException')) {
      return Colors.orange;
    } else if (error.contains('404')) {
      return Colors.blue;
    } else if (error.contains('500')) {
      return Colors.red;
    }
    return Colors.red;
  }

  Widget _buildRelatedProductCard(Product product, BuildContext context) {
    // final imageUrl removed (was unused)

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.itemDetail,
          arguments: {
            'urlName': product.urlName,
            'isPrescribed': product.otcpom?.toLowerCase() == 'pom',
          },
        );
      },
      child: Container(
          // ...existing code for the card UI...
          // You should reconstruct the widget tree here as needed, ensuring no dead code or duplicate children.
          ),
    );
  }
}

class ItemPageSkeleton extends StatelessWidget {
  const ItemPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
        leading: BackButtonUtils.simple(
          backgroundColor: Colors.grey[400] ?? Colors.grey,
        ),
        title: Container(
          width: 200,
          height: 24,
          color: Colors.white,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[400],
            ),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 1, bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // product image skeleton
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.white,
              ),

              Container(
                width: 100,
                height: 24,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Container(
                          width: 100,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Container(
                          width: 120,
                          height: 20,
                          color: Colors.white,
                        ),
                      ),
                      const Divider(height: 24, thickness: 1),
                      const SizedBox(height: 8),

                      // description skeleton
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          5,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: index == 4 ? 100 : double.infinity,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: 150,
                  height: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(left: 10, right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 80,
                            height: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
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
  bool _expanded = false;
  final double _collapsedHeight = 160; // Approximate height for 8 lines
  final HtmlEscape _htmlEscape = const HtmlEscape();

  /// [flutter_html] maps `font-feature-settings` to [FontFeature]; CMS values like
  /// `normal` become `FontFeature.enable("normal")` and crash (tag must be 4 chars).
  /// Renaming the property avoids parsing entirely (unknown CSS keys are ignored).
  String _sanitizeRichHtmlForFlutterHtml(String html) {
    if (html.isEmpty) return html;
    return html
        .replaceAll(
            RegExp(r'font-feature-settings', caseSensitive: false), '_ffs_x_')
        .replaceAll(RegExp(r'font-variation-settings', caseSensitive: false),
            '_fvs_x_');
  }

  String _normalizeDescriptionToHtml(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // If backend already returns HTML, keep it.
    final hasHtmlTag = RegExp(r'<[a-zA-Z][^>]*>').hasMatch(trimmed);
    if (hasHtmlTag) return _sanitizeRichHtmlForFlutterHtml(trimmed);

    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return '<p>${_htmlEscape.convert(trimmed)}</p>';
    }

    final buffer = StringBuffer();
    bool inList = false;

    for (final line in lines) {
      final bulletMatch = RegExp(r'^(\-|\*|•)\s+').firstMatch(line);
      if (bulletMatch != null) {
        if (!inList) {
          buffer.writeln('<ul>');
          inList = true;
        }
        final cleanLine = line.replaceFirst(RegExp(r'^(\-|\*|•)\s+'), '');
        buffer.writeln('<li>${_htmlEscape.convert(cleanLine)}</li>');
      } else {
        if (inList) {
          buffer.writeln('</ul>');
          inList = false;
        }
        buffer.writeln('<p>${_htmlEscape.convert(line)}</p>');
      }
    }

    if (inList) {
      buffer.writeln('</ul>');
    }

    return _sanitizeRichHtmlForFlutterHtml(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final description = _normalizeDescriptionToHtml(widget.description);
    if (description.isEmpty) {
      return const Text(
        'No description available.',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 13,
          color: Colors.grey,
        ),
      );
    }

    // Use a key to measure the rendered height
    return LayoutBuilder(
      builder: (context, constraints) {
        // Style HTML for better readability
        final htmlWidget = Html(
          data: description,
          style: {
            "body": Style(
              fontSize: FontSize(14),
              color: const Color(0xFF1F2937),
              lineHeight: LineHeight.number(1.6),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            "h1, h2, h3, h4": Style(
              color: Colors.green.shade800,
              fontWeight: FontWeight.w700,
              margin: Margins.only(top: 8, bottom: 8),
            ),
            "ul": Style(
              padding: HtmlPaddings.only(left: 20),
              margin: Margins.only(top: 0, bottom: 10),
            ),
            "li": Style(
              fontSize: FontSize(14),
              color: const Color(0xFF1F2937),
              lineHeight: LineHeight.number(1.55),
              margin: Margins.only(bottom: 6),
            ),
            "strong": Style(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
            "hr": Style(
              margin: Margins.only(top: 12, bottom: 12),
              border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            "p": Style(
              margin: Margins.only(bottom: 10),
            ),
          },
        );

        return _ExpandableHtml(
          htmlWidget: htmlWidget,
          expanded: _expanded,
          collapsedHeight: _collapsedHeight,
          onToggle: () => setState(() => _expanded = !_expanded),
        );
      },
    );
  }
}

class _ExpandableHtml extends StatefulWidget {
  final Widget htmlWidget;
  final bool expanded;
  final double collapsedHeight;
  final VoidCallback onToggle;

  const _ExpandableHtml({
    required this.htmlWidget,
    required this.expanded,
    required this.collapsedHeight,
    required this.onToggle,
  });

  @override
  State<_ExpandableHtml> createState() => _ExpandableHtmlState();
}

class _ExpandableHtmlState extends State<_ExpandableHtml> {
  final GlobalKey _key = GlobalKey();
  double? _fullHeight;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final ctx = _key.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          _fullHeight = box.size.height;
          _showButton = _fullHeight! > widget.collapsedHeight + 8;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: widget.expanded || !_showButton
              ? const BoxConstraints(maxHeight: 10000)
              : BoxConstraints(maxHeight: widget.collapsedHeight),
          child: Container(key: _key, child: widget.htmlWidget),
        ),
        if (_showButton)
          TextButton(
            onPressed: widget.onToggle,
            child: Text(
              widget.expanded ? 'Show less' : 'Show more',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class CategoryAndTagsWidget extends StatelessWidget {
  final String category;
  final List<String> tags;

  const CategoryAndTagsWidget({
    super.key,
    required this.category,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty)
          Row(
            children: [
              const Text(
                "Category: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tags: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => TagChip(tag: tag)).toList(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  final String tag;

  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
