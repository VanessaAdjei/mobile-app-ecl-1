// pages/homepage.dart
import 'package:eclapp/pages/signinpage.dart';
import 'package:eclapp/pages/storelocation.dart';
import 'package:eclapp/pages/categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ProductModel.dart';
import 'auth_service.dart';
import 'bottomnav.dart';
import 'itemdetail.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_results_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/cart_icon_button.dart';
import '../widgets/product_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Import the new health tips service and model
import '../services/health_tips_service.dart';
import '../models/health_tip.dart';
import '../services/banner_cache_service.dart';
import '../services/homepage_optimization_service.dart';

// Image preloading service for better performance
class ImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  static void preloadImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty || _preloadedImages.containsKey(imageUrl)) return;

    _preloadedImages[imageUrl] = true;
    precacheImage(CachedNetworkImageProvider(imageUrl), context);
  }

  static void preloadImages(List<String> imageUrls, BuildContext context) {
    for (final imageUrl in imageUrls) {
      preloadImage(imageUrl, context);
    }
  }

  static void clearPreloadedImages() {
    _preloadedImages.clear();
  }

  static bool isPreloaded(String imageUrl) {
    return _preloadedImages.containsKey(imageUrl);
  }
}

// Global cache for products to persist across navigation
class ProductCache {
  static List<Product> _cachedProducts = [];
  static List<Product> _cachedPopularProducts = [];
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  static void cacheProducts(List<Product> products) {
    _cachedProducts = products;
    _lastCacheTime = DateTime.now();
  }

  static void cachePopularProducts(List<Product> products) {
    _cachedPopularProducts = products;
  }

  static List<Product> get cachedProducts => _cachedProducts;
  static List<Product> get cachedPopularProducts => _cachedPopularProducts;

  static void clearCache() {
    _cachedProducts.clear();
    _cachedPopularProducts.clear();
    _lastCacheTime = null;
  }
}

class ErrorDisplayWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({
    Key? key,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 50,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: Colors.blue),
              label: Text(
                'Retry',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  SliverSearchBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: shrinkOffset > 0
          ? Theme.of(context).appBarTheme.backgroundColor
          : Colors.white,
      child: child,
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isLoadingPopular = true;
  bool _isLoadingHealthTips = true;
  bool _isFetchingHealthTips = false; // Add flag to prevent multiple calls
  String? _error;
  String? _popularError;
  String? _healthTipsError;
  List<Product> _products = [];
  List<Product> filteredProducts = [];
  List<Product> popularProducts = [];
  List<HealthTip> healthTips = <HealthTip>[];
  final RefreshController _refreshController = RefreshController();
  bool _allContentLoaded = false;
  TextEditingController searchController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  // Health tips carousel state
  final PageController _healthTipsPageController =
      PageController(viewportFraction: 0.92);
  int _currentHealthTipsPage = 0;

  List<Product> otcpomProducts = [];
  List<Product> drugProducts = [];
  List<Product> wellnessProducts = [];
  List<Product> selfcareProducts = [];
  List<Product> accessoriesProducts = [];
  List<Product> drugsSectionProducts = [];

  // Image preloading controller
  final Map<String, bool> _preloadedImages = {};

  // Optimization service
  final HomepageOptimizationService _optimizationService =
      HomepageOptimizationService();

  _launchPhoneDialer(String phoneNumber) async {
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus.isGranted) {
      final String formattedPhoneNumber = 'tel:$phoneNumber';
      if (await canLaunch(formattedPhoneNumber)) {
        await launch(formattedPhoneNumber);
      } else {}
    } else {}
  }

  Future<bool> requireAuth(BuildContext context) async {
    if (await AuthService.isLoggedIn()) return true;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SignInScreen(
          returnTo: ModalRoute.of(context)?.settings.name,
        ),
      ),
    );

    return result ?? false;
  }

  _launchWhatsApp(String phoneNumber, String message) async {
    if (phoneNumber.isEmpty || message.isEmpty) {
      return;
    }

    if (!phoneNumber.startsWith('+')) {
      return;
    }

    String whatsappUrl =
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';

    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      showTopSnackBar(
          context, 'Could not open WhatsApp. Please ensure it is installed.');
    }
  }

  Future<void> _loadAllContent() async {
    print('HomePage: _loadAllContent called');
    setState(() => _allContentLoaded = false);
    try {
      // Load products first, then popular products and health tips
      print('HomePage: Loading products');
      await loadProducts();

      // Load popular products in background if not cached
      if (ProductCache.cachedPopularProducts.isEmpty) {
        print('HomePage: Loading popular products');
        _fetchPopularProducts();
      } else {
        print('HomePage: Using cached popular products');
        setState(() {
          popularProducts = ProductCache.cachedPopularProducts;
          _isLoadingPopular = false;
        });
      }

      // Always load fresh health tips on refresh
      print('HomePage: Loading fresh health tips');
      HealthTipsService.clearCache(); // Clear cache to force fresh fetch
      _fetchHealthTips();
    } catch (e) {
      print('HomePage: Exception in _loadAllContent: $e');
      // Handle error without cache fallback
    } finally {
      if (mounted) {
        setState(() => _allContentLoaded = true);
        print('HomePage: _loadAllContent completed');
      }
    }
  }

  Future<void> loadProducts() async {
    // Check if we have valid cached data
    if (ProductCache.isCacheValid && ProductCache.cachedProducts.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _error = null;
      });

      // Use cached data
      final cachedProducts = ProductCache.cachedProducts;
      _processProducts(cachedProducts);

      // Preload images in background
      _preloadImages(cachedProducts);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];
        final allProducts = dataList.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: item['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
            quantity: productData['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        // Cache the products
        ProductCache.cacheProducts(allProducts);

        // Process products and update state
        _processProducts(allProducts);

        // Preload images in background
        _preloadImages(allProducts);
      } else {
        throw Exception('Server error');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Connection timed out';
          _isLoading = false;
        });
      }
    } on http.ClientException {
      if (mounted) {
        setState(() {
          _error = 'No internet connection';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _refreshController.refreshCompleted();
    }
  }

  // Helper method to process products and categorize them
  void _processProducts(List<Product> allProducts) {
    if (!mounted) return;

    setState(() {
      _products = allProducts;
      filteredProducts = allProducts;
    });

    // Optimize filtering by doing it once
    final List<Product> otcDrugProducts = [];
    final List<Product> wellnessList = [];
    final List<Product> selfcareList = [];
    final List<Product> accessoriesList = [];

    for (final product in allProducts) {
      if ((product.otcpom != null &&
              product.otcpom!.trim().toLowerCase() == 'otc') ||
          (product.drug != null &&
              product.drug!.trim().toLowerCase() == 'drug')) {
        otcDrugProducts.add(product);
      }
      if (product.wellness != null && product.wellness!.trim().isNotEmpty) {
        wellnessList.add(product);
      }
      if (product.selfcare != null && product.selfcare!.trim().isNotEmpty) {
        selfcareList.add(product);
      }
      if (product.accessories != null &&
          product.accessories!.trim().isNotEmpty) {
        accessoriesList.add(product);
      }
    }

    // Shuffle lists efficiently
    otcDrugProducts.shuffle();
    wellnessList.shuffle();
    selfcareList.shuffle();
    accessoriesList.shuffle();

    if (mounted) {
      setState(() {
        drugsSectionProducts = otcDrugProducts;
        wellnessProducts = wellnessList;
        selfcareProducts = selfcareList;
        accessoriesProducts = accessoriesList;
      });
    }
  }

  // Preload images for better performance
  void _preloadImages(List<Product> products) {
    final imageUrls = products
        .take(20) // Preload first 20 images
        .map((product) => getProductImageUrl(product.thumbnail))
        .where((url) => url.isNotEmpty)
        .toList();

    ImagePreloader.preloadImages(imageUrls, context);
  }

  Future<void> _fetchPopularProducts() async {
    if (!mounted) return;

    // Check if we have cached popular products
    if (ProductCache.cachedPopularProducts.isNotEmpty) {
      setState(() {
        popularProducts = ProductCache.cachedPopularProducts;
        _isLoadingPopular = false;
      });
      return;
    }

    setState(() {
      _isLoadingPopular = true;
      _popularError = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/popular-products'),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> productsData = data['data'] ?? [];
        if (!mounted) return;

        final popularProductsList = productsData.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: item['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? '',
            quantity: item['qty_in_stock']?.toString() ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
            otcpom: productData['otcpom'],
            drug: productData['drug'],
            wellness: productData['wellness'],
            selfcare: productData['selfcare'],
            accessories: productData['accessories'],
          );
        }).toList();

        // Cache popular products
        ProductCache.cachePopularProducts(popularProductsList);

        if (!mounted) return;
        setState(() {
          popularProducts = popularProductsList;
          _isLoadingPopular = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _popularError = 'Server error';
          _isLoadingPopular = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _popularError = 'Connection timed out';
        _isLoadingPopular = false;
      });
    } on http.ClientException {
      if (!mounted) return;
      setState(() {
        _popularError = 'No internet connection';
        _isLoadingPopular = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _popularError = 'Something went wrong';
        _isLoadingPopular = false;
      });
    }
  }

  Future<void> _fetchHealthTips() async {
    print('HomePage: _fetchHealthTips called');
    if (!mounted) return;

    // Prevent multiple simultaneous calls
    if (_isFetchingHealthTips) {
      print('HomePage: Health tips fetch already in progress, skipping');
      return;
    }

    setState(() {
      _isLoadingHealthTips = true;
      _healthTipsError = null;
      _isFetchingHealthTips = true;
    });

    try {
      print(
          'HomePage: Calling HealthTipsService.fetchHealthTips with random parameters');
      // Use the new MyHealthfinder API service with random parameters for variety
      final tips = await HealthTipsService.fetchHealthTips(
        limit: 6,
      );
      print('HomePage: Received ${tips.length} tips from service');

      // Debug: Print the first tip details
      if (tips.isNotEmpty) {
        print(
            'HomePage: First tip - Title: "${tips[0].title}", Category: "${tips[0].category}"');
        print('HomePage: First tip - Summary: "${tips[0].summary}"');
        print('HomePage: First tip - Content: "${tips[0].content}"');
      }

      if (!mounted) return;

      if (tips.isNotEmpty) {
        print('HomePage: Setting health tips in state');
        setState(() {
          healthTips = List<HealthTip>.from(tips); // Ensure correct type
          _isLoadingHealthTips = false;
          _isFetchingHealthTips = false;
        });
        print(
            'HomePage: Health tips set successfully. healthTips.length = ${healthTips.length}');
      } else {
        print('HomePage: No tips received, loading default tips');
        _loadDefaultHealthTips();
      }
    } catch (e) {
      print('HomePage: Exception in _fetchHealthTips: $e');
      if (!mounted) return;
      _loadDefaultHealthTips();
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingHealthTips = false;
        });
      }
    }
  }

  void _loadDefaultHealthTips() {
    if (!mounted) return;

    setState(() {
      healthTips = <HealthTip>[
        HealthTip(
          title: 'Stay Hydrated',
          url: '',
          content: 'Drink 8 glasses of water daily for better health',
          category: 'Wellness',
          summary:
              'Proper hydration helps maintain body temperature, lubricate joints, and transport nutrients throughout your body.',
        ),
        HealthTip(
          title: 'Exercise Regularly',
          url: '',
          content: '30 minutes of daily exercise keeps you fit',
          category: 'Physical Activity',
          summary:
              'Regular physical activity strengthens your heart, improves mood, and helps maintain a healthy weight.',
        ),
        HealthTip(
          title: 'Get Enough Sleep',
          url: '',
          content: '7-8 hours of sleep is essential for health',
          category: 'Wellness',
          summary:
              'Quality sleep supports immune function, memory consolidation, and overall physical and mental recovery.',
        ),
        HealthTip(
          title: 'Eat Healthy',
          url: '',
          content: 'Include fruits and vegetables in your diet',
          category: 'Nutrition',
          summary:
              'A balanced diet rich in fruits, vegetables, and whole grains provides essential nutrients for optimal health.',
        ),
        HealthTip(
          title: 'Wash Hands',
          url: '',
          content: 'Regular hand washing prevents infections',
          category: 'Prevention',
          summary:
              'Proper hand hygiene is one of the most effective ways to prevent the spread of germs and infections.',
        ),
        HealthTip(
          title: 'Take Breaks',
          url: '',
          content: 'Take regular breaks from screen time',
          category: 'Wellness',
          summary:
              'Regular breaks from digital devices help reduce eye strain, improve posture, and maintain mental well-being.',
        ),
      ];
      _isLoadingHealthTips = false;
      _isFetchingHealthTips = false;
    });
  }

  Widget _buildHealthTips() {
    print(
        'HomePage: _buildHealthTips called - healthTips.length = ${healthTips.length}, _isLoadingHealthTips = $_isLoadingHealthTips, _healthTipsError = $_healthTipsError');

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.health_and_safety,
                    color: Colors.cyan[700], size: 22),
                SizedBox(width: 8),
                Text(
                  'Health Tips',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${healthTips.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (_isLoadingHealthTips)
            Container(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_healthTipsError != null)
            Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text('Could not load health tips',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14)),
                    SizedBox(height: 8),
                    TextButton(
                        onPressed: _fetchHealthTips, child: Text('Retry')),
                  ],
                ),
              ),
            )
          else if (healthTips.isEmpty)
            Container(
              height: 200,
              child: Center(
                  child: Text('No health tips available',
                      style: TextStyle(color: Colors.grey[600]))),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _healthTipsPageController,
                    itemCount: healthTips.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentHealthTipsPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final tip = healthTips[index];
                      return _buildCarouselHealthTipCard(tip, height: 200);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(healthTips.length, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentHealthTipsPage == index
                            ? Colors.cyan[700]
                            : Colors.cyan[200],
                      ),
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselHealthTipCard(HealthTip tip, {double height = 200}) {
    final color = _getColorFromCategory(tip.category);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Image
            tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                ? Image.network(
                    tip.imageUrl!,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: height,
                    color: color.withOpacity(0.15),
                    child: Center(
                      child:
                          Icon(Icons.health_and_safety, color: color, size: 48),
                    ),
                  ),
            // Gradient overlay
            Container(
              width: double.infinity,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Category badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getShortCategoryName(tip.category),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Text overlay
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    tip.summary ?? tip.content,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 10.5,
                      height: 1.3,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'wellness':
        return Icons.favorite;
      case 'physical activity':
      case 'exercise':
        return Icons.fitness_center;
      case 'nutrition':
      case 'diet':
        return Icons.restaurant;
      case 'prevention':
        return Icons.shield;
      case 'mental health':
        return Icons.psychology;
      case 'heart health':
        return Icons.favorite;
      case 'diabetes':
        return Icons.monitor_heart;
      case 'cancer':
        return Icons.local_hospital;
      case 'pregnancy':
        return Icons.pregnant_woman;
      case 'vaccinations':
      case 'immunizations':
        return Icons.vaccines;
      default:
        return Icons.health_and_safety;
    }
  }

  Color _getColorFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'wellness':
        return Colors.green[600]!;
      case 'physical activity':
      case 'exercise':
        return Colors.blue[600]!;
      case 'nutrition':
      case 'diet':
        return Colors.orange[600]!;
      case 'prevention':
        return Colors.purple[600]!;
      case 'mental health':
        return Colors.indigo[600]!;
      case 'heart health':
        return Colors.red[600]!;
      case 'diabetes':
        return Colors.teal[600]!;
      case 'cancer':
        return Colors.pink[600]!;
      case 'pregnancy':
        return Colors.pink[400]!;
      case 'vaccinations':
      case 'immunizations':
        return Colors.cyan[600]!;
      default:
        return Colors.green[600]!;
    }
  }

  String _getShortCategoryName(String category) {
    // Handle long category names by taking the first meaningful part
    if (category.contains(',')) {
      return category.split(',')[0].trim();
    }

    // Handle specific long categories
    switch (category.toLowerCase()) {
      case 'hiv and other stis, screening tests, sexual health':
        return 'Sexual Health';
      case 'cervical cancer, vaccines (shots)':
        return 'Cancer Prevention';
      case 'screening tests':
        return 'Screening';
      case 'heart health':
        return 'Heart Health';
      case 'mental health':
        return 'Mental Health';
      case 'physical activity':
        return 'Exercise';
      case 'nutrition':
        return 'Nutrition';
      case 'prevention':
        return 'Prevention';
      case 'wellness':
        return 'Wellness';
      case 'pregnancy':
        return 'Pregnancy';
      case 'vaccinations':
      case 'immunizations':
        return 'Vaccines';
      default:
        // If category is still too long, truncate it
        if (category.length > 15) {
          return category.substring(0, 15) + '...';
        }
        return category;
    }
  }

  void makePhoneCall(String phoneNumber) async {
    final Uri callUri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      throw "Could not launch $callUri";
    }
  }

  void _showContactOptions(String phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Contact Us',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Choose how you\'d like to reach us',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Call option
              _buildContactOption(
                icon: Icons.phone_rounded,
                title: 'Call Us',
                subtitle: '+233 000 000 0000',
                color: Colors.green.shade600,
                onTap: () {
                  Navigator.pop(context);
                  _launchPhoneDialer(phoneNumber);
                  makePhoneCall(phoneNumber);
                },
              ),

              const SizedBox(height: 12),

              // WhatsApp option
              _buildContactOption(
                icon: Icons.message_rounded,
                title: 'WhatsApp',
                subtitle: 'Chat with us instantly',
                color: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  _launchWhatsApp(
                      phoneNumber, "Hello, I'm interested in your products!");
                },
              ),

              const SizedBox(height: 12),

              // Email option
              _buildContactOption(
                icon: Icons.email_rounded,
                title: 'Email Us',
                subtitle: 'support@ernestchemists.com',
                color: Colors.blue.shade600,
                onTap: () {
                  Navigator.pop(context);
                  _launchEmail(
                      'support@ernestchemists.com', 'ECL Support Request');
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _launchEmail(String email, String subject) async {
    try {
      final String emailBody =
          'Hello,\n\nI would like to contact Ernest Chemists Limited for support.\n\nBest regards,';
      final Uri emailUri = Uri.parse(
          'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody)}');

      final bool launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showEmailAlternatives(email);
      }
    } catch (e) {
      _showEmailAlternatives(email);
    }
  }

  void _showEmailAlternatives(String email) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                'Email Not Available',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No email app found on your device. Here are alternative ways to contact us:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Email Address:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: email));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text('Email copied to clipboard'),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can copy the email address and use it in your preferred email app.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearCacheAndReload() async {
    ProductCache.clearCache();
    ImagePreloader.clearPreloadedImages();
    HealthTipsService.clearCache(); // Clear health tips cache
    _preloadedImages.clear();
    await _loadAllContent();
  }

  @override
  void initState() {
    super.initState();
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    // Clear any old cached data to prevent type mismatches
    HealthTipsService.clearCache();
    _initializeOptimizationService();
    _loadContentOptimized();
    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && !_isScrolled) {
        setState(() {
          _isScrolled = true;
        });
      } else if (_scrollController.offset <= 100 && _isScrolled) {
        setState(() {
          _isScrolled = false;
        });
      }
    });
  }

  Future<void> _initializeOptimizationService() async {
    await _optimizationService.initialize();

    // Load cached data immediately if available
    if (_optimizationService.hasCachedProducts) {
      setState(() {
        _products = _optimizationService.cachedProducts;
        filteredProducts = _optimizationService.cachedProducts;
        _isLoading = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    _healthTipsPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_products.isNotEmpty && _preloadedImages.isEmpty) {
      _preloadImages(_products);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh health tips when app becomes active
    if (state == AppLifecycleState.resumed) {
      _fetchHealthTips();
    }
  }

  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration}) {
    final overlay = Overlay.of(context);

    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green[900],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration ?? const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TypeAheadField<Product>(
        textFieldConfiguration: TextFieldConfiguration(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search medicines, products...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(
                    query: value.trim(),
                    products: _products,
                  ),
                ),
              );
            }
          },
        ),
        suggestionsCallback: (pattern) async {
          if (pattern.isEmpty) {
            return [];
          }
          try {
            final response = await http
                .get(
                  Uri.parse(
                      'https://eclcommerce.ernestchemists.com.gh/api/search/' +
                          pattern),
                )
                .timeout(Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List productsData = data['data'] ?? [];
              final products = productsData.map<Product>((item) {
                return Product(
                  id: item['id'] ?? 0,
                  name: item['name'] ?? 'No name',
                  description: item['tag_description'] ?? '',
                  urlName: item['url_name'] ?? '',
                  status: item['status'] ?? '',
                  batch_no: item['batch_no'] ?? '',
                  price:
                      (item['price'] ?? item['selling_price'] ?? 0).toString(),
                  thumbnail: item['thumbnail'] ?? item['image'] ?? '',
                  quantity: item['quantity']?.toString() ?? '',
                  category: item['category'] ?? '',
                  route: item['route'] ?? '',
                );
              }).toList();
              if (products.length > 1) {
                return [
                  Product(
                    id: -1,
                    name: '__VIEW_MORE__',
                    description: '',
                    urlName: '',
                    status: '',
                    price: '',
                    thumbnail: '',
                    quantity: '',
                    batch_no: '',
                    category: '',
                    route: '',
                  ),
                  ...products.take(6),
                ];
              }
              return products;
            } else {
              throw Exception('Server error');
            }
          } on TimeoutException {
            return [];
          } on http.ClientException {
            return [];
          } catch (e) {
            return [];
          }
        },
        itemBuilder: (context, Product suggestion) {
          if (suggestion.name == '__VIEW_MORE__') {
            return Container(
              color: Colors.green.withOpacity(0.08),
              child: ListTile(
                leading: Icon(Icons.list, color: Colors.green[700]),
                title: Text(
                  'View All Results',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
          // Try to find the product in the products list by id or name
          final matchingProduct = _products.firstWhere(
            (p) => p.id == suggestion.id || p.name == suggestion.name,
            orElse: () => suggestion,
          );
          final imageUrl = getProductImageUrl(
              matchingProduct.thumbnail.isNotEmpty
                  ? matchingProduct.thumbnail
                  : suggestion.thumbnail);
          return ListTile(
            leading: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              memCacheHeight: 300,
              maxWidthDiskCache: 300,
              maxHeightDiskCache: 300,
              fadeInDuration: Duration(milliseconds: 100),
              fadeOutDuration: Duration(milliseconds: 100),
              placeholder: (context, url) => SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => Icon(Icons.broken_image),
            ),
            title: Text(suggestion.name),
            subtitle: (suggestion.price.isNotEmpty && suggestion.price != '0')
                ? Text('GHS ${suggestion.price}')
                : null,
          );
        },
        onSuggestionSelected: (Product suggestion) {
          final matchingProduct = _products.firstWhere(
            (p) => p.id == suggestion.id || p.name == suggestion.name,
            orElse: () => suggestion,
          );
          final urlName = matchingProduct.urlName.isNotEmpty
              ? matchingProduct.urlName
              : suggestion.urlName;
          if (suggestion.name == '__VIEW_MORE__') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchResultsPage(
                  query: _searchController.text,
                  products: _products,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemPage(
                  urlName: urlName,
                  isPrescribed: matchingProduct.otcpom?.toLowerCase() == 'pom',
                ),
              ),
            );
          }
        },
        noItemsFoundBuilder: (context) => Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Text('No products found', style: TextStyle(color: Colors.grey)),
        ),
        hideOnEmpty: true,
        hideOnLoading: false,
        debounceDuration: Duration(milliseconds: 10),
        suggestionsBoxDecoration: SuggestionsBoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        suggestionsBoxVerticalOffset: 0,
        suggestionsBoxController: null,
      ),
    );
  }

  Widget _buildActionCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.people,
              title: "Meet Our Pharmacists",
              color: Colors.blue[600]!,
              onTap: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => PharmacistsPage()),
                // );
              },
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildActionCard(
              icon: Icons.location_on,
              title: "Store Locator",
              color: Colors.green[600]!,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => StoreSelectionPage()),
                );
              },
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildActionCard(
              icon: Icons.contact_support_rounded,
              title: "Contact Us",
              color: Colors.orange[600]!,
              onTap: () => _showContactOptions("+2330000000000"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: BoxConstraints(
          minWidth: 90,
          maxWidth: 100,
          minHeight: 100,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialOffers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  'assets/images/specialoffer.PNG',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 120,
                ),
              ),
              // Text below image
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GET DEAL 10% OFF ON FIRST PURCHASE',
                      style: GoogleFonts.poppins(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Orders above GH₵100.',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Make purchase through the Ernest Chemists e-commerce platform and get a 10% discount of your first purchase.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        body:
            _allContentLoaded ? _buildMainContent() : _buildOptimizedSkeleton(),
        bottomNavigationBar: CustomBottomNav(),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_error != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          setState(() {
            _error = null;
          });
          _loadAllContent();
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        int crossAxisCount = 2;
        double aspectRatio = 1.2;
        if (screenWidth > 900) {
          crossAxisCount = 4;
          aspectRatio = 1.1;
        } else if (screenWidth > 600) {
          crossAxisCount = 3;
          aspectRatio = 1.15;
        }
        double cardFontSize =
            screenWidth < 400 ? 11 : (screenWidth < 600 ? 13 : 15);
        double cardPadding =
            screenWidth < 400 ? 6 : (screenWidth < 600 ? 8 : 12);
        double cardImageHeight =
            screenWidth < 400 ? 55 : (screenWidth < 600 ? 75 : 95);

        return Stack(
          children: [
            SmartRefresher(
              controller: _refreshController,
              onRefresh: _loadAllContent,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor:
                        Theme.of(context).appBarTheme.backgroundColor,
                    toolbarHeight: 60,
                    floating: false,
                    pinned: false,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 1),
                          child: Image.asset(
                            'assets/images/png.png',
                            height: 85,
                          ),
                        ),
                        CartIconButton(
                          iconColor: Colors.white,
                          iconSize: 24,
                          backgroundColor: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: SliverSearchBarDelegate(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 20.0, left: 10.0, right: 10.0, bottom: 1.0),
                        child: _buildSearchBar(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: buildOrderMedicineCard(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildActionCards(),
                  ),
                  // Bulk Purchase Card - Commented out for now
                  /*
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2), // Reduced vertical margin
                      child: InkWell(
                        onTap: () async {
                          final shouldProceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Bulk Purchase Notice'),
                              content: const Text(
                                'You will be redirected to our website to complete your bulk purchase. This is required for bulk orders as they need special handling and verification.',
                                style: TextStyle(fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Continue to Website'),
                                ),
                              ],
                            ),
                          );

                          if (shouldProceed == true) {
                            final url = Uri.parse(
                                'https://eclcommerce.ernestchemists.com.gh/index');
                            try {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Could not open bulk purchase page'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade600,
                                Colors.blue.shade800
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bulk Purchase',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                Icons.shopping_cart,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  */
                  // Drugs Section
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Drugs',
                      Colors.green[700]!,
                      _getLimitedProducts(drugsSectionProducts),
                      'drugs',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                    ),
                  ),
                  // Special Offers Section
                  SliverToBoxAdapter(
                    child: _buildSpecialOffers(),
                  ),
                  // Wellness Section
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Wellness',
                      Colors.purple[700]!,
                      _getLimitedProducts(wellnessProducts),
                      'wellness',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                    ),
                  ),
                  // Popular Products Section
                  SliverToBoxAdapter(
                    child: _buildPopularProducts(),
                  ),
                  // Selfcare Section
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Selfcare',
                      Colors.orange[700]!,
                      _getLimitedProducts(selfcareProducts),
                      'selfcare',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                    ),
                  ),
                  // Accessories Section
                  SliverToBoxAdapter(
                    child: _buildProductSection(
                      'Accessories',
                      Colors.teal[700]!,
                      _getLimitedProducts(accessoriesProducts),
                      'accessories',
                      fontSize: cardFontSize,
                      padding: cardPadding,
                      imageHeight: cardImageHeight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptimizedSkeleton() {
    // Get screen dimensions for responsive spacing
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive spacing - absolutely minimal
    final responsiveMainAxisSpacing = 0.0; // No spacing at all
    final responsiveCrossAxisSpacing = 0.0; // No spacing at all
    final responsivePadding = 0.0; // No padding at all

    // Ensure minimum and maximum values - absolutely minimal spacing
    final finalMainAxisSpacing = 0.0; // No spacing between rows
    final finalCrossAxisSpacing = 0.0; // No spacing between columns
    final finalPadding = 0.0; // No padding around grid

    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: kToolbarHeight + MediaQuery.of(context).padding.top,
              color: Colors.white,
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    3,
                    (index) => Container(
                          width: (MediaQuery.of(context).size.width - 48) / 3,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )),
              ),
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                mainAxisSpacing: 0.0,
                crossAxisSpacing: 0.0,
              ),
              itemBuilder: (context, index) => _buildProductSkeleton(),
            ),
            Container(
              height: 120,
              margin: const EdgeInsets.all(16),
              color: Colors.white,
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                mainAxisSpacing: 0.0,
                crossAxisSpacing: 0.0,
              ),
              itemBuilder: (context, index) => _buildProductSkeleton(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: 150,
                height: 24,
                color: Colors.white,
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                mainAxisSpacing: 0.0,
                crossAxisSpacing: 0.0,
              ),
              itemBuilder: (context, index) => _buildProductSkeleton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSkeleton() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 80,
                    height: 10,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 50,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check if images are already cached
  bool _areImagesCached() {
    return _preloadedImages.isNotEmpty ||
        ImagePreloader.isPreloaded(
            getProductImageUrl(_products.firstOrNull?.thumbnail ?? ''));
  }

  // Optimized loading that checks cache first
  Future<void> _loadContentOptimized() async {
    // If we have cached data and images are preloaded, use them immediately
    if (ProductCache.isCacheValid &&
        ProductCache.cachedProducts.isNotEmpty &&
        _areImagesCached()) {
      setState(() {
        _isLoading = false;
        _error = null;
        _allContentLoaded = true;
      });

      final cachedProducts = ProductCache.cachedProducts;
      _processProducts(cachedProducts);

      if (ProductCache.cachedPopularProducts.isNotEmpty) {
        setState(() {
          popularProducts = ProductCache.cachedPopularProducts;
          _isLoadingPopular = false;
        });
      }
      return;
    }

    // Otherwise, load normally
    await _loadAllContent();
  }

  Widget _buildPopularProducts() {
    if (_isLoadingPopular) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_popularError != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          setState(() {
            _popularError = null;
          });
          _loadAllContent();
        },
      );
    }
    if (popularProducts.isEmpty) {
      return Center(
        child: Text(
          'No popular products available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Limit popular products for better performance
    final limitedPopularProducts =
        _getLimitedProducts(popularProducts, limit: 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCapsuleHeading('Popular Products', Colors.green[700]!),
        Container(
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: limitedPopularProducts.map((product) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemPage(
                          urlName: product.urlName,
                          isPrescribed: product.otcpom?.toLowerCase() == 'pom',
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl: getProductImageUrl(product.thumbnail),
                            fit: BoxFit.contain,
                            height: 80,
                            width: 80,
                            memCacheWidth: 160,
                            memCacheHeight: 160,
                            maxWidthDiskCache: 160,
                            maxHeightDiskCache: 160,
                            fadeInDuration: Duration(milliseconds: 100),
                            fadeOutDuration: Duration(milliseconds: 100),
                            placeholder: (context, url) {
                              return Center(child: CircularProgressIndicator());
                            },
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.broken_image, size: 32),
                              );
                            },
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Divider(
          color: Colors.grey.shade300,
          thickness: 1.0,
          height: 16,
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Product product, {
    double fontSize = 16,
    double padding = 16,
    double imageHeight = 120,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Reduce card width for more compact layout
    double cardWidth = screenWidth * (screenWidth < 600 ? 0.35 : 0.38);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Prevent overflow
      children: [
        // Card is only the image (square) - more compact
        Container(
          width: cardWidth,
          margin: EdgeInsets.zero, // No margins at all
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemPage(
                        urlName: product.urlName,
                        isPrescribed: product.otcpom?.toLowerCase() == 'pom',
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
              ),
              if (product.otcpom?.toLowerCase() == 'pom')
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
        Container(
          width: cardWidth,
          constraints: BoxConstraints(
              maxHeight: 38), // Increased from 34 to 38 for bigger text
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 1), // Small spacing for better readability
              Flexible(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize *
                        0.8, // Increased from 0.65 to 0.8 for bigger text
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 1), // Small spacing
              Flexible(
                child: Text(
                  'GHS ${product.price}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize *
                        0.8, // Increased from 0.65 to 0.8 for bigger text
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Limit products for better performance
  List<Product> _getLimitedProducts(List<Product> products, {int limit = 8}) {
    return products.take(limit).toList();
  }

  Widget _buildProductSection(
      String title, Color color, List<Product> products, String category,
      {required double fontSize,
      required double padding,
      required double imageHeight}) {
    // Get screen dimensions for responsive spacing
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive spacing - absolutely minimal
    final responsiveMainAxisSpacing = 0.0; // No spacing at all
    final responsiveCrossAxisSpacing = 0.0; // No spacing at all
    final responsivePadding = 0.0; // No padding at all

    // Ensure minimum and maximum values - absolutely minimal spacing
    final finalMainAxisSpacing = 0.0; // No spacing between rows
    final finalCrossAxisSpacing = 0.0; // No spacing between columns
    final finalPadding = 0.0; // No padding around grid

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with See More button on same row
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 0.0), // No vertical padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: buildSectionHeading(title, color),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryPage(
                        isBulkPurchase: false,
                      ),
                    ),
                  );
                },
                child: Text(
                  'See More',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero, // No padding at all
          itemCount: products.length > 6 ? 6 : products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio:
                1.0, // Square aspect ratio for maximum compactness
            mainAxisSpacing: 0.0, // No spacing between rows
            crossAxisSpacing: 0.0, // No spacing between columns
          ),
          itemBuilder: (context, index) {
            return HomeProductCard(
              product: products[index],
              fontSize:
                  fontSize * 1.1, // Increased from 0.95 to 1.1 for bigger text
              padding: padding * 0.8,
              imageHeight: imageHeight * 0.85,
            );
          },
        ),
        SizedBox(height: 0), // No spacing at all
      ],
    );
  }
}

class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
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

            // Search Bar Skeleton
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Banner Carousel Skeleton
            SliverToBoxAdapter(
              child: Container(
                height: 150,
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Action Cards Skeleton
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                      3,
                      (index) => Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )),
                ),
              ),
            ),
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCardSkeleton(),
                childCount: 4,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 120,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCardSkeleton(),
                childCount: 4,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: 150,
                height: 24,
                color: Colors.white,
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 120,
                margin: EdgeInsets.only(left: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Container(
                      width: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCardSkeleton(),
                childCount: 4,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProductCardSkeleton() {
    return Container(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 16,
            color: Colors.white,
          ),
          SizedBox(height: 4),
          Container(
            width: 80,
            height: 14,
            color: Colors.white,
          ),
          SizedBox(height: 8),
          Container(
            width: 60,
            height: 16,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

Widget buildOrderMedicineCard() => _OrderMedicineCard();

class _OrderMedicineCard extends StatefulWidget {
  @override
  State<_OrderMedicineCard> createState() => _OrderMedicineCardState();
}

class _OrderMedicineCardState extends State<_OrderMedicineCard> {
  List<BannerModel> banners = [];
  bool _isLoadingBanners = false;
  Timer? _timer;
  late final PageController _pageController;
  final BannerCacheService _bannerCacheService = BannerCacheService();

  void showTopSnackBar(BuildContext context, String message,
      {Duration? duration}) {
    final overlay = Overlay.of(context);

    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green[900],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration ?? const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _initializeBannerCache();
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_pageController.hasClients && banners.isNotEmpty) {
        int nextPage = (_pageController.page?.round() ?? 0) + 1;
        if (nextPage >= banners.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _initializeBannerCache() async {
    await _bannerCacheService.initialize();
    await fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBanners) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }
    if (banners.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        child: Text(
          'No banners available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 190, // Increased height to show more of the image length
      child: PageView.builder(
        controller: _pageController,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = banner.img.startsWith('http')
              ? banner.img
              : 'https://eclcommerce.ernestchemists.com.gh/storage/banners/${Uri.encodeComponent(banner.img)}';
          return GestureDetector(
            onTap: () {
              if (banner.urlName != null && banner.urlName!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemPage(urlName: banner.urlName!),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 200),
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image unavailable',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> fetchBanners() async {
    if (!mounted) return;

    setState(() => _isLoadingBanners = true);

    try {
      // Use cached banners if available
      final cachedBanners = await _bannerCacheService.getBanners();

      if (mounted) {
        setState(() {
          banners = cachedBanners;
          _isLoadingBanners = false;
        });

        // Preload banner images in background
        _bannerCacheService.preloadBannerImages(context);

        // Print performance summary periodically
        if (banners.isNotEmpty) {
          print('Banner widget loaded ${banners.length} banners successfully');
          _bannerCacheService.printPerformanceSummary();
        }
      }
    } catch (e) {
      print('Banner widget error: $e');
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
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
  return 'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
}

// Helper to build a modern section heading with enhanced design
Widget buildSectionHeading(String title, Color color) {
  return Row(
    children: [
      // Decorative line with gradient
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              color.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      // Icon beside the title
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _getIconForSection(title),
          color: color,
          size: 14,
        ),
      ),
      const SizedBox(width: 8),
      // Title with enhanced styling
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            Container(
              width: 25,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// Helper to get appropriate icon for each section
IconData _getIconForSection(String title) {
  switch (title.toLowerCase()) {
    case 'drugs':
      return Icons.medication;
    case 'popular products':
      return Icons.trending_up;
    case 'otc/pom':
      return Icons.local_pharmacy;
    case 'wellness':
      return Icons.favorite;
    case 'self care':
      return Icons.self_improvement;
    case 'accessories':
      return Icons.medical_services;
    default:
      return Icons.category;
  }
}

// Helper to build a modern capsule heading with enhanced design
Widget buildCapsuleHeading(String title, Color color) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForSection(title),
              color: color,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
