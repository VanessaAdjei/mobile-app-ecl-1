// pages/itemdetail.dart
import 'package:eclapp/pages/prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'CartItem.dart';
import 'package:eclapp/pages/ProductModel.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'bottomnav.dart';
import 'cartprovider.dart';
import 'package:html/parser.dart' show parse;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'AppBackButton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:eclapp/pages/cart.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';

// Import optimization service
import '../services/item_detail_optimization_service.dart';
import '../widgets/optimized_item_detail_widget.dart';

final Map<String, Product> _productCache = {};
final Map<String, List<Product>> _relatedProductsCache = {};

class ItemPage extends StatefulWidget {
  final String urlName;
  final bool isPrescribed;

  const ItemPage({
    super.key,
    required this.urlName,
    this.isPrescribed = false,
  });

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  late Future<Product> _productFuture;
  late Future<List<Product>> _relatedProductsFuture;
  int quantity = 1;
  final int maxQuantity = 99; // Maximum quantity limit
  final uuid = Uuid();
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;
  List<String> _productImages = [];

  // Key for storing quantity preferences
  static const String _quantityPrefsKey = 'product_quantities';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;

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

    // Load data concurrently
    _productFuture = _fetchProductDetailsWithCache(widget.urlName);
    _relatedProductsFuture = _fetchRelatedProductsWithCache(widget.urlName);
  }

  @override
  void dispose() {
    _imagePageController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Enhanced product fetching with caching
  Future<Product> _fetchProductDetailsWithCache(String urlName) async {
    // Check cache first
    if (_productCache.containsKey(urlName)) {
      return _productCache[urlName]!;
    }

    try {
      final product = await fetchProductDetails(urlName);

      // Cache the result
      _productCache[urlName] = product;

      // Extract images for gallery
      if (product.thumbnail.isNotEmpty) {
        _productImages = [product.thumbnail];
        // You can add more images here if available in the API response
      }

      return product;
    } catch (e) {
      // Remove from cache if there's an error
      _productCache.remove(urlName);
      rethrow;
    }
  }

  // Enhanced related products fetching with caching
  Future<List<Product>> _fetchRelatedProductsWithCache(String urlName) async {
    // Check cache first
    if (_relatedProductsCache.containsKey(urlName)) {
      return _relatedProductsCache[urlName]!;
    }

    try {
      final products = await fetchRelatedProducts(urlName);

      // Cache the result
      _relatedProductsCache[urlName] = products;

      return products;
    } catch (e) {
      // Remove from cache if there's an error
      _relatedProductsCache.remove(urlName);
      return [];
    }
  }

  void _addToCart(BuildContext context, Product product) async {
    _addToCartWithQuantity(context, product, 1);
  }

  void _addToCartWithQuantity(
      BuildContext context, Product product, int quantity) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    print('🔍 ADDING TO CART ===');
    print('Product ID: ${product.id}');
    print('Product Name: ${product.name}');
    print('Batch Number: ${product.batch_no}');
    print('Price: ${product.price}');
    print('URL Name: ${product.urlName}');
    print('Quantity: $quantity');
    print('========================');

    try {
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: product.id.toString(),
        originalProductId:
            product.id.toString(), // Preserve original product ID
        name: product.name,
        price: double.tryParse(product.price) ?? 0.0,
        quantity: quantity,
        image: product.thumbnail,
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: (double.tryParse(product.price) ?? 0.0) * quantity,
      );

      print('🔍 CREATED CART ITEM ===');
      print('Cart Item ID: ${cartItem.id}');
      print('Cart Item Quantity: ${cartItem.quantity}');
      print('Cart Item Total Price: ${cartItem.totalPrice}');
      print('========================');

      cartProvider.addToCart(cartItem);

      if (mounted) {
        await _flyToCartAnimation(context);
        _showSuccessSnackBar(
            context, '${quantity}x ${product.name} has been added to cart');
        _scaleController.forward().then((_) => _scaleController.reverse());
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(context, 'Error adding item to cart: $e');
      }
    }
  }

  Future<void> _flyToCartAnimation(BuildContext context) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // Find the render boxes for the Add to Cart button and the cart icon
    final addToCartBox = context.findRenderObject() as RenderBox?;
    final scaffoldBox =
        Scaffold.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final appBarBox = Scaffold.maybeOf(context)?.appBarMaxHeight != null
        ? Scaffold.maybeOf(context)?.context.findRenderObject() as RenderBox?
        : null;

    // Fallback: use the center bottom and top right
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
                    color: Colors.black.withOpacity(0.2),
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

  void _removeFromCart(BuildContext context, Product product) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    print('🔍 REMOVING FROM CART ===');
    print('Product ID: ${product.id}');
    print('Product Name: ${product.name}');
    print('Batch Number: ${product.batch_no}');
    print('URL Name: ${product.urlName}');
    print('========================');

    try {
      // Find the cart item to remove
      final cartItems = cartProvider.cartItems;
      final itemToRemove = cartItems.firstWhere(
        (item) =>
            item.productId == product.id.toString() &&
            item.batchNo == product.batch_no,
        orElse: () => CartItem(
          id: '',
          productId: product.id.toString(),
          name: product.name,
          price: 0.0,
          quantity: 0,
          image: '',
          batchNo: product.batch_no,
          urlName: product.urlName,
          totalPrice: 0.0,
        ),
      );

      if (itemToRemove.id.isNotEmpty) {
        await cartProvider.removeFromCart(itemToRemove.id);

        if (mounted) {
          _showSuccessSnackBar(
              context, '${product.name} has been removed from cart');
          // Update the quantity display
          setState(() {
            quantity = _getCartQuantity(product);
          });
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(context, 'Item not found in cart');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(context, 'Error removing item from cart: $e');
      }
    }
  }

  // Get current quantity of this product in cart
  int _getCartQuantity(Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartItems = cartProvider.cartItems;

    final cartItem = cartItems.firstWhere(
      (item) =>
          item.productId == product.id.toString() &&
          item.batchNo == product.batch_no,
      orElse: () => CartItem(
        id: '',
        productId: product.id.toString(),
        name: product.name,
        price: 0.0,
        quantity: 0,
        image: '',
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: 0.0,
      ),
    );

    return cartItem.quantity;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<Product> fetchProductDetails(String urlName) async {
    print('🔍 FETCHING PRODUCT DETAILS ===');
    print('URL Name: $urlName');

    try {
      final response = await http
          .get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/product-details/$urlName'),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('The request timed out. Please try again.');
        },
      );

      print('🔍 HTTP RESPONSE RECEIVED ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          // Debug print to see the full API response structure
          print('🔍 PRODUCT DETAILS API RESPONSE ===');
          print(
              'URL: https://eclcommerce.ernestchemists.com.gh/api/product-details/$urlName');
          print('Response Status: ${response.statusCode}');
          print('Response Body: ${response.body}');
          print('  data keys: ${data.keys.toList()}');
          if (data.containsKey('data')) {
            print('  data.data keys: ${data['data'].keys.toList()}');
            if (data['data'].containsKey('product')) {
              print(
                  '  data.data.product keys: ${data['data']['product'].keys.toList()}');
            }
            if (data['data'].containsKey('inventory')) {
              print(
                  '  data.data.inventory keys: ${data['data']['inventory'].keys.toList()}');
            }
          }
          print('=====================================');

          if (data.containsKey('data')) {
            final productData = data['data']['product'] ?? {};
            final inventoryData = data['data']['inventory'] ?? {};

            if (productData.isEmpty || inventoryData.isEmpty) {
              throw Exception('Product data is incomplete or missing');
            }

            // Get the product ID from the correct location
            final productId = productData['product_id'] ??
                productData['id'] ??
                inventoryData['product_id'] ??
                inventoryData['id'] ??
                inventoryData['inventory_id'] ??
                0;

            if (productId == 0) {
              throw Exception('Invalid product ID');
            }

            // Log the extracted product details
            print('🔍 EXTRACTED PRODUCT DETAILS ===');
            print('Product ID: $productId');
            print('Product Name: ${inventoryData['url_name']}');
            print('Batch Number: ${inventoryData['batch_no']}');
            print('Price: ${inventoryData['price']}');
            print('Status: ${inventoryData['status']}');
            print('Quantity: ${inventoryData['quantity']}');
            print('================================');

            // Check all possible locations for otcpom
            final otcpom = productData['otcpom'] ??
                inventoryData['otcpom'] ??
                productData['route'] ??
                inventoryData['route'] ??
                '';

            // Extract UOM (Unit of Measure) from possible locations
            final uom = productData['uom'] ??
                inventoryData['uom'] ??
                productData['unit_of_measure'] ??
                inventoryData['unit_of_measure'] ??
                '';

            // Debug print to see what UOM data we're getting
            print('🔍 UOM Debug Info:');
            print('  productData uom: ${productData['uom']}');
            print('  inventoryData uom: ${inventoryData['uom']}');
            print(
                '  productData unit_of_measure: ${productData['unit_of_measure']}');
            print(
                '  inventoryData unit_of_measure: ${inventoryData['unit_of_measure']}');
            print('  Final UOM value: $uom');

            List<String> tags = [];
            if (productData['tags'] != null && productData['tags'] is List) {
              tags = List<String>.from(
                  productData['tags'].map((tag) => tag.toString()));
            }

            final extractedName =
                _extractProductName(inventoryData['url_name'] ?? '');
            print('🔍 CREATING PRODUCT OBJECT ===');
            print('Extracted Name: $extractedName');
            print('Product ID: $productId');
            print('Price: ${inventoryData['price']?.toString() ?? '0.00'}');
            print('Batch No: ${inventoryData['batch_no'] ?? ''}');
            print(
                'Category: ${(productData['categories'] != null && productData['categories'].isNotEmpty) ? productData['categories'][0]['description'] ?? '' : ''}');
            print('UOM: $uom');

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
              'quantity': inventoryData['quantity']?.toString() ?? '',
              'category': (productData['categories'] != null &&
                      productData['categories'].isNotEmpty)
                  ? productData['categories'][0]['description'] ?? ''
                  : '',
              'otcpom': otcpom,
              'route': productData['route'] ?? '',
              'batch_no': inventoryData['batch_no'] ?? '',
              'uom': uom,
            });

            print('🔍 PRODUCT OBJECT CREATED ===');
            print('Final Product Name: ${product.name}');
            print('Final Product Price: ${product.price}');
            print('Final Product Category: ${product.category}');
            print('=====================================');

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

  // Helper method to extract clean product name from URL name
  String _extractProductName(String urlName) {
    if (urlName.isEmpty) return 'Unknown Product';

    print('🔍 EXTRACTING PRODUCT NAME ===');
    print('Original URL Name: $urlName');

    // Remove common suffixes that are not part of the product name
    String cleanName = urlName;

    // Remove random alphanumeric suffixes (like a8cfddbcd6)
    cleanName = cleanName.replaceAll(RegExp(r'-[a-f0-9]{8,}$'), '');
    print('After removing alphanumeric suffix: $cleanName');

    // Remove trailing numbers that are not part of the name
    cleanName = cleanName.replaceAll(RegExp(r'-\d+$'), '');
    print('After removing trailing numbers: $cleanName');

    // Convert kebab-case to title case
    final finalName = cleanName
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');

    print('Final extracted name: $finalName');
    print('================================');

    return finalName;
  }

  // Load saved quantity for this product
  Future<void> _loadSavedQuantity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantityPrefs = prefs.getString(_quantityPrefsKey);

      if (quantityPrefs != null) {
        final Map<String, dynamic> prefsMap = json.decode(quantityPrefs);
        final savedQuantity = prefsMap[widget.urlName];

        if (savedQuantity != null &&
            savedQuantity is int &&
            savedQuantity > 0) {
          setState(() {
            quantity = savedQuantity;
          });
          print('🔍 LOADED SAVED QUANTITY ===');
          print('Product: ${widget.urlName}');
          print('Saved Quantity: $quantity');
          print('==========================');
        }
      }
    } catch (e) {
      print('Error loading saved quantity: $e');
    }
  }

  // Save quantity for this product
  Future<void> _saveQuantity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantityPrefs = prefs.getString(_quantityPrefsKey);

      Map<String, dynamic> prefsMap = {};
      if (quantityPrefs != null) {
        prefsMap = json.decode(quantityPrefs);
      }

      prefsMap[widget.urlName] = quantity;

      await prefs.setString(_quantityPrefsKey, json.encode(prefsMap));

      print('🔍 SAVED QUANTITY ===');
      print('Product: ${widget.urlName}');
      print('Quantity: $quantity');
      print('====================');
    } catch (e) {
      print('Error saving quantity: $e');
    }
  }

  Future<void> _clearSavedQuantity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantityPrefs = prefs.getString(_quantityPrefsKey);

      if (quantityPrefs != null) {
        Map<String, dynamic> prefsMap = json.decode(quantityPrefs);
        prefsMap.remove(widget.urlName);

        await prefs.setString(_quantityPrefsKey, json.encode(prefsMap));

        print('🔍 CLEARED SAVED QUANTITY ===');
        print('Product: ${widget.urlName}');
        print('============================');
      }
    } catch (e) {
      print('Error clearing saved quantity: $e');
    }
  }

  Future<List<Product>> fetchRelatedProducts(String urlName) async {
    try {
      final response = await http
          .get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/related-products/$urlName'),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder<Product>(
          future: _productFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                snapshot.data!.urlName
                    .replaceAll('-', ' ')
                    .split(' ')
                    .map((word) => word.isNotEmpty
                        ? word[0].toUpperCase() + word.substring(1)
                        : '')
                    .join(' '),
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
          // Cart button
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
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
        child: FutureBuilder<Product>(
          future: _productFuture,
          builder: (context, snapshot) {
            print('🔍 FUTUREBUILDER STATE ===');
            print('Connection State: ${snapshot.connectionState}');
            print('Has Data: ${snapshot.hasData}');
            print('Has Error: ${snapshot.hasError}');
            if (snapshot.hasError) {
              print('Error: ${snapshot.error}');
            }
            if (snapshot.hasData) {
              print('Product Data: ${snapshot.data!.name}');
            }
            print('==========================');

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
            return SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Product Image Gallery
                  _buildProductImageGallery(product),

                  // Product Info Card
                  _buildProductInfoCard(product, theme),

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
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms),
        SlideEffect(duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0))
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
              itemCount: _productImages.isNotEmpty ? _productImages.length : 1,
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
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoCard(Product product, ThemeData theme) {
    print('🔍 BUILDING PRODUCT INFO CARD ===');
    print('Product Name: ${product.name}');
    print('Product URL Name: ${product.urlName}');
    print('Product Price: ${product.price}');
    print('Product Category: ${product.category}');
    print('Product UOM: ${product.uom}');
    print('==================================');

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
              color: Colors.black.withOpacity(0.08),
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
              // Category chip
              if (product.category.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Chip(
                    label: Text(
                      product.category,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    backgroundColor: Colors.green.shade600,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  ),
                ),

              // Product name - Use the extracted name instead of urlName
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
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: 4),

              // Price
              Row(
                children: [
                  Text(
                    'GHS ${double.parse(product.price).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  if (product.uom != null && product.uom!.isNotEmpty) ...[
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '${product.uom}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8),

              // Description
              if (!widget.isPrescribed && product.description.isNotEmpty)
                ProductDescription(description: product.description),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
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
              color: Colors.black.withOpacity(0.08),
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
                  'Quantity',
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
                // Simple Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove,
                          color: quantity > 1
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                          size: 18,
                        ),
                        onPressed: quantity > 1
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  quantity--;
                                });
                              }
                            : null,
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.all(8),
                          minimumSize: Size(32, 32),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          quantity.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add,
                          color: quantity < maxQuantity
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                          size: 18,
                        ),
                        onPressed: quantity < maxQuantity
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  quantity++;
                                });
                              }
                            : null,
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.all(8),
                          minimumSize: Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Simple Total price display
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Total: GHS ${(double.parse(product.price) * quantity).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            // Maximum quantity indicator removed for cleaner design
          ],
        ),
      ),
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
        child: Container(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    return ElevatedButton(
                      onPressed: () async {
                        // Add haptic feedback
                        HapticFeedback.mediumImpact();

                        print('DEBUG: ItemPage urlName = \\${widget.urlName}');
                        print('DEBUG: isPrescribed = \\${widget.isPrescribed}');
                        if (widget.isPrescribed) {
                          final token = await AuthService.getToken();
                          if (token == null || token == "guest-temp-token") {
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
                          _addToCartWithQuantity(context, product, quantity);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                        backgroundColor: widget.isPrescribed
                            ? Colors.red[600]
                            : Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isPrescribed) ...[
                            Icon(Icons.medical_services_outlined,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                          ] else ...[
                            Icon(Icons.add_shopping_cart,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                          ],
                          Text(
                            widget.isPrescribed
                                ? 'Upload Prescription'
                                : 'Add to Cart',
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
    bottomNavigationBar:
    CustomBottomNav(initialIndex: 0);
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
            // Enhanced header with background
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
                    color: Colors.red.shade400,
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

                return Container(
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
        : 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/${product.thumbnail}';

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ItemPage(urlName: product.urlName),
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
                color: Colors.black.withOpacity(0.08),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.green.shade700,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This feature is only for signed up users.\nSign in to upload a prescription, get refillable drugs, and track your order.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(
                              color: Colors.green.shade700, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignInScreen(
                                onSuccess: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                          elevation: 1,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text('Sign In'),
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
        leading:
            AppBackButton(backgroundColor: Colors.grey[400] ?? Colors.grey),
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
              // Product Image Skeleton
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

                      // Description Skeleton
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
  bool isExpanded = false;
  late String _plainDescription;

  @override
  void initState() {
    super.initState();
    _plainDescription = _stripHtmlTags(widget.description);
  }

  String _stripHtmlTags(String html) {
    // Use the html parser to remove tags
    return parse(html).body?.text.trim() ?? html;
  }

  @override
  Widget build(BuildContext context) {
    final displayContent = !isExpanded && _plainDescription.length > 100
        ? _plainDescription.substring(0, 100) + '...'
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
