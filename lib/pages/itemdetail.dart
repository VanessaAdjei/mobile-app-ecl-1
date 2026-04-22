// pages/itemdetail.dart
import 'package:eclapp/pages/prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/services/auth_service.dart';
import 'bottomnav.dart';
import '../providers/cart_provider.dart';
import 'package:html/parser.dart' show parse;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_back_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/optimized_quantity_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_page_optimization_service.dart';

import 'homepage.dart';

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
  final List<String> _productImages = [];

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

    debugPrint('🔍 ADDING TO CART ===');
    debugPrint('Product ID: ${product.id}');
    debugPrint('Product Name: ${product.name}');
    debugPrint('Batch Number: ${product.batch_no}');
    debugPrint('Price: ${product.price}');
    debugPrint('URL Name: ${product.urlName}');
    debugPrint('Quantity: ${this.quantity}');
    debugPrint('========================');

    try {
      final cartItem = CartItem(
        // Use server cart ID only; start with empty and update after server response
        id: '',
        productId: product.id.toString(),
        originalProductId: product.id.toString(),
        name: product.name,
        price: double.tryParse(product.price) ?? 0.0,
        quantity: this.quantity,
        image: product.thumbnail,
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: (double.tryParse(product.price) ?? 0.0) * this.quantity,
      );

      debugPrint('🔍 CREATED CART ITEM ===');
      debugPrint('Cart Item ID: ${cartItem.id}');
      debugPrint('Cart Item Quantity: ${cartItem.quantity}');
      debugPrint('Cart Item Total Price: ${cartItem.totalPrice}');
      debugPrint('========================');

      // remember the original quantity for the success message
      final originalQuantity = this.quantity;

      // reset quantity to 1 before adding to cart
      setState(() {
        quantity = 1;
      });

      debugPrint('✅ Quantity reset to 1 before adding to cart');
      debugPrint('🔍 Current quantity after reset: $quantity');

      cartProvider.addToCart(cartItem);

      if (context.mounted) {
        await _flyToCartAnimation(context);
        if (context.mounted) {
          _showSuccessSnackBar(context,
              '${originalQuantity}x ${product.name} has been added to cart');
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
        backgroundColor: Colors.red.shade600,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<Product> fetchProductDetails(String urlName) async {
    debugPrint('🔍 FETCHING PRODUCT DETAILS ===');
    debugPrint('URL Name: $urlName');

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

      debugPrint('🔍 HTTP RESPONSE RECEIVED ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          // print the api response so we can see what we got
          debugPrint('🔍 PRODUCT DETAILS API RESPONSE ===');
          debugPrint('URL: ${ApiConfig.getProductDetailsUrl(urlName)}');
          debugPrint('Response Status: ${response.statusCode}');
          debugPrint('Response Body: ${response.body}');
          debugPrint('  data keys: ${data.keys.toList()}');
          if (data.containsKey('data')) {
            debugPrint('  data.data keys: ${data['data'].keys.toList()}');
            if (data['data'].containsKey('product')) {
              debugPrint(
                  '  data.data.product keys: ${data['data']['product'].keys.toList()}');
            }
            if (data['data'].containsKey('inventory')) {
              debugPrint(
                  '  data.data.inventory keys: ${data['data']['inventory'].keys.toList()}');
            }
          }
          debugPrint('=====================================');

          if (data.containsKey('data')) {
            final productData = data['data']['product'] ?? {};
            final inventoryData = data['data']['inventory'] ?? {};

            // print the raw api response so we can see the structure
            debugPrint('🔍 RAW API RESPONSE STRUCTURE ===');
            debugPrint('Product Data Keys: ${productData.keys.toList()}');
            debugPrint('Inventory Data Keys: ${inventoryData.keys.toList()}');
            debugPrint('Complete Product Data: $productData');
            debugPrint('Complete Inventory Data: $inventoryData');
            debugPrint('=====================================');

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

            // print the product details we extracted
            debugPrint('🔍 EXTRACTED PRODUCT DETAILS ===');
            debugPrint('Product ID: $productId');
            debugPrint('Product Name: ${inventoryData['url_name']}');
            debugPrint('Batch Number: ${inventoryData['batch_no']}');
            debugPrint('Price: ${inventoryData['price']}');
            debugPrint('Status: ${inventoryData['status']}');
            debugPrint('Quantity: ${inventoryData['quantity']}');
            debugPrint('================================');

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
                debugPrint('🔍 Found OTCPOM from cached products: $otcpom');
              }
            }

            // print what otcpom data we got
            debugPrint('🔍 OTCPOM Debug Info:');
            debugPrint('  productData otcpom: ${productData['otcpom']}');
            debugPrint('  inventoryData otcpom: ${inventoryData['otcpom']}');
            debugPrint('  productData route: ${productData['route']}');
            debugPrint('  inventoryData route: ${inventoryData['route']}');
            debugPrint('  Final OTCPOM value: $otcpom');

            // get the unit of measure from wherever it might be
            final uom = productData['uom'] ??
                inventoryData['uom'] ??
                productData['unit_of_measure'] ??
                inventoryData['unit_of_measure'] ??
                '';

            // print what uom data we got
            debugPrint('🔍 UOM Debug Info:');
            debugPrint('  productData uom: ${productData['uom']}');
            debugPrint('  inventoryData uom: ${inventoryData['uom']}');
            debugPrint(
                '  productData unit_of_measure: ${productData['unit_of_measure']}');
            debugPrint(
                '  inventoryData unit_of_measure: ${inventoryData['unit_of_measure']}');
            debugPrint('  Final UOM value: $uom');

            List<String> tags = [];
            if (productData['tags'] != null && productData['tags'] is List) {
              tags = List<String>.from(
                  productData['tags'].map((tag) => tag.toString()));
            }

            final extractedName =
                _extractProductName(inventoryData['url_name'] ?? '');
            debugPrint('🔍 CREATING PRODUCT OBJECT ===');
            debugPrint('Extracted Name: $extractedName');
            debugPrint('Product ID: $productId');
            debugPrint(
                'Price: ${inventoryData['price']?.toString() ?? '0.00'}');
            debugPrint('Batch No: ${inventoryData['batch_no'] ?? ''}');
            debugPrint('Stock: ${inventoryData['stock']?.toString() ?? '0'}');
            debugPrint(
                'Category: ${(productData['categories'] != null && productData['categories'].isNotEmpty) ? productData['categories'][0]['description'] ?? '' : ''}');
            debugPrint('UOM: $uom');

            final product = Product.fromJson({
              'id': productId,
              'name': extractedName,
              'description': productData['description'] ?? '',
              'url_name': inventoryData['url_name'] ?? '',
              'status': inventoryData['status'] ?? '',
              'price': inventoryData['price']?.toString() ?? '0.00',
              'thumbnail': (productData['images'] != null &&
                      productData['images'].isNotEmpty)
                  ? productData['images'][0]['url'] ?? ''
                  : '',
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

            debugPrint('🔍 PRODUCT OBJECT CREATED ===');
            debugPrint('Final Product Name: ${product.name}');
            debugPrint('Final Product Price: ${product.price}');
            debugPrint('Final Product Category: ${product.category}');
            debugPrint('Final Product OTCPOM: ${product.otcpom}');
            debugPrint('=====================================');

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

    debugPrint('🔍 EXTRACTING PRODUCT NAME ===');
    debugPrint('Original URL Name: $urlName');

    // remove common suffixes that arent part of the name
    String cleanName = urlName;

    // remove random letter/number suffixes (like a8cfddbcd6)
    cleanName = cleanName.replaceAll(RegExp(r'-[a-f0-9]{8,}$'), '');
    debugPrint('After removing alphanumeric suffix: $cleanName');

    // remove numbers at the end that arent part of the name
    cleanName = cleanName.replaceAll(RegExp(r'-\d+$'), '');
    debugPrint('After removing trailing numbers: $cleanName');

    // turn kebab-case into title case
    final finalName = cleanName
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');

    debugPrint('Final extracted name: $finalName');
    debugPrint('================================');

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
                Colors.green.shade700,
                Colors.green.shade800,
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
        title: null,
        actions: [
          // cart button
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
        child: _showSkeleton
            ? _buildLoadingSkeleton()
            : FutureBuilder<Product>(
                future: _productFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Error: ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    debugPrint('Product Data: ${snapshot.data!.name}');
                  }
                  debugPrint('==========================');

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingSkeleton();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (!snapshot.hasData) {
                    return _buildErrorState('No product data available');
                  }

                  final product = snapshot.data!;

                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // product image gallery
                          _buildProductImageGallery(product),

                          // product info card
                          _buildProductInfoCard(product, theme),

                          // action buttons (add to cart, etc)
                          _buildActionButtons(product),

                          // quantity selector (only show if item is in cart)
                          _buildQuantitySelector(product),

                          // related products section
                          _buildRelatedProductsSection(product),
                        ],
                      ),
                    ),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12),
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
            SizedBox(height: 16),

            // product info skeleton
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

  Widget _buildProductImageGallery(Product product) {
    final imageUrls =
        _productImages.isNotEmpty ? _productImages : [product.thumbnail];
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
              // image pageview
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
                      : product.thumbnail;

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
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          padding: EdgeInsets.all(12),
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

              SizedBox(height: 8),

              // Product name
              Text(
                product.name.isNotEmpty
                    ? product.name
                    : product.urlName
                        .replaceAll('-', ' ')
                        .split(' ')
                        .map((word) => word.isNotEmpty
                            ? word[0].toUpperCase() + word.substring(1)
                            : '')
                        .join(' '),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                  height: 1.3,
                ),
              ),

              SizedBox(height: 6),

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
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(10),
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

              SizedBox(height: isPrescription ? 0 : 6),

              // Description (only for non-prescription items)
              if (!isPrescription && product.description.isNotEmpty)
                ProductDescription(description: product.description),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        // Check if product is in cart
        final cartItems = cartProvider.cartItems;
        final productNameNorm = CartProvider.normalizeProductName(product.name);
        final matches = cartItems
            .cast<CartItem>()
            .where(
              (item) =>
                  CartProvider.normalizeProductName(item.name) ==
                      productNameNorm &&
                  item.batchNo == product.batch_no,
            )
            .toList();
        final existingItem = matches.isNotEmpty ? matches.first : null;
        final itemIndex = existingItem != null
            ? cartItems.indexWhere((item) =>
                CartProvider.normalizeProductName(item.name) ==
                    productNameNorm &&
                item.batchNo == product.batch_no)
            : -1;

        // In cart if we have a matching item (by name+batch) - don't rely on id
        final isInCart = existingItem != null;
        final cartQuantity = isInCart ? existingItem.quantity : 0;

        // Only show quantity selector if item is in cart
        if (!isInCart) {
          return SizedBox.shrink();
        }

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
                                    !cartProvider
                                        .isItemUpdating(existingItem.id))
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
                                    if (existingItem.id.isNotEmpty) {
                                      cartProvider.updateQuantityById(
                                          existingItem.id, cartQuantity - 1);
                                    } else if (itemIndex >= 0) {
                                      cartProvider.updateQuantity(
                                          itemIndex, cartQuantity - 1);
                                    }
                                  }
                                : null,
                            isEnabled: cartQuantity > 1 &&
                                !cartProvider.isItemUpdating(existingItem.id),
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
                                    !cartProvider
                                        .isItemUpdating(existingItem.id))
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

                                    // Add one more to cart (use index when id empty)
                                    if (existingItem.id.isNotEmpty) {
                                      cartProvider.updateQuantityById(
                                          existingItem.id, cartQuantity + 1);
                                    } else if (itemIndex >= 0) {
                                      cartProvider.updateQuantity(
                                          itemIndex, cartQuantity + 1);
                                    }

                                    // Play cart animation
                                    if (mounted) {
                                      await _flyToCartAnimation(context);
                                      _scaleController.forward().then(
                                          (_) => _scaleController.reverse());
                                    }
                                  }
                                : null,
                            isEnabled: cartQuantity < maxQuantity &&
                                !cartProvider.isItemUpdating(existingItem.id),
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
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            // check if product is already in cart
            final cartItems = cartProvider.cartItems;

            for (int i = 0; i < cartItems.length; i++) {
              debugPrint(
                  'Cart Item $i: Name=${cartItems[i].name}, ID=${cartItems[i].productId}, Batch=${cartItems[i].batchNo}, Qty=${cartItems[i].quantity}');
            }

            final productNameNorm =
                CartProvider.normalizeProductName(product.name);
            final existingItem = cartItems
                .cast<CartItem>()
                .where(
                  (item) =>
                      CartProvider.normalizeProductName(item.name) ==
                          productNameNorm &&
                      item.batchNo == product.batch_no,
                )
                .toList();
            final match = existingItem.isNotEmpty ? existingItem.first : null;

            // In cart if we have a matching item (by name+batch) - don't rely on id
            // since newly added items have id: '' until server sync completes
            final isInCart = match != null;
            final cartQuantity = isInCart ? match.quantity : 0;

            debugPrint('Is In Cart: $isInCart');
            debugPrint('Cart Quantity: $cartQuantity');
            debugPrint('========================');

            // Hide the entire button container if item is already in cart
            if (isInCart) {
              return SizedBox.shrink();
            }

            final isPrescription =
                widget.isPrescribed || product.otcpom?.toLowerCase() == 'pom';

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: isPrescription
                        ? Colors.red.shade700
                        : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: (isPrescription
                                ? Colors.red.shade700
                                : Colors.green.shade600)
                            .withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      // add haptic feedback
                      HapticFeedback.mediumImpact();

                      debugPrint(
                          'DEBUG: ItemPage urlName = \\${widget.urlName}');
                      debugPrint(
                          'DEBUG: isPrescribed = \\${widget.isPrescribed}');
                      if (isPrescription) {
                        final token = await AuthService.getToken();
                        if (token == null || token == "guest-temp-token") {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                              'pending_prescription_product', product.name);
                          await prefs.setString(
                              'pending_prescription_thumbnail',
                              product.thumbnail);
                          await prefs.setString(
                              'pending_prescription_id', product.id.toString());
                          await prefs.setString(
                              'pending_prescription_price', product.price);
                          await prefs.setString('pending_prescription_batch_no',
                              product.batch_no);
                          await prefs.setBool('has_pending_prescription', true);

                          debugPrint(
                              '🔍 ItemDetail: Stored prescription data:');
                          debugPrint(
                              '🔍 ItemDetail: Product Name: ${product.name}');
                          debugPrint(
                              '🔍 ItemDetail: Product ID: ${product.id}');
                          debugPrint('🔍 ItemDetail: Price: ${product.price}');
                          debugPrint(
                              '🔍 ItemDetail: Batch No: ${product.batch_no}');

                          if (!context.mounted) return;

                          _showSignInRequiredDialog(context);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionUploadPage(
                              token: token,
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
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
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
    final imageUrl = product.thumbnail.startsWith('http')
        ? product.thumbnail
        : ApiConfig.getProductImageUrl(product.thumbnail);

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
              // image section
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
                    // prescribed medicine badge
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
              // content section
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
                          color: Colors.green.shade800,
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

  void _showSignInRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Prescription Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This medication requires a valid prescription. Please sign in to upload your prescription and complete your order.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            AppRoutes.signIn,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('Sign In'),
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
  @override
  Widget build(BuildContext context) {
    if (widget.description.trim().isEmpty) {
      return const Text(
        'No description available.',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 13,
          color: Colors.grey,
        ),
      );
    }
    return Html(
      data: widget.description,
      style: {
        "body": Style(
          fontSize: FontSize(13),
          color: Colors.black54,
          lineHeight: LineHeight(1.4),
          margin: Margins.zero,
        ),
      },
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
