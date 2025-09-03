// pages/clearance_homepage.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/clearance_sale_provider.dart';
import '../services/clearance_sale_api_service.dart';
import '../widgets/cart_icon_button.dart';
import 'itemdetail.dart';
import 'search_results_page.dart';
import 'product_model.dart';

class ClearanceHomePage extends StatefulWidget {
  const ClearanceHomePage({super.key});

  @override
  State<ClearanceHomePage> createState() => _ClearanceHomePageState();
}

class _ClearanceHomePageState extends State<ClearanceHomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<ClearanceProduct> _clearanceProducts = [];
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Clear any cached network images to prevent conflicts
    imageCache.clear();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClearanceData();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClearanceData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load mock clearance products directly
      await _loadMockClearanceProducts();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMockClearanceProducts() async {
    // Add a small delay to simulate loading
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data as fallback
    final mockProducts = [
      ClearanceProduct(
        id: 1,
        name: "Paracetamol 500mg",
        description: "Pain relief medication",
        urlName: "paracetamol-500mg",
        status: "active",
        batchNo: "B001",
        originalPrice: 15.00,
        clearancePrice: 7.50,
        discountAmount: 7.50,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular1.png",
        quantity: "100",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 2,
        name: "Vitamin C 1000mg",
        description: "Immune system support",
        urlName: "vitamin-c-1000mg",
        status: "active",
        batchNo: "B002",
        originalPrice: 25.00,
        clearancePrice: 12.50,
        discountAmount: 12.50,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular2.png",
        quantity: "50",
        category: "Vitamins",
        route: "oral",
      ),
      ClearanceProduct(
        id: 3,
        name: "Ibuprofen 400mg",
        description: "Anti-inflammatory pain relief",
        urlName: "ibuprofen-400mg",
        status: "active",
        batchNo: "B003",
        originalPrice: 20.00,
        clearancePrice: 10.00,
        discountAmount: 10.00,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular3.png",
        quantity: "75",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 4,
        name: "Multivitamin Complex",
        description: "Daily vitamin supplement",
        urlName: "multivitamin-complex",
        status: "active",
        batchNo: "B004",
        originalPrice: 30.00,
        clearancePrice: 15.00,
        discountAmount: 15.00,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular4.png",
        quantity: "60",
        category: "Vitamins",
        route: "oral",
      ),
      ClearanceProduct(
        id: 5,
        name: "Aspirin 100mg",
        description: "Blood thinner and pain relief",
        urlName: "aspirin-100mg",
        status: "active",
        batchNo: "B005",
        originalPrice: 12.00,
        clearancePrice: 6.00,
        discountAmount: 6.00,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular5.png",
        quantity: "90",
        category: "Pain Relief",
        route: "oral",
      ),
      ClearanceProduct(
        id: 6,
        name: "Calcium Supplement",
        description: "Bone health support",
        urlName: "calcium-supplement",
        status: "active",
        batchNo: "B006",
        originalPrice: 18.00,
        clearancePrice: 9.00,
        discountAmount: 9.00,
        discountPercentage: 50.0,
        thumbnail: "assets/images/popular6.png",
        quantity: "120",
        category: "Supplements",
        route: "oral",
      ),
    ];

    setState(() {
      _clearanceProducts = mockProducts;
    });

    // Force banner update with actual percentage
    print('Loaded ${_clearanceProducts.length} clearance products');
    print('Banner will show: Up to ${_getMaxDiscountPercentage()}% OFF');
  }

  Future<void> _handleRefresh() async {
    await _loadClearanceData();
    _refreshController.refreshCompleted();
  }

  int _getMaxDiscountPercentage() {
    if (_clearanceProducts.isEmpty) return 50;

    double maxDiscount = 0;
    for (var product in _clearanceProducts) {
      if (product.discountPercentage > maxDiscount) {
        maxDiscount = product.discountPercentage;
      }
    }

    final result = maxDiscount.round();
    print(
        'Max discount percentage: $result% (from ${_clearanceProducts.length} products)');
    return result;
  }

  void _addToCart(ClearanceProduct product) {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${product.name} added to cart',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Here you would typically add the product to your cart provider
    // For now, we'll just show the success message
    print('Added to cart: ${product.name} - GHS ${product.clearancePrice}');
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
                      child: _buildClearanceBanner(),
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
                                      'Clearance Sale - ${_clearanceProducts.length} Products',
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
            contentPadding: EdgeInsets.symmetric(vertical: 12),
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
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red[600]!,
            Colors.red[700]!,
            Colors.orange[600]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.local_fire_department,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '🔥 MEGA SALE',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Up to ${_getMaxDiscountPercentage()}% OFF',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Limited time offer',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearanceProductsGrid({
    required double fontSize,
    required double padding,
    required double imageHeight,
    bool isTablet = false,
  }) {
    if (_clearanceProducts.isEmpty) {
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
      itemCount: _clearanceProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        childAspectRatio: isTablet ? 1.2 : 1.0,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
      ),
      itemBuilder: (context, index) {
        final product = _clearanceProducts[index];
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
        aspectRatio: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemPage(
                              urlName: product.urlName,
                              isPrescribed: false,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Hero(
                          tag:
                              'clearance-product-image-${product.id}-${product.urlName}',
                          child: Container(
                            color: Colors.grey[100],
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              child: Image.asset(
                                product.thumbnail,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medication,
                                        color: Colors.grey[400],
                                        size: 30,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.name.split(' ')[0],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Discount Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-${product.discountPercentage.toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Fire Icon
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_fire_department,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    // Add to Cart Icon
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          _addToCart(product);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shopping_cart,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Product Details
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'GHS ${product.clearancePrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: fontSize * 1.1,
                          fontWeight: FontWeight.w700,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GHS ${product.originalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: fontSize * 0.8,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Save GHS ${product.discountAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: fontSize * 0.7,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 50,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Clearance Products',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadClearanceData,
            icon: Icon(Icons.refresh, color: Colors.blue),
            label: Text(
              'Retry',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
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
      color: shrinkOffset > 0
          ? Theme.of(context).appBarTheme.backgroundColor
          : Colors.white,
      child: builder(shrinkOffset),
    );
  }

  @override
  double get maxExtent => 64.0;

  @override
  double get minExtent => 64.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
