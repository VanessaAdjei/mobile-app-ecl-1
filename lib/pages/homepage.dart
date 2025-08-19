// pages/homepage.dart
import 'package:eclapp/pages/pharmacists.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:eclapp/pages/storelocation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'product_model.dart';
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
import '../widgets/smart_tips.dart';
import '../services/banner_cache_service.dart';
import '../services/homepage_optimization_service.dart';
import '../widgets/empty_state.dart';
import 'section_products_page.dart';
import 'package:animations/animations.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/promotional_event_provider.dart';
import '../widgets/ernest_friday_banner.dart';
import '../widgets/ernest_friday_notification.dart';
import 'ernest_friday_page.dart';

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

class ProductCache {
  static List<Product> _cachedProducts = [];
  static List<Product> _cachedPopularProducts = [];
  static DateTime? _lastCacheTime;
  static DateTime? _lastShuffleTime;

  static const Duration _cacheValidDuration = Duration(hours: 24);
  static const Duration _shuffleInterval = Duration(hours: 24);
  static const String _popularProductsKey = 'cached_popular_products';
  static const String _lastCacheTimeKey = 'last_cache_time';
  static const String _lastShuffleTimeKey = 'last_shuffle_time';
  static const String _shuffledPopularProductsKey = 'shuffled_popular_products';

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    final timeSinceCache = DateTime.now().difference(_lastCacheTime!);
    final isValid = timeSinceCache < _cacheValidDuration;
    debugPrint(
        '🔄 ProductCache: Cache valid: $isValid, Time since cache: ${timeSinceCache.inMinutes} minutes');
    return isValid;
  }

  // Check if products need to be shuffled (every 24 hours)
  static bool get shouldShuffle {
    if (_lastShuffleTime == null) return true;
    final timeSinceShuffle = DateTime.now().difference(_lastShuffleTime!);
    final shouldShuffle = timeSinceShuffle >= _shuffleInterval;
    debugPrint(
        '🎲 ProductCache: Should shuffle: $shouldShuffle, Time since shuffle: ${timeSinceShuffle.inHours} hours');
    return shouldShuffle;
  }

  // Get popular products with automatic shuffling every 24 hours
  static List<Product> get popularProductsWithShuffle {
    if (shouldShuffle) {
      debugPrint('🎲 ProductCache: Shuffling popular products after 24 hours');
      _shufflePopularProducts();
    }
    return _cachedPopularProducts;
  }

  static void cacheProducts(List<Product> products) {
    _cachedProducts = products;
    _lastCacheTime = DateTime.now();
  }

  static void cachePopularProducts(List<Product> products) {
    _cachedPopularProducts = products;
    _lastCacheTime = DateTime.now();
    _lastShuffleTime = DateTime.now(); // Set shuffle time when caching
    debugPrint(
        '💾 ProductCache: Cached ${products.length} popular products at $_lastCacheTime');
    debugPrint('🎲 ProductCache: Set shuffle time to $_lastShuffleTime');
    _saveToStorage();
  }

  static List<Product> get cachedProducts => _cachedProducts;
  static List<Product> get cachedPopularProducts => _cachedPopularProducts;

  static void clearCache() {
    _cachedProducts.clear();
    _cachedPopularProducts.clear();
    _lastCacheTime = null;
    _lastShuffleTime = null; // Clear shuffle timestamp
    _clearFromStorage();
  }

  // Load cache from persistent storage
  static Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTimeString = prefs.getString(_lastCacheTimeKey);
      final lastShuffleTimeString = prefs.getString(_lastShuffleTimeKey);

      if (lastCacheTimeString != null) {
        _lastCacheTime = DateTime.parse(lastCacheTimeString);
        debugPrint('📱 ProductCache: Loaded cache timestamp: $_lastCacheTime');

        // Check if cache is still valid
        if (isCacheValid) {
          final productsJson = prefs.getString(_popularProductsKey);
          if (productsJson != null) {
            final List<dynamic> productsList = json.decode(productsJson);
            _cachedPopularProducts =
                productsList.map((json) => Product.fromJson(json)).toList();
            debugPrint(
                '📱 ProductCache: Loaded ${_cachedPopularProducts.length} popular products from storage');

            // Load shuffle timestamp
            if (lastShuffleTimeString != null) {
              _lastShuffleTime = DateTime.parse(lastShuffleTimeString);
              debugPrint(
                  '🎲 ProductCache: Loaded shuffle timestamp: $_lastShuffleTime');
            }

            debugPrint('🔍 STORAGE PRODUCTS:');
            for (int i = 0; i < _cachedPopularProducts.length; i++) {
              final product = _cachedPopularProducts[i];
              debugPrint('  ${i + 1}. ${product.name} (ID: ${product.id})');
            }
            debugPrint('🔍 END STORAGE PRODUCTS');
          }
        } else {
          debugPrint('📱 ProductCache: Cache expired, clearing storage');
          _clearFromStorage();
        }
      }
    } catch (e) {
      debugPrint('❌ ProductCache: Error loading from storage: $e');
      _clearFromStorage();
    }
  }

  // Save cache to persistent storage
  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson =
          json.encode(_cachedPopularProducts.map((p) => p.toJson()).toList());
      await prefs.setString(_popularProductsKey, productsJson);
      await prefs.setString(
          _lastCacheTimeKey, _lastCacheTime!.toIso8601String());

      // Save shuffle timestamp
      if (_lastShuffleTime != null) {
        await prefs.setString(
            _lastShuffleTimeKey, _lastShuffleTime!.toIso8601String());
      }

      debugPrint('💾 ProductCache: Saved to persistent storage');
    } catch (e) {
      debugPrint('❌ ProductCache: Error saving to storage: $e');
    }
  }

  // Clear cache from persistent storage
  static Future<void> _clearFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_popularProductsKey);
      await prefs.remove(_lastCacheTimeKey);
      await prefs.remove(_lastShuffleTimeKey); // Clear shuffle timestamp
      debugPrint('🗑️ ProductCache: Cleared from persistent storage');
    } catch (e) {
      debugPrint('❌ ProductCache: Error clearing from storage: $e');
    }
  }

  // Shuffle popular products and update shuffle timestamp
  static void _shufflePopularProducts() {
    if (_cachedPopularProducts.isNotEmpty) {
      final shuffled = List<Product>.from(_cachedPopularProducts);
      shuffled.shuffle();
      _cachedPopularProducts = shuffled;
      _lastShuffleTime = DateTime.now();
      debugPrint(
          '🎲 ProductCache: Shuffled ${_cachedPopularProducts.length} popular products');
      _saveToStorage();
    }
  }
}

