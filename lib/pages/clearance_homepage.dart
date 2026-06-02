// pages/clearance_homepage.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/product_catalog_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/clearance_sale_provider.dart';
import '../services/clearance_sale_api_service.dart';
import '../widgets/cart_icon_button.dart';
import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../utils/app_error_utils.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import 'clearance_item_detail.dart';
import 'search_results_page.dart';
import '../models/product_model.dart';

class ClearanceHomePage extends StatefulWidget {
  const ClearanceHomePage({super.key});

  @override
  State<ClearanceHomePage> createState() => _ClearanceHomePageState();
}

class _ClearanceHomePageState extends State<ClearanceHomePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ProductCatalogService _catalogService = ProductCatalogService();
  bool _isLoading = true;

  // Safe Google Fonts wrapper - handles network errors gracefully
  TextStyle _safeGoogleFonts({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      print('⚠️ Google Fonts error, using fallback: $e');
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: 'Roboto',
      );
    }
  }

  String? _error;
  List<ClearanceProduct> _clearanceProducts = [];
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _featuredScrollController = ScrollController();
  AnimationController? _pulseController;
  AnimationController? _slideController;
  Timer? _autoScrollTimer;

  // Filtering and sorting
  String _selectedCategory = 'All';
  String _sortBy = 'price_low';
  List<String> _categories = ['All'];
  List<ClearanceProduct> _filteredProducts = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAutoScroll();
    // Clear any cached network images to prevent conflicts
    imageCache.clear();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClearanceData();
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _startAnimations();
  }

  void _startAnimations() {
    _pulseController?.repeat(reverse: true);
    _slideController?.forward();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_featuredScrollController.hasClients &&
          _clearanceProducts.isNotEmpty) {
        final currentOffset = _featuredScrollController.offset;
        final maxScrollExtent =
            _featuredScrollController.position.maxScrollExtent;

        if (currentOffset >= maxScrollExtent) {
          // If at the end, scroll back to beginning
          _featuredScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Scroll to next item (140px width + 12px margin = 152px)
          final nextOffset = currentOffset + 152;
          _featuredScrollController.animateTo(
            nextOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _updateCategories() {
    final categories = _clearanceProducts
        .map((product) => product.category)
        .where((category) =>
            category.isNotEmpty) // Only include non-empty categories
        .toSet()
        .toList();
    categories.sort();
    _categories = ['All', ...categories];

    // Debug: Print available categories
    print('🏷️ Available categories: $_categories');
    print('🏷️ Total products: ${_clearanceProducts.length}');
    for (var product in _clearanceProducts) {
      print('  - ${product.name}: ${product.category}');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _clearanceProducts.where((product) {
        if (_selectedCategory != 'All' &&
            product.category != _selectedCategory) {
          return false;
        }
        return true;
      }).toList();

      // Apply sorting
      switch (_sortBy) {
        case 'price_low':
          _filteredProducts
              .sort((a, b) => a.clearancePrice.compareTo(b.clearancePrice));
          break;
        case 'price_high':
          _filteredProducts
              .sort((a, b) => b.clearancePrice.compareTo(a.clearancePrice));
          break;
        case 'name':
          _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
          break;
      }
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  void _onSortChanged(String sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _featuredScrollController.dispose();
    _pulseController?.dispose();
    _slideController?.dispose();
    _stopAutoScroll();
    super.dispose();
  }

  Future<void> _loadClearanceData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Attempting to load from API...');
      await _loadClearanceFromAPI();
      print('Successfully loaded from API');
    } catch (e) {
      print('API failed with error: $e');
      print(' Error type: ${e.runtimeType}');

      if (mounted) {
        setState(() {
          _error = 'Failed to load products: ${e.toString()}';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClearanceFromAPI() async {
    try {
      print('🔄 Loading clearance products from API...');

      final dataList = await _catalogService.fetchCatalogRawItems(
        timeout: const Duration(seconds: 10),
      );

      print('✅ API Response: ${dataList.length} products received');
      if (dataList.isNotEmpty) {
        print('✅ First product structure: ${(dataList[0] as Map).keys.toList()}');
          if (dataList[0]['product'] != null) {
            final productData = dataList[0]['product'] as Map<String, dynamic>;
            print('✅ Product data structure: ${productData.keys.toList()}');
            print('✅ Image fields available:');
            print('  - thumbnail: ${productData['thumbnail']}');
            print('  - image: ${productData['image']}');
            print('  - product_img: ${productData['product_img']}');
            print('  - images: ${productData['images']}');
          }
        }

        double actualDiscount = 50.0;
        try {
          if (mounted) {
            final clearanceProvider =
                Provider.of<ClearanceSaleProvider>(context, listen: false);
            if (clearanceProvider.isActive) {
              actualDiscount = clearanceProvider.discountPercentage;
            }
          }
        } catch (e) {
          debugPrint('ClearanceHomepage: discount from provider failed: $e');
        }

        final clearanceProducts = dataList.map<ClearanceProduct>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          final originalPrice = (item['price'] ?? 0.0).toDouble();
          final clearancePrice = originalPrice * (1 - actualDiscount / 100);
          final discountAmount = originalPrice * (actualDiscount / 100);

          if (dataList.indexOf(item) < 3) {
            print('🔍 Product ${productData['name']} image fields:');
            print('  - thumbnail: ${productData['thumbnail']}');
            print('  - image: ${productData['image']}');
            print('  - product_img: ${productData['product_img']}');
          }

          final imageUrl = productData['thumbnail'] ??
              productData['image'] ??
              productData['product_img'] ??
              '';

          if (dataList.indexOf(item) < 3) {
            print('  - Final image URL: $imageUrl');
          }

          String category = 'Drug';
          if (productData['drug'] == 'drug' || productData['drug'] == true) {
            category = 'Drug';
          } else if (productData['wellness'] == 'wellness') {
            category = 'Wellness';
          } else if (productData['selfcare'] == 'selfcare') {
            category = 'Self Care';
          } else if (productData['accessories'] == 'accessories') {
            category = 'Accessories';
          }

          if (dataList.indexOf(item) < 3) {
            print('🏷️ Product ${productData['name']} category fields:');
            print('  - otcpom: ${productData['otcpom']}');
            print('  - drug: ${productData['drug']}');
            print('  - wellness: ${productData['wellness']}');
            print('  - selfcare: ${productData['selfcare']}');
            print('  - accessories: ${productData['accessories']}');
            print('  - Final category: $category');
          }

          if (productData['accessories'] == 'accessories') {
            print('🔍 Found accessories product: ${productData['name']}');
          }

          if (dataList.indexOf(item) < 3) {
            print('🆔 Product ${productData['name']} ID mapping:');
            print('  - item[id]: ${item['id']}');
            print('  - item[product_id]: ${item['product_id']}');
            print('  - productData[id]: ${productData['id']}');
            print(
                '  - Final ID: ${item['id'] ?? item['product_id'] ?? productData['id'] ?? 0}');
          }

          return ClearanceProduct(
            id: item['id'] ?? item['product_id'] ?? productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? 'active',
            batchNo: item['batch_no'] ?? '',
            originalPrice: originalPrice,
            clearancePrice: clearancePrice,
            discountAmount: discountAmount,
            discountPercentage: actualDiscount,
            thumbnail: imageUrl,
            quantity: productData['qty_in_stock']?.toString() ?? '0',
            category: category,
            route: productData['route'] ?? 'oral',
            isPrescribed: productData['otcpom'] == 'pom',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _clearanceProducts = clearanceProducts;
            _updateCategories();
            _applyFilters();
          });
          // Restart auto-scroll when new products are loaded
          _startAutoScroll();
        }

        print(
            '✅ Converted ${clearanceProducts.length} products to clearance format');
        print('✅ Banner will show: Up to ${_getMaxDiscountPercentage()}% OFF');

        // Debug: Print categories from API
        final apiCategories =
            clearanceProducts.map((p) => p.category).toSet().toList();
        apiCategories.sort();
        print('🏷️ API Categories: $apiCategories');

        // Debug: Count products by category
        final categoryCounts = <String, int>{};
        for (var product in clearanceProducts) {
          categoryCounts[product.category] =
              (categoryCounts[product.category] ?? 0) + 1;
        }
        print('📊 API Category counts: $categoryCounts');

        // Debug first few products' final data
        for (int i = 0; i < 3 && i < clearanceProducts.length; i++) {
          final product = clearanceProducts[i];
          print('🔍 Final Product $i: ${product.name}');
          print('  - Image URL: ${product.thumbnail}');
          print(
              '  - Price: GHS ${product.originalPrice} -> GHS ${product.clearancePrice}');
        }
    } catch (e) {
      print('❌ API Error Details: $e');
      print('❌ Error Type: ${e.runtimeType}');
      if (e.toString().contains('SocketException')) {
        print('❌ Network connection issue');
      } else if (e.toString().contains('TimeoutException')) {
        print('❌ Request timed out');
      } else if (e.toString().contains('FormatException')) {
        print('❌ JSON parsing error');
      }
      rethrow; // Re-throw to trigger fallback to mock data
    }
  }

  Future<void> _handleRefresh() async {
    await _loadClearanceData();
    _refreshController.refreshCompleted();
  }

  int _getMaxDiscountPercentage() {
    try {
      if (mounted) {
        final clearanceProvider =
            Provider.of<ClearanceSaleProvider>(context, listen: false);
        if (clearanceProvider.isActive) {
          return clearanceProvider.discountPercentage.round();
        }
      }
    } catch (e) {
      // Silently handle error
    }

    // If no active clearance sale, calculate from actual product discounts
    if (_clearanceProducts.isEmpty) return 0;

    double maxDiscount = 0;
    for (var product in _clearanceProducts) {
      if (product.discountPercentage > maxDiscount) {
        maxDiscount = product.discountPercentage;
      }
    }

    return maxDiscount.round();
  }

  void _addToCart(ClearanceProduct product) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Adding ${product.name} to cart...',
                  style: _safeGoogleFonts(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Get the cart provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Validate product data before adding to cart
      if (product.name.isEmpty) {
        throw Exception('Product name is missing');
      }
      if (product.clearancePrice <= 0) {
        throw Exception('Invalid product price');
      }

      // Create a CartItem from the ClearanceProduct
      final cartItem = CartItem(
        id: 'clearance_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id.toString(),
        name: product.name,
        price: product.clearancePrice,
        originalPrice: product.originalPrice,
        quantity: 1,
        image: product.thumbnail,
        batchNo: product.batchNo,
        urlName: product.urlName,
        totalPrice: product.clearancePrice,
      );

      // Add to cart with timeout
      await cartProvider.addToCart(cartItem).timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Adding to cart timed out'),
          );

    } on TimeoutException catch (e) {
      _handleAddToCartError(
          product, 'Adding to cart timed out. Please try again.', 'Timeout', e);
    } on SocketException catch (e) {
      _handleAddToCartError(
          product,
          'No internet connection. Please check your network.',
          'No Internet',
          e);
    } on HttpException catch (e) {
      _handleAddToCartError(
          product, AppErrorUtils.oopsTryAgainMessage, AppErrorUtils.oopsTitle, e);
    } on FormatException catch (e) {
      _handleAddToCartError(
          product, 'Data processing error. Please try again.', 'Data Error', e);
    } on Exception catch (e) {
      _handleAddToCartError(
          product,
          'Failed to add ${product.name} to cart. Please try again.',
          'Add Failed',
          e);
    } catch (e) {
      _handleAddToCartError(product, 'Something went wrong. Please try again.',
          'Unknown Error', e);
    }
  }

  void _handleAddToCartError(
      ClearanceProduct product, String message, String title, dynamic error) {
    if (!mounted) return;

    // Log the error for debugging
    print('Add to Cart Error - $title: $error');

    // Determine the appropriate icon and color based on error type
    IconData errorIcon = Icons.error_outline;
    Color backgroundColor = Colors.red.shade600;

    if (title.contains('Timeout') || title.contains('Connection')) {
      errorIcon = Icons.wifi_off;
      backgroundColor = Colors.orange.shade600;
    } else if (title.contains('Server')) {
      errorIcon = Icons.cloud_off;
      backgroundColor = Colors.red.shade700;
    } else if (title.contains('Data')) {
      errorIcon = Icons.data_usage;
      backgroundColor = Colors.amber.shade700;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  errorIcon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _addToCart(product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _isLoading ? _buildSkeletonWithLoading() : _buildMainContent(),
      bottomNavigationBar: null, // No bottom nav for clearance page
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 50.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 400,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_error != null) {
      return _buildErrorState();
    }

    return Material(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          bool isTablet = screenWidth >= 600;

          // Enhanced responsive dimensions for tablet
          double cardFontSize = isTablet ? 16 : (screenWidth < 400 ? 11 : 13);
          double cardPadding = isTablet ? 16 : (screenWidth < 400 ? 6 : 8);
          double cardImageHeight =
              isTablet ? 70 : (screenWidth < 400 ? 55 : 75);

          return Stack(
            children: [
              SmartRefresher(
                controller: _refreshController,
                onRefresh: _handleRefresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // App Bar
                    SliverAppBar(
                      automaticallyImplyLeading: true,
                      backgroundColor:
                          Theme.of(context).appBarTheme.backgroundColor,
                      toolbarHeight: isTablet ? 80 : 60,
                      floating: false,
                      pinned: false,
                      leading: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: isTablet ? 20 : 18,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          splashRadius: 20,
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: isTablet ? 16 : 1),
                            child: Image.asset(
                              'assets/images/png.png',
                              height: isTablet ? 100 : 85,
                            ),
                          ),
                          CartIconButton(
                            iconColor: Colors.white,
                            iconSize: isTablet ? 28 : 24,
                            backgroundColor: Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: SliverSearchBarDelegate(
                        builder: (shrinkOffset) {
                          return _buildSearchBar(isTablet: isTablet);
                        },
                      ),
                    ),
                    // Clearance Banner
                    SliverToBoxAdapter(
                      child: Consumer<ClearanceSaleProvider>(
                        builder: (context, clearanceProvider, child) {
                          return _buildClearanceBanner();
                        },
                      ),
                    ),
                    // Filter and Sort Section
                    SliverToBoxAdapter(
                      child: _buildFilterAndSortSection(),
                    ),
                    // Featured Products Carousel
                    SliverToBoxAdapter(
                      child: _buildFeaturedProductsCarousel(),
                    ),
                    // Clearance Products Section Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 16.0),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.red[600]!,
                                    Colors.red[700]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Clearance Sale - ${_filteredProducts.length} Products',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
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
                    // Clearance Products Grid
                    SliverToBoxAdapter(
                      child: _buildClearanceProductsGrid(
                        fontSize: cardFontSize,
                        padding: cardPadding,
                        imageHeight: cardImageHeight,
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar({bool isTablet = false}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: 8.0,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search clearance products...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: isTablet ? 16 : 14,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(
                    query: value,
                    products: _clearanceProducts
                        .map((cp) => Product(
                              id: cp.id,
                              name: cp.name,
                              description: cp.description,
                              urlName: cp.urlName,
                              status: cp.status,
                              batch_no: cp.batchNo,
                              price: cp.clearancePrice
                                  .toString(), // Use clearance price
                              thumbnail: cp.thumbnail,
                              quantity: cp.quantity,
                              category: cp.category,
                              route: cp.route,
                            ))
                        .toList(),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildClearanceBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red[600]!,
            Colors.red[700]!,
            Colors.orange[600]!,
            Colors.deepOrange[600]!,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 15),
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated background elements
          Positioned(
            right: -30,
            top: -30,
            child: _pulseController != null
                ? AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController!.value * 0.1),
                        child: Icon(
                          Icons.local_fire_department,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      );
                    },
                  )
                : Icon(
                    Icons.local_fire_department,
                    size: 100,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: _pulseController != null
                ? AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController!.value * 0.05),
                        child: Icon(
                          Icons.star,
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      );
                    },
                  )
                : Icon(
                    Icons.star,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
          ),
          // Floating sparkles
          ...List.generate(8, (index) {
            return Positioned(
              left: (index * 50.0) % 300,
              top: (index * 30.0) % 150,
              child: _pulseController != null
                  ? AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            (index % 2 == 0 ? 1 : -1) *
                                (_pulseController!.value * 5),
                            (index % 3 == 0 ? 1 : -1) *
                                (_pulseController!.value * 3),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 8 + (index % 3) * 2,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.auto_awesome,
                      size: 8 + (index % 3) * 2,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
            );
          }),
          // Main content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sale badge with animation
                      _pulseController != null
                          ? AnimatedBuilder(
                              animation: _pulseController!,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_pulseController!.value * 0.05),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'MEGA SALE',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.3),
                                                offset: const Offset(1, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'MEGA SALE',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          offset: const Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 6),

                      _pulseController != null
                          ? AnimatedBuilder(
                              animation: _pulseController!,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_pulseController!.value * 0.02),
                                  child: Text(
                                    'Up to ${_getMaxDiscountPercentage()}% OFF',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.4),
                                          offset: const Offset(2, 2),
                                          blurRadius: 4,
                                        ),
                                        Shadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          offset: const Offset(-1, -1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Text(
                              'Up to ${_getMaxDiscountPercentage()}% OFF',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    offset: const Offset(-1, -1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 4),
                      // Statistics row
                      Row(
                        children: [
                          _buildStatItem(
                              '${_clearanceProducts.length}', 'Products'),
                          const SizedBox(width: 16),
                          _buildStatItem(
                              '${_getMaxDiscountPercentage()}%', 'Max Save'),
                          const SizedBox(width: 16),
                          _buildStatItem('24h', 'Left'),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Text(
                            'Shop Now',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _pulseController != null
                              ? AnimatedBuilder(
                                  animation: _pulseController!,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                          _pulseController!.value * 3, 0),
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 12,
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right side discount badge
                _pulseController != null
                    ? AnimatedBuilder(
                        animation: _pulseController!,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController!.value * 0.08),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    blurRadius: 10,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SAVE',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red[600],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    '${_getMaxDiscountPercentage()}%',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red[600],
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'OFF',
                                    style: GoogleFonts.poppins(
                                      color: Colors.orange[600],
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SAVE',
                              style: GoogleFonts.poppins(
                                color: Colors.red[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              '${_getMaxDiscountPercentage()}%',
                              style: GoogleFonts.poppins(
                                color: Colors.red[600],
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'OFF',
                              style: GoogleFonts.poppins(
                                color: Colors.orange[600],
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterAndSortSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Filter
          Container(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                // Debug: Print categories being rendered
                if (index == 0) {
                  print('🔍 Rendering categories: $_categories');
                }
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      _onCategoryChanged(category);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.red[600],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? Colors.red[600]! : Colors.grey[300]!,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Sort Options
          Row(
            children: [
              Icon(
                Icons.sort,
                color: Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Sort by:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'price_low',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward,
                                  size: 16, color: Colors.green[600]),
                              const SizedBox(width: 8),
                              Text('Price: Low to High'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'price_high',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward,
                                  size: 16, color: Colors.orange[600]),
                              const SizedBox(width: 8),
                              Text('Price: High to Low'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'name',
                          child: Row(
                            children: [
                              Icon(Icons.sort_by_alpha,
                                  size: 16, color: Colors.purple[600]),
                              const SizedBox(width: 8),
                              Text('Name A-Z'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _onSortChanged(value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Results count
          Text(
            '${_filteredProducts.length} products found',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<ClearanceProduct> _getFeaturedProducts() {
    if (_clearanceProducts.isEmpty) return [];

    final products = _clearanceProducts.toList();

    products.shuffle();

    return products.take(5).toList();
  }

  Widget _buildFeaturedProductsCarousel() {
    if (_clearanceProducts.isEmpty) return const SizedBox.shrink();

    // Get 5 random discounted products
    final featuredProducts = _getFeaturedProducts();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Featured Deals',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Random Picks',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.swipe,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Carousel
          Container(
            height: 150,
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollStartNotification) {
                      _stopAutoScroll();
                    } else if (notification is ScrollEndNotification) {
                      _startAutoScroll();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _featuredScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: featuredProducts.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final product = featuredProducts[index];
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        child: _buildFeaturedProductCard(product),
                      );
                    },
                  ),
                ),
                // Right fade indicator
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProductCard(ClearanceProduct product) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image
            Container(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                product.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print(
                      '❌ Featured image loading error for ${product.name}: $error');
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.medication,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  );
                },
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Discount badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Product name
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Price
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'GHS ${product.clearancePrice.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'GHS ${product.originalPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Tap indicator
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
            // Tap gesture
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClearanceItemDetailPage(
                          product: product,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearanceProductsGrid({
    required double fontSize,
    required double padding,
    required double imageHeight,
    bool isTablet = false,
  }) {
    if (_filteredProducts.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 50,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No clearance products available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        childAspectRatio: isTablet ? 1.0 : 0.9,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
      ),
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildClearanceProductCard(
          product: product,
          fontSize: fontSize,
          padding: padding,
          imageHeight: imageHeight,
        );
      },
    );
  }

  Widget _buildClearanceProductCard({
    required ClearanceProduct product,
    required double fontSize,
    required double padding,
    required double imageHeight,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClearanceItemDetailPage(
                    product: product,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          child: Image.network(
                            product.thumbnail,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey[50],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue[300]!),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  '❌ Image loading error for ${product.name}: $error');
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey[50],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.medication,
                                      color: Colors.grey[400],
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No Image',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Discount Badge with animation
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _pulseController != null
                              ? AnimatedBuilder(
                                  animation: _pulseController!,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 +
                                          (_pulseController!.value * 0.05),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.red[600]!,
                                              Colors.red[700]!,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.trending_down,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${product.discountPercentage.toStringAsFixed(0)}%',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.red[600]!,
                                        Colors.red[700]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.red.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.trending_down,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${product.discountPercentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Product Details section
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Product name with category (only show Prescribed badge)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: fontSize * 0.85,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Only show prescribed badge if it's prescribed
                              if (product.isPrescribed == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Text(
                                    'Prescription',
                                    style: _safeGoogleFonts(
                                      fontSize: fontSize * 0.5,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Price section
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'GHS ${product.clearancePrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: fontSize * 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.red[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'GHS ${product.originalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: fontSize * 0.7,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Savings info
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Save GHS ${product.discountAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: fontSize * 0.6,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon with animation
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),

            // Error title
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Error message
            Text(
              _error ??
                  'Unable to load clearance products. Please check your connection and try again.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Retry button
                ElevatedButton.icon(
                  onPressed: _loadClearanceData,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Go back button
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, size: 18),
                  label: Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Help text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If the problem persists, please check your internet connection or contact support.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
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
}

class SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double shrinkOffset) builder;

  SliverSearchBarDelegate({required this.builder});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: builder(shrinkOffset),
    );
  }

  @override
  double get maxExtent => 56.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