class SafeTypeAheadField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final Future<List<Product>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, Product) itemBuilder;
  final Function(Product) onSuggestionSelected;
  final Widget Function(BuildContext)? noItemsFoundBuilder;
  final bool hideOnEmpty;
  final bool hideOnLoading;
  final Duration debounceDuration;
  final SuggestionsBoxDecoration suggestionsBoxDecoration;
  final double suggestionsBoxVerticalOffset;
  final SuggestionsBoxController? suggestionsBoxController;

  const SafeTypeAheadField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSuggestionSelected,
    this.noItemsFoundBuilder,
    this.hideOnEmpty = true,
    this.hideOnLoading = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    required this.suggestionsBoxDecoration,
    this.suggestionsBoxVerticalOffset = 0,
    this.suggestionsBoxController,
  });

  @override
  State<SafeTypeAheadField> createState() => _SafeTypeAheadFieldState();
}

class _SafeTypeAheadFieldState extends State<SafeTypeAheadField> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    try {
      return TypeAheadField<Product>(
        textFieldConfiguration: TextFieldConfiguration(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: 'Search medicines, products...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      if (mounted && !_isDisposed) {
                        widget.controller.clear();
                        setState(() {});
                      }
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
            if (mounted && !_isDisposed) {
              widget.onSubmitted(value);
            }
          },
        ),
        suggestionsCallback: (pattern) async {
          if (pattern.isEmpty || !mounted || _isDisposed) {
            return [];
          }
          try {
            return await widget.suggestionsCallback(pattern);
          } catch (e) {
            debugPrint('SafeTypeAheadField suggestions error: $e');
            return [];
          }
        },
        itemBuilder: (context, suggestion) {
          if (!mounted || _isDisposed) {
            return const SizedBox.shrink();
          }
          return widget.itemBuilder(context, suggestion);
        },
        onSuggestionSelected: (suggestion) {
          if (mounted && !_isDisposed) {
            widget.onSuggestionSelected(suggestion);
          }
        },
        noItemsFoundBuilder: widget.noItemsFoundBuilder,
        hideOnEmpty: widget.hideOnEmpty,
        hideOnLoading: widget.hideOnLoading,
        debounceDuration: widget.debounceDuration,
        suggestionsBoxDecoration: widget.suggestionsBoxDecoration,
        suggestionsBoxVerticalOffset: widget.suggestionsBoxVerticalOffset,
        suggestionsBoxController: widget.suggestionsBoxController,
      );
    } catch (e) {
      debugPrint('SafeTypeAheadField build error: $e');
      return const SizedBox.shrink();
    }
  }
}

class ErrorDisplayWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({
    super.key,
    this.onRetry,
  });

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
  double get maxExtent => 96.0;

  @override
  double get minExtent => 96.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isLoadingPopular = true;

  String? _error;
  String? _popularError;

  List<Product> _products = [];
  List<Product> filteredProducts = [];
  List<Product> popularProducts = [];

  final RefreshController _refreshController = RefreshController();

  TextEditingController searchController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  List<Product> otcpomProducts = [];
  List<Product> drugProducts = [];
  List<Product> wellnessProducts = [];
  List<Product> selfcareProducts = [];
  List<Product> accessoriesProducts = [];
  List<Product> drugsSectionProducts = [];

  final Map<String, bool> _preloadedImages = {};

  final HomepageOptimizationService _optimizationService =
      HomepageOptimizationService();

  final ScrollController _popularScrollController = ScrollController();
  Timer? _popularScrollTimer;
  int _highlightedPopularIndex = 0;

  // Add these fields to the _HomePageState class:
  int _popularBaseIndex = 0;
  int _popularCurrentIndex = 0;
  final int _popularRepeatCount = 1000;

  // Track when product sections were last shuffled
  DateTime? _lastSectionShuffleTime;
  static const Duration _sectionShuffleInterval = Duration(hours: 24);

  // Track if the page has already been loaded to prevent unnecessary reloads
  bool _hasBeenLoaded = false;

  @override
  bool get wantKeepAlive => true;

  _launchPhoneDialer(String phoneNumber) async {
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus.isGranted) {
      final String formattedPhoneNumber = 'tel:$phoneNumber';
      if (await canLaunchUrl(Uri.parse(formattedPhoneNumber))) {
        await launchUrl(Uri.parse(formattedPhoneNumber));
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

    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      showTopSnackBar(
          context, 'Could not open WhatsApp. Please ensure it is installed.');
    }
  }

  bool _isLoadingContent = false;

  Future<void> _loadAllContent() async {
    debugPrint('HomePage: _loadAllContent called');
    if (!mounted || _isLoadingContent) return;

    // Check if content has already been loaded to prevent unnecessary reloads
    if (_hasBeenLoaded) {
      debugPrint('HomePage: Content already loaded, skipping reload');
      return;
    }

    _isLoadingContent = true;

    try {
      // Check if we already have cached popular products
      if (ProductCache.isCacheValid &&
          ProductCache.cachedPopularProducts.isNotEmpty) {
        debugPrint(
            'HomePage: Using cached popular products, skipping API call');
        debugPrint('🔍 USING CACHED PRODUCTS:');
        for (int i = 0; i < ProductCache.cachedPopularProducts.length; i++) {
          final product = ProductCache.cachedPopularProducts[i];
          debugPrint('  ${i + 1}. ${product.name} (ID: ${product.id})');
        }
        debugPrint('🔍 END CACHED PRODUCTS');
        setState(() {
          popularProducts = ProductCache.cachedPopularProducts;
        });

        // Start auto-scroll for cached popular products
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && popularProducts.isNotEmpty) {
            _startPopularProductsAutoScroll();
          }
        });
      } else {
        // Load popular products only if cache is expired
        debugPrint(
            'HomePage: Loading popular products (cache expired or empty)');
        await _fetchPopularProducts();
      }

      // Load products first
      debugPrint('HomePage: Loading products');
      await loadProducts();

      // Load health tips
      debugPrint('HomePage: Loading health tips');
      await _fetchHealthTips();

      // Mark as loaded to prevent future reloads
      _hasBeenLoaded = true;
      debugPrint('HomePage: Content loaded successfully, marked as loaded');
    } catch (e) {
      debugPrint('HomePage: Exception in _loadAllContent: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load content';
        });
      }
    } finally {
      _isLoadingContent = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('HomePage: _loadAllContent completed');
        // Preload all product images for best UX
        HomepageOptimizationService().preloadAllProductImages(context);
      }
      if (_refreshController.isRefresh) {
        _refreshController.refreshCompleted();
      }
    }
  }

  Future<void> loadProducts() async {
    if (!mounted) return;

    // Always show skeleton for at least 800ms for better UX
    final skeletonStartTime = DateTime.now();

    // Check if we have valid cached data
    if (ProductCache.isCacheValid && ProductCache.cachedProducts.isNotEmpty) {
      // Use cached data but still show skeleton briefly
      final cachedProducts = ProductCache.cachedProducts;
      _processProducts(cachedProducts);

      // Preload images in background
      _preloadImages(cachedProducts);

      // Ensure skeleton shows for at least 800ms
      final elapsed = DateTime.now().difference(skeletonStartTime);
      if (elapsed.inMilliseconds < 800) {
        await Future.delayed(
            Duration(milliseconds: 800 - elapsed.inMilliseconds));
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        if (dataList.isNotEmpty) {
          final firstItem = dataList[0];
          final productData = firstItem['product'] ?? {};
          debugPrint('🔍 HOMEPAGE API RESPONSE STRUCTURE ===');
          debugPrint('First Product Data Keys: ${productData.keys.toList()}');
          debugPrint('First Product OTCPOM: ${productData['otcpom']}');
          debugPrint('==========================================');
        }

        final allProducts = dataList.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;

          if (dataList.indexOf(item) < 3) {
            debugPrint('🔍 HOMEPAGE PRODUCT DATA ===');
            debugPrint('Product: ${productData['name']}');
            debugPrint('Qty in stock (root): ${item['qty_in_stock']}');
            debugPrint(
                'Qty in stock (product): ${productData['qty_in_stock']}');
            debugPrint(
                'Quantity field: ${item['qty_in_stock']?.toString() ?? ''}');
            debugPrint('========================');
          }

          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: item['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? productData['image'] ?? '',
            quantity: item['qty_in_stock']?.toString() ??
                '', // Fixed: Get from root item, not product
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
    }
  }

  bool _shouldShuffleSections() {
    if (_lastSectionShuffleTime == null) {
      debugPrint(
          '🎲 HomePage: No section shuffle timestamp found, should shuffle: true');
      return true;
    }

    final timeSinceShuffle =
        DateTime.now().difference(_lastSectionShuffleTime!);
    final shouldShuffle = timeSinceShuffle >= _sectionShuffleInterval;

    debugPrint('🎲 HomePage: Section shuffle check:');
    debugPrint('  - Last shuffle time: $_lastSectionShuffleTime');
    debugPrint('  - Current time: ${DateTime.now()}');
    debugPrint(
        '  - Time since shuffle: ${timeSinceShuffle.inHours} hours ${timeSinceShuffle.inMinutes % 60} minutes');
    debugPrint(
        '  - Shuffle interval: ${_sectionShuffleInterval.inHours} hours');
    debugPrint('  - Should shuffle: $shouldShuffle');

    return shouldShuffle;
  }

  Future<void> _saveSectionShuffleTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSectionShuffleTime != null) {
        await prefs.setString(
            'section_shuffle_time', _lastSectionShuffleTime!.toIso8601String());
        debugPrint(
            'HomePage: Saved section shuffle timestamp: $_lastSectionShuffleTime');
      }
    } catch (e) {
      debugPrint('HomePage: Error saving section shuffle timestamp: $e');
    }
  }

  Future<void> _loadSectionShuffleTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shuffleTimeString = prefs.getString('section_shuffle_time');
      if (shuffleTimeString != null) {
        _lastSectionShuffleTime = DateTime.parse(shuffleTimeString);
        debugPrint(
            'HomePage: Loaded section shuffle timestamp: $_lastSectionShuffleTime');
      } else {
        debugPrint(
            'HomePage: No section shuffle timestamp found, will shuffle on first load');
      }
    } catch (e) {
      debugPrint('    HomePage: Error loading section shuffle timestamp: $e');
    }
  }

  // Synchronous version for initState
  void _loadSectionShuffleTimeSync() {
    SharedPreferences.getInstance().then((prefs) {
      final shuffleTimeString = prefs.getString('section_shuffle_time');
      if (shuffleTimeString != null) {
        _lastSectionShuffleTime = DateTime.parse(shuffleTimeString);
        debugPrint(
            '📱 HomePage: Loaded section shuffle timestamp: $_lastSectionShuffleTime');
      } else {
        debugPrint(
            '📱 HomePage: No section shuffle timestamp found, will shuffle on first load');
      }
    }).catchError((e) {
      debugPrint('❌ HomePage: Error loading section shuffle timestamp: $e');
    });
  }

  // Method to manually reset shuffle timestamp (for testing)
  Future<void> _resetSectionShuffleTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('section_shuffle_time');
      _lastSectionShuffleTime = null;
      debugPrint('🔄 HomePage: Section shuffle timestamp reset manually');
    } catch (e) {
      debugPrint('❌ HomePage: Error resetting section shuffle timestamp: $e');
    }
  }

  // Method to reset loaded flag for refresh functionality
  void _resetLoadedFlag() {
    _hasBeenLoaded = false;
    debugPrint('🔄 HomePage: Loaded flag reset for refresh');
  }

  // Wrapper method for refresh that resets the loaded flag
  Future<void> _handleRefresh() async {
    debugPrint('🔄 HomePage: Refresh requested, resetting loaded flag');
    _resetLoadedFlag();
    await _loadAllContent();
  }

  // Public method to manually reload home page content
  Future<void> reloadHomePage() async {
    debugPrint('🔄 HomePage: Manual reload requested');
    _resetLoadedFlag();
    await _loadAllContent();
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

    // Ensure we have the shuffle timestamp before deciding whether to shuffle
    if (_lastSectionShuffleTime == null) {
      debugPrint(
          '🎲 HomePage: Section shuffle timestamp not loaded yet, skipping shuffle check');
      // Set default order without shuffling
      if (mounted) {
        setState(() {
          drugsSectionProducts = otcDrugProducts;
          wellnessProducts = wellnessList;
          selfcareProducts = selfcareList;
          accessoriesProducts = accessoriesList;
        });
      }
      return;
    }

    final shouldShuffleSections = _shouldShuffleSections();

    if (shouldShuffleSections) {
      debugPrint('🎲 HomePage: Shuffling product sections after 24 hours');
      // Shuffle section products
      otcDrugProducts.shuffle();
      wellnessList.shuffle();
      selfcareList.shuffle();
      accessoriesList.shuffle();
      // Update shuffle timestamp and save to storage
      _lastSectionShuffleTime = DateTime.now();
      _saveSectionShuffleTime();
    } else {
      debugPrint(
          '🎲 HomePage: Using existing section product order (within 24 hours)');
    }

    // Debug: Log product counts to confirm consistency
    debugPrint('🔍 PRODUCT SECTIONS - Consistent Order:');
    debugPrint('  Drugs: ${otcDrugProducts.length} products');
    debugPrint('  Wellness: ${wellnessList.length} products');
    debugPrint('  Selfcare: ${selfcareList.length} products');
    debugPrint('  Accessories: ${accessoriesList.length} products');

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

  Future<void> _fetchHealthTips() async {
    debugPrint('Health tips fetching disabled.');
    return;
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
                subtitle: '0302908674',
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
                subtitle: 'info@ernestchemists.com',
                color: Colors.blue.shade600,
                onTap: () {
                  Navigator.pop(context);
                  _launchEmail(
                      'info@ernestchemists.com', 'ECL Support Request');
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
              color: Colors.black.withValues(alpha: 0.05),
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
                color: color.withValues(alpha: 0.1),
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
                            margin: const EdgeInsets.only(
                                top: 16.0, left: 16.0, right: 16.0),
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

  void _clearSearch() {
    if (_searchController.text.isNotEmpty && mounted) {
      _searchController.clear();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 HomePage: initState called');

    WidgetsBinding.instance.addObserver(this);

    ProductCache.loadFromStorage();

    // Initialize optimization service
    _initializeOptimizationService();

    // Load cached data immediately if available
    if (_optimizationService.hasCachedProducts) {
      setState(() {
        _products = _optimizationService.cachedProducts;
        filteredProducts = _optimizationService.cachedProducts;
        // Keep loading state true for skeleton to show
        _isLoading = true;
        _error = null;
      });
    }

    // Load section shuffle timestamp from storage synchronously
    _loadSectionShuffleTimeSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAllContent();
      }
    });

    _scrollController.addListener(() {
      if (mounted) {
        if (_scrollController.offset > 100 && !_isScrolled) {
          setState(() {
            _isScrolled = true;
          });
        } else if (_scrollController.offset <= 100 && _isScrolled) {
          setState(() {
            _isScrolled = false;
          });
        }
      }
    });

    // Add scroll listener for popular products
    _popularScrollController.addListener(() {
      if (mounted) {
        final scrollPosition = _popularScrollController.offset;
        final maxScrollExtent =
            _popularScrollController.position.maxScrollExtent;
        if (maxScrollExtent > 0) {
          final scrollPercentage = scrollPosition / maxScrollExtent;
          setState(() {});
        }
      }
    });

    // Auto-scroll will be initialized when popular products are loaded
  }

  Future<void> _initializeOptimizationService() async {
    await _optimizationService.initialize();

    if (_optimizationService.hasCachedProducts) {
      setState(() {
        _products = _optimizationService.cachedProducts;
        filteredProducts = _optimizationService.cachedProducts;
        // Keep loading state true for skeleton to show
        _isLoading = true;
        _error = null;
      });
    }
  }

  void _startPopularProductsAutoScroll() {
    if (popularProducts.isEmpty || !mounted) return;

    // Cancel any existing timer
    _popularScrollTimer?.cancel();

    debugPrint(
        '🎡 Starting automatic scroll for ${popularProducts.length} popular products');

    _popularScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || popularProducts.isEmpty) {
        timer.cancel();
        return;
      }

      try {
        if (_popularScrollController.hasClients) {
          final currentOffset = _popularScrollController.offset;
          final maxScrollExtent =
              _popularScrollController.position.maxScrollExtent;

          // Calculate next scroll position (scroll by 1 item)
          const scrollDistance = 96.0; // Width of 1 product (80 + 16 padding)
          double nextOffset = currentOffset + scrollDistance;

          // For true infinite scroll, when we reach 75% of the way, jump to beginning
          // This creates seamless infinite scrolling effect
          if (nextOffset >= maxScrollExtent * 0.75) {
            // Jump to equivalent position at the beginning (same product pattern)
            final baseProducts = popularProducts.take(6).length;
            final jumpToOffset = (currentOffset % (baseProducts * 96.0));

            _popularScrollController.jumpTo(jumpToOffset);

            // Then continue scrolling from new position
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _popularScrollController.hasClients) {
                _popularScrollController.animateTo(
                  jumpToOffset + scrollDistance,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
          } else {
            _popularScrollController.animateTo(
              nextOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      } catch (e) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();

    _popularScrollTimer?.cancel();
    _popularScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted && _products.isNotEmpty && _preloadedImages.isEmpty) {
      _preloadImages(_products);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Clear search when app becomes active
    if (state == AppLifecycleState.resumed && mounted) {
      _clearSearch();
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
                  color: Colors.black.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 8.0),
      child: SizedBox(
        height: 48,
        child: Builder(
          builder: (context) {
            if (!mounted) {
              return const SizedBox.shrink();
            }

            try {
              return SafeTypeAheadField(
                controller: _searchController,
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
                    ).then((_) => _clearSearch());
                  }
                },
                suggestionsCallback: (pattern) async {
                  if (pattern.isEmpty || !mounted) {
                    return [];
                  }
                  try {
                    final response = await http
                        .get(
                          Uri.parse(
                              'https://eclcommerce.ernestchemists.com.gh/api/search/$pattern'),
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
                          price: (item['price'] ?? item['selling_price'] ?? 0)
                              .toString(),
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
                  if (!mounted) {
                    return const SizedBox.shrink();
                  }
                  if (suggestion.name == '__VIEW_MORE__') {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.list, color: Colors.green[700]),
                        title: Text(
                          'View All Results',
                          style: GoogleFonts.poppins(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  final matchingProduct = _products.firstWhere(
                    (p) => p.id == suggestion.id || p.name == suggestion.name,
                    orElse: () => suggestion,
                  );
                  final imageUrl = getProductImageUrl(
                      matchingProduct.thumbnail.isNotEmpty
                          ? matchingProduct.thumbnail
                          : suggestion.thumbnail);
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.06)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        final matchingProduct = _products.firstWhere(
                          (p) =>
                              p.id == suggestion.id ||
                              p.name == suggestion.name,
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
                          ).then((_) => _clearSearch());
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ItemPage(
                                urlName: urlName,
                                isPrescribed:
                                    matchingProduct.otcpom?.toLowerCase() ==
                                        'pom',
                              ),
                            ),
                          ).then((_) => _clearSearch());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                memCacheHeight: 200,
                                maxWidthDiskCache: 200,
                                maxHeightDiskCache: 200,
                                fadeInDuration: Duration(milliseconds: 100),
                                fadeOutDuration: Duration(milliseconds: 100),
                                placeholder: (context, url) => Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: Colors.grey[400]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (suggestion.price.isNotEmpty &&
                                      suggestion.price != '0')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'GH₵ ${suggestion.price}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
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
                    ).then((_) => _clearSearch());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemPage(
                          urlName: urlName,
                          isPrescribed:
                              matchingProduct.otcpom?.toLowerCase() == 'pom',
                        ),
                      ),
                    ).then((_) => _clearSearch());
                  }
                },
                noItemsFoundBuilder: (context) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('No products found',
                      style: TextStyle(color: Colors.grey)),
                ),
                hideOnEmpty: true,
                hideOnLoading: false,
                debounceDuration: Duration(milliseconds: 10),
                suggestionsBoxDecoration: SuggestionsBoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 10,
                ),
                suggestionsBoxVerticalOffset: 0,
                suggestionsBoxController: null,
              );
            } catch (e) {
              debugPrint('SafeTypeAheadField error: $e');
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      children: [
        // Action Cards Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.people,
                  title: "Meet Our Pharmacists",
                  color: Colors.blue[600]!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PharmacistsPage()),
                    );
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.location_on,
                  title: "Locate A Store Near You",
                  color: Colors.green[600]!,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => StoreSelectionPage()),
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
        ),
      ],
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
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
                color: Colors.black.withValues(alpha: 0.1),
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
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          _isLoading ? _buildSkeletonWithLoading() : _buildMainContent(),
          const SmartTips(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 0),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const HomePageSkeletonBody(),
        // Add a loading indicator overlay
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading your products...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return SizedBox.shrink(); // Already handled in build()
    }
    if (_error != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          if (mounted) {
            setState(() {
              _error = null;
            });
            _loadAllContent();
          }
        },
      );
    }

    return Material(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
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
                onRefresh: _handleRefresh,
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
                            padding: const EdgeInsets.only(left: 1),
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
                        builder: (shrinkOffset) {
                          return _buildSearchBar();
                        },
                      ),
                    ),
                    // Ernest Friday Top Notification - COMMENTED OUT
                    // SliverToBoxAdapter(
                    //   child: ErnestFridayTopNotification(),
                    // ),
                    // Ernest Friday Banner - COMMENTED OUT
                    // SliverToBoxAdapter(
                    //   child: Consumer<PromotionalEventProvider>(
                    //     builder: (context, promotionalProvider, child) {
                    //       if (promotionalProvider.isErnestFridayActive) {
                    //             return ErnestFridayBanner(
                    //               event: promotionalProvider.activeEvent!,
                    //               onTap: () {
                    //                 Navigator.push(
                    //                   context,
                    //                   MaterialPageRoute(
                    //                     builder: (context) =>
                    //                         const ErnestFridayPage(),
                    //                   ),
                    //                 );
                    //               },
                    //             );
                    //           }
                    //           return const SizedBox.shrink();
                    //         },
                    //       ),
                    //     ),
                    //   ),
                    SliverToBoxAdapter(
                      child: buildOrderMedicineCard(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildActionCards(),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
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
                    // Popular Products Section Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    Colors.blueAccent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.blueAccent
                                        .withValues(alpha: 0.18),
                                    width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up,
                                      color: Colors.blueAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Popular Products',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
      ),
    );
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
      return EmptyStateWidget(
        message: 'No popular products available',
        icon: Icons.star_border,
      );
    }

    // Create infinite scroll by duplicating products multiple times for seamless loop
    final baseProducts = popularProducts.take(6).toList();
    final infiniteProducts = <Product>[];

    // Duplicate products multiple times for smooth infinite scroll
    for (int i = 0; i < 10; i++) {
      infiniteProducts.addAll(baseProducts);
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Popular Products Row - Infinite Scroll
          Expanded(
            child: ListView.builder(
              controller: _popularScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: infiniteProducts.length,
              padding: const EdgeInsets.only(right: 16),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final product = infiniteProducts[index];
                final baseIndex = index % baseProducts.length;

                // Calculate which product is currently in the center viewport
                final currentScrollOffset = _popularScrollController.hasClients
                    ? _popularScrollController.offset
                    : 0.0;
                final itemPosition = index * 96.0; // 80 width + 16 padding
                final isInCenter = (itemPosition - currentScrollOffset).abs() <
                    48.0; // Center 96px area

                return AnimatedScale(
                  scale: isInCenter ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(top: isInCenter ? 8.0 : 0.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 80,
                        child: HomeProductCard(
                          product: product,
                          fontSize: 15,
                          padding: 0,
                          imageHeight: 100,
                          showPrice: false,
                          showName: false,
                          showHero: false, // Disable Hero in the grid
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                  final sectionKey = title.toLowerCase();
                  final filtered = _products.where((p) {
                    switch (sectionKey) {
                      case 'wellness':
                        return p.wellness?.toLowerCase() == 'wellness';
                      case 'selfcare':
                        return p.selfcare?.toLowerCase() == 'selfcare';
                      case 'accessories':
                        return p.accessories?.toLowerCase() == 'accessories';
                      case 'drugs':
                      case 'drug':
                        return p.drug?.toLowerCase() == 'drug';
                      case 'otc':
                        return p.otcpom?.toLowerCase() == 'otc';
                      default:
                        // fallback: match category or other fields if needed
                        return p.category.toLowerCase() == sectionKey;
                    }
                  }).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SectionProductsPage(
                        sectionTitle: title,
                        products: filtered,
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
            crossAxisSpacing: 0.0, // Small spacing between columns
          ),
          itemBuilder: (context, index) {
            return AnimatedVisibilityProductCard(
              key: ValueKey(products[index].id),
              product: products[index],
              fontSize: fontSize * 1.1,
              padding: padding * 0.8,
              imageHeight: imageHeight * 0.85,
            );
          },
        ),
        SizedBox(height: 0), // No spacing at all
        if (products.isEmpty)
          EmptyStateWidget(
            message: 'No products found in this section.',
            icon: Icons.shopping_bag_outlined,
          ),
      ],
    );
  }

  Future<void> _fetchPopularProducts() async {
    debugPrint('🔄 HomePage: _fetchPopularProducts called');
    if (!mounted) return;

    // Check if we have valid cached popular products
    if (ProductCache.isCacheValid &&
        ProductCache.cachedPopularProducts.isNotEmpty) {
      debugPrint(
          '✅ HomePage: Using cached popular products (${ProductCache.cachedPopularProducts.length} products)');
      setState(() {
        // Use the shuffle system - products will be shuffled every 24 hours
        popularProducts = ProductCache.popularProductsWithShuffle;
        _isLoadingPopular = false;
      });
      return;
    }

    debugPrint('🔄 HomePage: Cache invalid or empty, fetching from API...');
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

        debugPrint('🔍 RAW API RESPONSE - Popular Products:');
        debugPrint('  Total products returned: ${productsData.length}');
        for (int i = 0; i < productsData.length; i++) {
          final item = productsData[i];
          final productData = item['product'] as Map<String, dynamic>;
          debugPrint(
              '  ${i + 1}. ${productData['name']} (ID: ${productData['id']})');
        }
        debugPrint('🔍 END RAW API RESPONSE');

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

        debugPrint('🔍 CACHED PRODUCTS DETAILS:');
        for (int i = 0; i < popularProductsList.length; i++) {
          final product = popularProductsList[i];
          debugPrint('  ${i + 1}. ${product.name} (ID: ${product.id})');
        }
        debugPrint('🔍 END CACHED PRODUCTS DETAILS');

        if (!mounted) return;
        setState(() {
          popularProducts = popularProductsList;
          _isLoadingPopular = false;
        });

        // Start auto-scroll after popular products are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && popularProducts.isNotEmpty) {
            _startPopularProductsAutoScroll();
          }
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
}

class HomePageSkeletonBody extends StatelessWidget {
  const HomePageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
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
                  ),
                ),
              ),
            ),
          ),
          // Product grid skeleton
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
          // Large rectangle skeleton (e.g. for offers)
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
          // Another product grid skeleton
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
          // Small bar skeleton
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: 150,
                height: 24,
                color: Colors.white,
              ),
            ),
          ),
          // Horizontal list skeleton
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
          // Final product grid skeleton
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
    );
  }

  Widget _buildProductCardSkeleton() {
    return Container(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Image placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[200],
                  ),
                ),
                // Prescription badge placeholder (bottom left)
                Positioned(
                  bottom: 8,
                  left: 2,
                  child: Container(
                    width: 48,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name line
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 4),
                // Price line
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 15),
              ],
            ),
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                      color: Colors.black.withValues(alpha: 0.1),
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
          debugPrint(
              'Banner widget loaded ${banners.length} banners successfully');
          _bannerCacheService.printPerformanceSummary();
        }
      }
    } catch (e) {
      debugPrint('Banner widget error: $e');
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
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              color.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      // Icon beside the title
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _getIconForSection(title),
          color: color,
          size: 16,
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            Container(
              width: 30,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
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
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
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

// YesStyle-style scroll-in animation for product cards
class AnimatedVisibilityProductCard extends StatefulWidget {
  final Product product;
  final double? fontSize;
  final double? padding;
  final double? imageHeight;

  const AnimatedVisibilityProductCard({
    super.key,
    required this.product,
    this.fontSize,
    this.padding,
    this.imageHeight,
  });

  @override
  State<AnimatedVisibilityProductCard> createState() =>
      _AnimatedVisibilityProductCardState();
}

class _AnimatedVisibilityProductCardState
    extends State<AnimatedVisibilityProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction > 0.1 && !_visible) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    } else if (info.visibleFraction == 0 && _visible) {
      setState(() => _visible = false);
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? UniqueKey(),
      onVisibilityChanged: _onVisibilityChanged,
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openColor: Theme.of(context).scaffoldBackgroundColor,
        closedColor: Colors.transparent,
        closedElevation: 0,
        openElevation: 0,
        transitionDuration: Duration(milliseconds: 200),
        closedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        openBuilder: (context, _) => ItemPage(
          urlName: widget.product.urlName,
          isPrescribed: widget.product.otcpom?.toLowerCase() == 'pom',
        ),
        closedBuilder: (context, openContainer) => HomeProductCard(
          product: widget.product,
          fontSize: widget.fontSize,
          padding: widget.padding,
          imageHeight: widget.imageHeight,
          onTap: openContainer,
          showHero: false, // Disable Hero in closedBuilder
        ),
      ),
    );
  }
}
