// pages/categories.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eclapp/widgets/error_display.dart';
import 'package:eclapp/pages/itemdetail.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/product_model.dart';
import 'package:eclapp/pages/app_back_button.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/pages/bulk_purchase_page.dart';
import 'package:eclapp/pages/bottomnav.dart';
import '../services/category_optimization_service.dart';
import 'package:flutter/foundation.dart';
import 'package:animations/animations.dart';

// Cache for categories and products
class CategoryCache {
  static List<dynamic> _cachedCategories = [];
  static List<dynamic> _cachedAllProducts = [];
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 60);

  static bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  static void cacheCategories(List<dynamic> categories) {
    _cachedCategories = categories;
    _lastCacheTime = DateTime.now();
  }

  static void cacheAllProducts(List<dynamic> products) {
    _cachedAllProducts = products;
  }

  static List<dynamic> get cachedCategories => _cachedCategories;
  static List<dynamic> get cachedAllProducts {
    debugPrint(
        '🔍 CategoryCache.cachedAllProducts accessed: ${_cachedAllProducts.length} products');
    return _cachedAllProducts;
  }

  static void clearCache() {
    _cachedCategories.clear();
    _cachedAllProducts.clear();
    _lastCacheTime = null;
  }
}

// Image preloading service for categories
class CategoryImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  static void preloadImage(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty || _preloadedImages.containsKey(imageUrl)) return;

    _preloadedImages[imageUrl] = true;
    precacheImage(
      CachedNetworkImageProvider(
        imageUrl,
        maxWidth: 300,
        maxHeight: 300,
      ),
      context,
    );
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

class CategoryPage extends StatefulWidget {
  final bool isBulkPurchase;

  const CategoryPage({super.key, this.isBulkPurchase = false});

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Map<int, List<dynamic>> _subcategoriesMap = {};
  final Map<int, bool> _categoryHasSubcategories = {};
  Timer? _highlightTimer;
  List<dynamic> _allProducts = [];
  final bool _isLoadingProducts = false;
  bool _showSearchDropdown = false;
  List<dynamic> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  final CategoryOptimizationService _categoryService =
      CategoryOptimizationService();

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 CategoryPage initState() called');
    _initializeCategoryService();
    debugPrint('🔍 Calling _prefetchAllProducts()...');
    _prefetchAllProducts(); // Prefetch all products on page load
    _loadCategoriesOptimized();

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          _showSearchDropdown = false;
        });
      }
    });

    // Print performance summary after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _categoryService.printPerformanceSummary();
    });
  }

  Future<void> _initializeCategoryService() async {
    await _categoryService.initialize();

    // Load cached data immediately if available
    if (_categoryService.hasCachedCategories &&
        _categoryService.isCategoriesCacheValid) {
      debugPrint(
          'Using cached categories from initialization: ${_categoryService.cachedCategories.length} categories');
      setState(() {
        _categories = _categoryService.cachedCategories;
        _filteredCategories = _categoryService.cachedCategories;
        // Keep loading state true for skeleton to show
        _isLoading = true;
        _errorMessage = '';
      });

      // Preload images in background
      _categoryService.preloadCategoryImages(
          context, _categoryService.cachedCategories);
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Optimized loading that checks cache first
  Future<void> _loadCategoriesOptimized() async {
    // Always show skeleton for at least 800ms for better UX
    final skeletonStartTime = DateTime.now();

    // Skip loading if we already have valid cached data from initialization
    if (_categoryService.hasCachedCategories &&
        _categoryService.isCategoriesCacheValid &&
        _categories.isNotEmpty) {
      debugPrint('Skipping category loading - using existing cached data');

      // Ensure skeleton shows for at least 800ms
      final elapsed = DateTime.now().difference(skeletonStartTime);
      if (elapsed.inMilliseconds < 800) {
        await Future.delayed(
            Duration(milliseconds: 800 - elapsed.inMilliseconds));
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      debugPrint('Loading categories from service...');
      final categories = await _categoryService.getCategories();
      _processCategories(categories);

      // Ensure skeleton shows for at least 800ms
      final elapsed = DateTime.now().difference(skeletonStartTime);
      if (elapsed.inMilliseconds < 800) {
        await Future.delayed(
            Duration(milliseconds: 800 - elapsed.inMilliseconds));
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
      }

      // Preload images in background
      _categoryService.preloadCategoryImages(context, categories);
    } catch (e) {
      debugPrint('Category loading error: $e');

      // Ensure skeleton shows for at least 800ms even on error
      final elapsed = DateTime.now().difference(skeletonStartTime);
      if (elapsed.inMilliseconds < 800) {
        await Future.delayed(
            Duration(milliseconds: 800 - elapsed.inMilliseconds));
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load categories. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // Process categories and update state
  void _processCategories(List<dynamic> categories) {
    if (!mounted) return;

    debugPrint('Processing ${categories.length} categories');
    debugPrint('Categories data: ${categories.take(3).map((c) => {
          'id': c['id'],
          'name': c['name'],
          'has_subcategories': c['has_subcategories']
        }).toList()}');

    // Update the subcategory mapping based on actual API responses
    _updateSubcategoryMapping(categories);

    setState(() {
      _categories = categories;
      _filteredCategories = categories;
    });

    debugPrint('Categories state updated: ${_categories.length} categories');
    debugPrint('Filtered categories: ${_filteredCategories.length} categories');
  }

  // Update subcategory mapping based on actual API responses
  void _updateSubcategoryMapping(List<dynamic> categories) {
    for (final category in categories) {
      final categoryId = category['id'];
      final categoryName = category['name'];

      // Use the hardcoded mapping based on our debug logs
      // This ensures consistent behavior regardless of cache state
      if ([1, 2, 3, 4, 6, 7, 8, 9, 11].contains(categoryId)) {
        _categoryHasSubcategories[categoryId] = true;
        debugPrint(
            'Updated subcategory mapping for $categoryName: has subcategories = true');
      } else {
        _categoryHasSubcategories[categoryId] =
            category['has_subcategories'] ?? false;
      }
    }
  }

  // Preload category images for better performance
  void _preloadCategoryImages(List<dynamic> categories) {
    final imageUrls = categories
        .take(10) // Preload first 10 category images
        .map((category) => _getCategoryImageUrl(category['image_url']))
        .where((url) => url.isNotEmpty)
        .toList();

    CategoryImagePreloader.preloadImages(imageUrls, context);
  }

  void _highlightCategory(int categoryId, int? subcategoryId) {
    setState(() {
      // _highlightedCategoryId = categoryId;
      // _highlightedSubcategoryId = subcategoryId;
    });

    // Automatically remove highlight after 5 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          // _highlightedCategoryId = null;
          // _highlightedSubcategoryId = null;
        });
      }
    });

    // If this is a subcategory, find and select its parent category first
    if (subcategoryId != null) {
      final subcategory = _subcategoriesMap[categoryId]?.firstWhere(
        (sub) => sub['id'] == subcategoryId,
        orElse: () => null,
      );

      if (subcategory != null) {}
    }
  }

  Future<List<dynamic>> _getAllProductsFromCategories({
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint(
          '🔍 _getAllProductsFromCategories() called with forceRefresh: $forceRefresh');
      final products =
          await _categoryService.getProducts(forceRefresh: forceRefresh);
      _allProducts = products;
      debugPrint(
          '🔍 _getAllProductsFromCategories() returned ${products.length} products');
      return products;
    } catch (e) {
      debugPrint('🔍 Error in _getAllProductsFromCategories: $e');
      return [];
    }
  }

  void _showSearch(BuildContext context) async {
    // Check if we already have products cached
    if (_categoryService.hasCachedProducts) {
      final products = await _categoryService.getProducts();
      _showSearchWithProducts(context, products);
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade700),
              ),
              SizedBox(height: 16),
              Text(
                'Loading products...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );

    // Fetch all products with timeout
    try {
      final products = await _getAllProductsFromCategories().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Loading timeout. Please try again.');
        },
      );

      // Hide loading indicator
      Navigator.of(context).pop();

      if (products.isEmpty) {
        SnackBarUtils.showInfo(
          context,
          'There is no product available currently',
        );
        return;
      }

      _showSearchWithProducts(context, products);
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();

      SnackBarUtils.showError(
        context,
        'Failed to load products. Please try again.',
      );
    }
  }

  void _showSearchWithProducts(BuildContext context, List<dynamic> products) {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        products: products,
        onCategorySelected: _highlightCategory,
        currentCategoryName: null,
      ),
    );
  }

  void _searchProduct(String query) async {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _filteredCategories = _categories;
        _showSearchDropdown = false;
        _searchResults = [];
      });
      return;
    }

    // Set a timer to debounce the search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performSearch(query);
    });
  }

  // Move search to a background isolate and limit results
  Future<void> _performSearch(String query) async {
    setState(() {
      _showSearchDropdown = true;
      _searchResults = []; // Clear previous results while searching
    });

    List<dynamic> productsToSearch = [];
    if (CategoryCache.cachedAllProducts.isNotEmpty) {
      productsToSearch = CategoryCache.cachedAllProducts;
    } else if (_allProducts.isNotEmpty) {
      productsToSearch = _allProducts;
    } else if (query.length >= 2) {
      await _getAllProductsFromCategories(forceRefresh: true);
      productsToSearch = _allProducts;
    }

    // Use compute to search in background
    final productResults = await compute(_filterProducts, {
      'products': productsToSearch,
      'query': query,
    });

    setState(() {
      _searchResults = productResults.take(30).toList(); // Limit to 30 results
    });
  }

  // Background search function for compute
  static List<dynamic> _filterProducts(Map<String, dynamic> args) {
    final products = args['products'] as List<dynamic>;
    final query = args['query'] as String;
    final searchQuery = query.toLowerCase();
    return products.where((product) {
      final productName = (product['name'] ?? '').toString().toLowerCase();
      return productName.contains(searchQuery);
    }).toList();
  }

  void _onSearchItemTap(dynamic item) {
    setState(() {
      _showSearchDropdown = false;
      _searchController.clear();
    });

    // Navigate to the category page where this product belongs
    final categoryId = item['category_id'] ?? item['data']?['category_id'];
    final categoryName =
        item['category_name'] ?? item['data']?['category_name'];
    final subcategoryId =
        item['subcategory_id'] ?? item['data']?['subcategory_id'];
    final searchedProductName = item['name'];
    final searchedProductId = item['id'];

    if (categoryId != null && categoryName != null) {
      // Check if the category has subcategories by looking at the original categories data
      final category = _categories.firstWhere(
        (cat) => cat['id'] == categoryId,
        orElse: () => {'has_subcategories': false},
      );

      if (category['has_subcategories'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubcategoryPage(
              categoryName: categoryName,
              categoryId: categoryId,
              searchedProductName: searchedProductName,
              searchedProductId: searchedProductId,
              targetSubcategoryId:
                  subcategoryId, // Pass the specific subcategory ID
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListPage(
              categoryName: categoryName,
              categoryId: categoryId,
              searchedProductName: searchedProductName,
              searchedProductId: searchedProductId,
            ),
          ),
        );
      }
    } else {
      SnackBarUtils.showError(context, 'Could not navigate to category');
    }
  }

  String _getCategoryImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return 'https://eclcommerce.ernestchemists.com.gh/storage/$imagePath';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';

    // Convert to double if it's a string
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

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();

    // Pharmacy and Medicine categories
    if (name.contains('drug') ||
        name.contains('medicine') ||
        name.contains('medication')) {
      return Icons.medication;
    } else if (name.contains('otc') || name.contains('over the counter')) {
      return Icons.local_pharmacy;
    } else if (name.contains('prescription') || name.contains('pom')) {
      return Icons.medical_services;
    }

    // Health and Wellness categories
    else if (name.contains('health') || name.contains('wellness')) {
      return Icons.health_and_safety;
    } else if (name.contains('vitamin') || name.contains('supplement')) {
      return Icons.medication;
    } else if (name.contains('nutrition') || name.contains('diet')) {
      return Icons.restaurant;
    }

    // Personal Care categories
    else if (name.contains('personal') || name.contains('care')) {
      return Icons.person;
    } else if (name.contains('beauty') || name.contains('cosmetic')) {
      return Icons.face;
    } else if (name.contains('skin') || name.contains('dermatology')) {
      return Icons.face_retouching_natural;
    } else if (name.contains('hair') || name.contains('shampoo')) {
      return Icons.content_cut;
    }

    // Hygiene and Sanitation
    else if (name.contains('sanitary') || name.contains('hygiene')) {
      return Icons.cleaning_services;
    } else if (name.contains('soap') || name.contains('wash')) {
      return Icons.cleaning_services;
    } else if (name.contains('toilet') || name.contains('bathroom')) {
      return Icons.bathroom;
    }

    // Maternal and Child Care
    else if (name.contains('baby') ||
        name.contains('infant') ||
        name.contains('child')) {
      return Icons.child_care;
    } else if (name.contains('mother') ||
        name.contains('maternal') ||
        name.contains('pregnancy')) {
      return Icons.pregnant_woman;
    } else if (name.contains('diaper') || name.contains('nappy')) {
      return Icons.child_care;
    }

    // Sexual Health
    else if (name.contains('sexual') ||
        name.contains('intimate') ||
        name.contains('condom')) {
      return Icons.favorite;
    }

    // Fitness and Sports
    else if (name.contains('sports') ||
        name.contains('fitness') ||
        name.contains('exercise')) {
      return Icons.sports;
    }

    // Medical Equipment and Accessories
    else if (name.contains('accessory') ||
        name.contains('equipment') ||
        name.contains('device')) {
      return Icons.medical_services;
    } else if (name.contains('thermometer') || name.contains('temperature')) {
      return Icons.thermostat;
    } else if (name.contains('bandage') || name.contains('plaster')) {
      return Icons.healing;
    }

    // Specific Health Conditions
    else if (name.contains('diabetes') || name.contains('blood')) {
      return Icons.monitor_heart;
    } else if (name.contains('heart') || name.contains('cardio')) {
      return Icons.favorite;
    } else if (name.contains('eye') ||
        name.contains('vision') ||
        name.contains('glasses')) {
      return Icons.visibility;
    } else if (name.contains('dental') ||
        name.contains('oral') ||
        name.contains('tooth')) {
      return Icons.medical_services;
    } else if (name.contains('ear') ||
        name.contains('nose') ||
        name.contains('throat')) {
      return Icons.hearing;
    }

    // Pain and Relief
    else if (name.contains('pain') ||
        name.contains('ache') ||
        name.contains('relief')) {
      return Icons.healing;
    } else if (name.contains('cough') ||
        name.contains('cold') ||
        name.contains('flu')) {
      return Icons.air;
    } else if (name.contains('fever') || name.contains('temperature')) {
      return Icons.thermostat;
    }

    // Self Care and Wellness
    else if (name.contains('self care') || name.contains('selfcare')) {
      return Icons.spa;
    } else if (name.contains('mental') || name.contains('stress')) {
      return Icons.psychology;
    }

    // Sports Nutrition (specific category - must come before general nutrition)
    else if (name.contains('sports nutrition') ||
        name.contains('sportsnutrition')) {
      return Icons.sports;
    }

    // Food and Nutrition
    else if (name.contains('food') ||
        name.contains('nutrition') ||
        name.contains('diet')) {
      return Icons.restaurant;
    }

    // Default fallback
    else {
      return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        centerTitle: Theme.of(context).appBarTheme.centerTitle,
        leading: AppBackButton(
          backgroundColor: Theme.of(context).primaryColor,
          onPressed: () {
            if (widget.isBulkPurchase) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkPurchasePage(),
                ),
              );
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            }
          },
        ),
        title: Text(
          'Categories',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          CartIconButton(
            iconColor: Colors.white,
            iconSize: 24,
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading ? _buildSkeletonWithLoading() : _buildMainContent(),
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 2),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const CategoryPageSkeletonBody(),
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
                    'Loading categories...',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Section
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar with Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _searchProduct,
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          setState(() {
                            _showSearchDropdown = true;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Search products...",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  // Search Dropdown
                  if (_showSearchDropdown)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      constraints:
                          BoxConstraints(maxHeight: 320), // Increased height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Debug header
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Search Results (${_searchResults.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Results
                          Flexible(
                            child: _isLoadingProducts
                                ? Container(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.green.shade700),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Loading products...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _searchResults.isEmpty
                                    ? Container(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 32,
                                              color: Colors.grey.shade400,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'No products found',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      )
                                    : Scrollbar(
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          primary:
                                              false, // Prevent PrimaryScrollController conflict
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: _searchResults.length,
                                          itemBuilder: (context, index) {
                                            final item = _searchResults[index];
                                            return _buildSearchResultItem(item);
                                          },
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Find products by name',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        ),
        // Categories Title
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Browse Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_filteredCategories.length} found',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        // Categories Grid
        Expanded(child: _buildCategoriesGrid()),
      ],
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      transitionDuration: Duration(milliseconds: 200),
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      openBuilder: (context, _) {
        // Navigate to the category page where this product belongs
        final categoryId = item['category_id'] ?? item['data']?['category_id'];
        final categoryName =
            item['category_name'] ?? item['data']?['category_name'];
        final subcategoryId =
            item['subcategory_id'] ?? item['data']?['subcategory_id'];
        final searchedProductName = item['name'];
        final searchedProductId = item['id'];

        if (categoryId != null && categoryName != null) {
          // Check if the category has subcategories by looking at the original categories data
          final category = _categories.firstWhere(
            (cat) => cat['id'] == categoryId,
            orElse: () => {'has_subcategories': false},
          );

          if (category['has_subcategories'] == true) {
            return SubcategoryPage(
              categoryName: categoryName,
              categoryId: categoryId,
              searchedProductName: searchedProductName,
              searchedProductId: searchedProductId,
              targetSubcategoryId: subcategoryId,
            );
          } else {
            return ProductListPage(
              categoryName: categoryName,
              categoryId: categoryId,
              searchedProductName: searchedProductName,
              searchedProductId: searchedProductId,
            );
          }
        } else {
          // Fallback to categories page if navigation fails
          return CategoryPage();
        }
      },
      closedBuilder: (context, openContainer) => InkWell(
        onTap: openContainer,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Product thumbnail
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: item['thumbnail'] ?? '',
                    fit: BoxFit.cover,
                    memCacheWidth: 80,
                    memCacheHeight: 80,
                    maxWidthDiskCache: 80,
                    maxHeightDiskCache: 80,
                    cacheKey: 'search_${item['id']}_${item['thumbnail']}',
                    placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.broken_image, size: 20),
                  ),
                ),
              ),
              SizedBox(width: 10),
              // Product content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'GHS ${_formatPrice(item['price'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item['category_name'] != null) ...[
                      SizedBox(height: 1),
                      Text(
                        item['category_name'],
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_filteredCategories.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        int crossAxisCount = 2;
        if (screenWidth > 900) {
          crossAxisCount = 4;
        } else if (screenWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: _filteredCategories.length,
          itemBuilder: (context, index) {
            final category = _filteredCategories[index];
            debugPrint('Building category card $index: ${category['name']}');
            final icon = _getCategoryIcon(category['name'] ?? '');
            final iconColor = Colors.green.shade700;
            final available =
                category['product_count'] ?? category['available'];
            return OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedColor: Colors.transparent,
              closedElevation: 0,
              openElevation: 0,
              transitionDuration: Duration(milliseconds: 200),
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              openBuilder: (context, _) {
                // Use the cached subcategory information if available
                final hasSubcategories =
                    _categoryHasSubcategories[category['id']] ??
                        category['has_subcategories'] ??
                        false;

                if (hasSubcategories) {
                  return SubcategoryPage(
                    categoryName: category['name'],
                    categoryId: category['id'],
                  );
                } else {
                  return ProductListPage(
                    categoryName: category['name'],
                    categoryId: category['id'],
                  );
                }
              },
              closedBuilder: (context, openContainer) => _ModernCategoryCard(
                name: category['name'] ?? '',
                icon: icon,
                iconColor: iconColor,
                available: available is int ? available : null,
                onTap: openContainer,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.orange.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              _clearCacheAndReload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Clear cache and reload data
  Future<void> _clearCacheAndReload() async {
    CategoryCache.clearCache();
    CategoryImagePreloader.clearPreloadedImages();
    await _loadCategoriesOptimized();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload images when dependencies change (e.g., when coming back to this page)
    if (_categories.isNotEmpty) {
      _preloadCategoryImages(_categories);
    }
  }

  // Prefetch all products and cache them
  Future<void> _prefetchAllProducts() async {
    debugPrint('🔍 ==========================================');
    debugPrint('🔍 _prefetchAllProducts() method started');
    debugPrint('🔍 ==========================================');
    try {
      debugPrint(
          '🔍 Calling _categoryService.getProducts() with forceRefresh: true...');
      final products = await _categoryService.getProducts(forceRefresh: true);
      debugPrint(
          '🔍 Received ${products.length} products from service with otcpom data');
      _allProducts = products;
      CategoryCache.cacheAllProducts(products);
      debugPrint('🔍 Cached ${products.length} products in CategoryCache');

      setState(() {});
    } catch (e) {
      debugPrint('🔍 Error in _prefetchAllProducts: $e');
    }
    debugPrint('🔍 ==========================================');
    debugPrint('🔍 _prefetchAllProducts() method completed');
    debugPrint('🔍 ==========================================');
  }

  Future<void> _enhanceCachedProductsWithOtcpom() async {
    debugPrint('🔍 _enhanceCachedProductsWithOtcpom() method started');
    debugPrint('🔍 About to access CategoryCache.cachedAllProducts...');

    final cachedProducts = CategoryCache.cachedAllProducts;
    debugPrint(
        '🔍 Enhancing ${cachedProducts.length} cached products with otcpom data');

    for (int i = 0; i < cachedProducts.length; i++) {
      final product = cachedProducts[i];
      final productId = product['id'];

      try {
        debugPrint(
            '🔍 Fetching otcpom for product ${i + 1}/${cachedProducts.length}: ${product['name']}');
        final response = await http.get(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/products/$productId'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final productData = data['data'];
            final otcpom = productData['otcpom'];

            if (otcpom != null) {
              cachedProducts[i]['otcpom'] = otcpom;
              debugPrint('🔍 Enhanced ${product['name']} with otcpom: $otcpom');
            } else {
              debugPrint('🔍 No otcpom data for ${product['name']}');
            }
          } else {
            debugPrint('🔍 API returned success=false for ${product['name']}');
          }
        } else {
          debugPrint(
              '🔍 API returned status ${response.statusCode} for ${product['name']}');
        }
      } catch (e) {
        debugPrint('🔍 Error enhancing ${product['name']}: $e');
      }
    }

    // Update the cache with enhanced products
    CategoryCache.cacheAllProducts(cachedProducts);
    debugPrint('🔍 _enhanceCachedProductsWithOtcpom() method completed');

    // Trigger UI rebuild to show enhanced products
    if (mounted) {
      setState(() {});
      debugPrint('🔍 UI rebuild triggered after product enhancement');
    }

    // Force rebuild of all ProductCards by triggering a global rebuild
    // This will cause all ProductCards to re-convert with enhanced data
    debugPrint(
        '🔍 Product enhancement completed - all ProductCards should now show otcpom data');
  }
}

// Skeleton screen for category page
class CategoryPageSkeletonBody extends StatelessWidget {
  const CategoryPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Column(
        children: [
          // Search bar skeleton
          Container(
            margin: EdgeInsets.all(16),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Categories title skeleton
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Categories grid skeleton
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton screen for subcategory page
class SubcategoryPageSkeletonBody extends StatelessWidget {
  const SubcategoryPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Row(
        children: [
          // Sidebar skeleton
          Container(
            width: 200,
            color: Colors.white,
            child: Column(
              children: [
                // Header skeleton
                Container(
                  height: 50,
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Sidebar items skeleton
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Container(
                        height: 40,
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content skeleton
          Expanded(
            child: Column(
              children: [
                // Header skeleton
                Container(
                  height: 60,
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Products grid skeleton
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton screen for product list page
class ProductListPageSkeletonBody extends StatelessWidget {
  const ProductListPageSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.grey[200]!,
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 80,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Products grid skeleton
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernCategoryCard extends StatelessWidget {
  final String name;
  final int? available;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ModernCategoryCard({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.available,
  });

  static String _getBackgroundImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('medicine') ||
        lower.contains('drug') ||
        lower.contains('medication')) {
      return 'assets/images/Medicines ECL.jpg';
    } else if (lower.contains('sport') ||
        lower.contains('fitness') ||
        lower.contains('nutrition')) {
      return 'assets/images/Sports Nutrition ECL.jpg';
    } else if (lower.contains('sexual') ||
        lower.contains('intimate') ||
        lower.contains('condom')) {
      return 'assets/images/Sexual Health ECL.jpg';
    } else {
      return 'assets/images/Medicines ECL.jpg'; // fallback for now
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Rendering _ModernCategoryCard for: $name');
    final String bgImage = _getBackgroundImage(name);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.18),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Text at the bottom left
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 48, 3), // extra right padding to avoid arrow
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (available != null)
                      Text(
                        '$available Available',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Arrow button
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: onTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubcategoryPage extends StatefulWidget {
  final String categoryName;
  final int categoryId;
  final String? searchedProductName;
  final int? searchedProductId;
  final int? targetSubcategoryId;

  const SubcategoryPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
    this.targetSubcategoryId,
  });

  @override
  SubcategoryPageState createState() => SubcategoryPageState();
}

class SubcategoryPageState extends State<SubcategoryPage> {
  List<dynamic> subcategories = [];
  List<dynamic> products = [];
  bool isLoading = true;
  String errorMessage = '';
  int? selectedSubcategoryId;
  final ScrollController scrollController = ScrollController();
  bool showScrollToTop = false;
  String sortOption = 'Latest';
  int? highlightedProductId;
  Timer? highlightTimer;
  bool isSidebarVisible = true; // New state for sidebar visibility

  // Cache for subcategories and products
  static final Map<int, List<dynamic>> _subcategoriesCache = {};
  static final Map<int, List<dynamic>> _productsCache = {};
  static final Map<int, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    // Clear cache to ensure fresh data with otcpom
    _clearSubcategoryCache();
    _loadSubcategoriesOptimized();
    _setupScrollListener();
  }

  @override
  void dispose() {
    scrollController.dispose();
    highlightTimer?.cancel();
    super.dispose();
  }

  // Optimized loading that checks cache first
  Future<void> _loadSubcategoriesOptimized() async {
    // Check if we have valid cached data
    if (_isCacheValid(widget.categoryId) &&
        _subcategoriesCache.containsKey(widget.categoryId)) {
      final cachedSubcategories = _subcategoriesCache[widget.categoryId]!;

      if (mounted) {
        setState(() {
          subcategories = cachedSubcategories;
          isLoading = false;
        });
      }

      // Auto-select first subcategory or target subcategory
      _autoSelectSubcategory(cachedSubcategories);
      return;
    }

    // Otherwise, load from API
    await fetchSubcategories();
  }

  bool _isCacheValid(int categoryId) {
    final timestamp = _cacheTimestamps[categoryId];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheValidDuration;
  }

  void _autoSelectSubcategory(List<dynamic> subcategories) {
    if (subcategories.isNotEmpty) {
      if (widget.targetSubcategoryId != null) {
        final targetSubcategory = subcategories.firstWhere((sub) {
          final subId = sub['id'];
          final targetId = widget.targetSubcategoryId;
          return subId.toString() == targetId.toString();
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(targetSubcategory['id']);
      } else {
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(firstSubcategory['id']);
      }
    }
  }

  Future<void> fetchSubcategories() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/categories/${widget.categoryId}',
            ),
          )
          .timeout(Duration(seconds: 8)); // Reduced timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final subcategoriesData = data['data'] as List;

          // Cache the subcategories
          _subcategoriesCache[widget.categoryId] = subcategoriesData;
          _cacheTimestamps[widget.categoryId] = DateTime.now();

          handleSubcategoriesSuccess(data);
        } else {
          handleSubcategoriesError('Failed to load subcategories');
        }
      } else {
        handleSubcategoriesError(
          'Failed to load subcategories: ${response.statusCode}',
        );
      }
    } catch (e) {
      handleSubcategoriesError('Error: ${e.toString()}');
    }
  }

  void onSubcategorySelected(int subcategoryId) async {
    if (!mounted) return;

    setState(() {
      selectedSubcategoryId = subcategoryId;
      isLoading = true;
      products = [];
    });

    // Check if we have cached products for this subcategory
    if (_productsCache.containsKey(subcategoryId) &&
        _isCacheValid(subcategoryId)) {
      final cachedProducts = _productsCache[subcategoryId]!;

      if (mounted) {
        setState(() {
          products = cachedProducts;
          isLoading = false;
        });
      }

      // Highlight searched product if available
      if (widget.searchedProductId != null) {
        _highlightSearchedProduct();
      }
      return;
    }

    try {
      // Use the correct endpoint for products in a subcategory
      final apiUrl =
          'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId';

      final response =
          await http.get(Uri.parse(apiUrl)).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final allProducts = data['data'] as List;

          // Debug print to see the first product structure
          if (allProducts.isNotEmpty) {
            final firstProduct = allProducts[0];
            debugPrint('🔍 CATEGORIES API RESPONSE STRUCTURE ===');
            debugPrint('First Product Keys: ${firstProduct.keys.toList()}');
            debugPrint('First Product OTCPOM: ${firstProduct['otcpom']}');
            debugPrint('==========================================');
          }

          if (allProducts.isEmpty) {
            handleProductsError('There is no product available currently');
          } else {
            // Enhance products with otcpom data
            debugPrint(
                '🔍 Enhancing ${allProducts.length} products with otcpom data for subcategory $subcategoryId');
            await _enhanceProductsWithOtcpom(allProducts);

            // Cache the enhanced products
            _productsCache[subcategoryId] = allProducts;
            _cacheTimestamps[subcategoryId] = DateTime.now();

            handleProductsSuccess(data);
          }
        } else {
          handleProductsError('There is no product available currently');
        }
      } else {
        handleProductsError('Failed to load products');
      }
    } catch (e) {
      handleProductsError('Error: ${e.toString()}');
    }
  }

  void handleSubcategoriesSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      subcategories = data['data'];
      isLoading = false;
    });

    debugPrint('🔍 SUBCATEGORIES LOADED ===');
    debugPrint('Subcategories count: ${subcategories.length}');
    debugPrint(
        'Subcategories: ${subcategories.map((s) => s['name']).toList()}');
    debugPrint('==========================');

    if (subcategories.isNotEmpty) {
      // If we have a target subcategory from search, select it
      if (widget.targetSubcategoryId != null) {
        final targetSubcategory = subcategories.firstWhere((sub) {
          final subId = sub['id'];
          final targetId = widget.targetSubcategoryId;
          // Handle both string and int comparisons
          return subId.toString() == targetId.toString();
        }, orElse: () => subcategories[0]);
        onSubcategorySelected(targetSubcategory['id']);
      } else {
        // Otherwise select the first subcategory as before
        final firstSubcategory = subcategories[0];
        onSubcategorySelected(firstSubcategory['id']);
      }
    }
  }

  void handleSubcategoriesError(String message) {
    if (!mounted) return;

    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  void handleProductsSuccess(dynamic data) {
    if (!mounted) return;

    setState(() {
      products = data['data'];
      isLoading = false;
    });

    // Highlight searched product if available
    if (widget.searchedProductId != null) {
      _highlightSearchedProduct();
    }

    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void handleProductsError(String message) {
    if (!mounted) return;

    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  // Clear subcategory cache to ensure fresh data
  void _clearSubcategoryCache() {
    debugPrint(
        '🔍 Clearing subcategory cache for category ${widget.categoryId}');
    _subcategoriesCache.remove(widget.categoryId);
    _productsCache.remove(widget.categoryId);
    _cacheTimestamps.remove(widget.categoryId);
  }

  // Enhance products with otcpom data using ProductCache from homepage
  Future<void> _enhanceProductsWithOtcpom(List<dynamic> products) async {
    debugPrint(
        '🔍 Starting otcpom enhancement for ${products.length} products using ProductCache');

    try {
      // Get cached products from homepage (which have otcpom data)
      final cachedProducts = ProductCache.cachedProducts;
      debugPrint(
          '🔍 Found ${cachedProducts.length} cached products from ProductCache');

      if (cachedProducts.isEmpty) {
        debugPrint('🔍 No cached products available, trying API call...');
        // Fallback to API call if cache is empty
        await _enhanceProductsWithAPI(products);
        return;
      }

      // Create a map of product names to otcpom data for quick lookup
      final Map<String, String?> otcpomMap = {};
      for (final product in cachedProducts) {
        final productName = product.name?.toString().toLowerCase();
        final otcpom = product.otcpom;
        if (productName != null) {
          otcpomMap[productName] = otcpom;
        }
      }

      debugPrint(
          '🔍 Created otcpom map with ${otcpomMap.length} products from cache');

      // Enhance the subcategory products with otcpom data
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final productName = product['name']?.toString().toLowerCase();

        if (productName != null && otcpomMap.containsKey(productName)) {
          final otcpom = otcpomMap[productName];
          products[i]['otcpom'] = otcpom;
          debugPrint('🔍 Enhanced ${product['name']} with otcpom: $otcpom');
        } else {
          debugPrint('🔍 No otcpom data found for ${product['name']}');
        }
      }
    } catch (e) {
      debugPrint('🔍 Error using ProductCache: $e');
      // Fallback to API call
      await _enhanceProductsWithAPI(products);
    }

    debugPrint(
        '🔍 Completed otcpom enhancement for ${products.length} products');
  }

  // Fallback method to enhance products with API call
  Future<void> _enhanceProductsWithAPI(List<dynamic> products) async {
    debugPrint('🔍 Fallback: Using API call for otcpom enhancement');

    try {
      final response = await http
          .get(Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        debugPrint(
            '🔍 Fetched ${dataList.length} products from get-all-products API');

        final Map<String, String?> otcpomMap = {};
        for (final item in dataList) {
          final productData = item['product'] as Map<String, dynamic>;
          final productName = productData['name']?.toString().toLowerCase();
          final otcpom = productData['otcpom'];
          if (productName != null) {
            otcpomMap[productName] = otcpom;
          }
        }

        for (int i = 0; i < products.length; i++) {
          final product = products[i];
          final productName = product['name']?.toString().toLowerCase();

          if (productName != null && otcpomMap.containsKey(productName)) {
            final otcpom = otcpomMap[productName];
            products[i]['otcpom'] = otcpom;
            debugPrint('🔍 Enhanced ${product['name']} with otcpom: $otcpom');
          }
        }
      }
    } catch (e) {
      debugPrint('🔍 Error in fallback API call: $e');
    }
  }

  void _highlightSearchedProduct() {
    if (widget.searchedProductId != null && mounted) {
      setState(() {
        highlightedProductId = widget.searchedProductId;
      });

      // Find the index of the searched product
      final productIndex = products.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        // Wait for the widget to be built and then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            // Calculate the position to scroll to
            final itemHeight = 250.0;
            final crossAxisCount = 2;
            final rowIndex = productIndex ~/ crossAxisCount;
            final scrollPosition = (rowIndex * itemHeight) + 100;

            // Scroll to the product
            scrollController.animateTo(
              scrollPosition,
              duration: Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      // Do NOT remove highlight after a timer; keep it until the page is left.
    }
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      if (mounted) {
        setState(() {
          showScrollToTop = scrollController.offset > 300;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildMainContent(),
      floatingActionButton: showScrollToTop ? _buildScrollToTopButton() : null,
      bottomNavigationBar: CustomBottomNav(initialIndex: 2),
    );
  }

  Widget _buildMainContent() {
    if (isLoading && subcategories.isEmpty) {
      return buildSubcategoriesLoadingState();
    } else if (subcategories.isEmpty) {
      return buildErrorState("No subcategories found");
    } else {
      return buildBody();
    }
  }

  Widget _buildScrollToTopButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.green.shade700,
      child: Icon(Icons.keyboard_arrow_up, color: Colors.white),
      onPressed: () {
        scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Widget buildBody() {
    if (isLoading && subcategories.isEmpty) {
      return _buildSkeletonWithLoading();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout based on screen width
        bool isTablet = constraints.maxWidth > 600;
        double sideNavWidth = isTablet ? 260 : constraints.maxWidth * 0.35;
        // Ensure minimum width for sidebar with proper bounds
        double minWidth = 200.0;
        double maxWidth = constraints.maxWidth * 0.45;
        // Ensure min is not greater than max
        if (minWidth > maxWidth) {
          minWidth = maxWidth * 0.8; // Use 80% of max as min
        }
        sideNavWidth = sideNavWidth.clamp(minWidth, maxWidth);

        // Only force hide sidebar if screen is extremely narrow
        bool isScreenTooNarrow = constraints.maxWidth < 250;
        if (isScreenTooNarrow && isSidebarVisible) {
          isSidebarVisible = false;
        }

        return Row(
          children: [
            // Sidebar - only render when visible
            if (isSidebarVisible)
              SizedBox(
                width: sideNavWidth,
                child: buildSideNavigation(),
              ),
            // Toggle button when sidebar is hidden
            if (!isSidebarVisible)
              Container(
                margin: EdgeInsets.only(left: 16, top: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          isSidebarVisible = true;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Main content
            Expanded(
              child: Container(
                color: Color(0xFFF8F9FA),
                child: Column(
                  children: [
                    // Sticky subcategory header - Always show for debugging
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: subcategories.isNotEmpty
                          ? buildSubcategoryHeader()
                          : Container(
                              padding: EdgeInsets.all(8),
                              color: Colors.red.shade100,
                              child: Text(
                                'DEBUG: subcategories.isEmpty = ${subcategories.isEmpty}, length = ${subcategories.length}',
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ),
                    ),
                    // Products content
                    Expanded(child: _buildProductsContent()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const SubcategoryPageSkeletonBody(),
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
                    'Loading subcategories...',
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

  Widget buildSideNavigation() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  color: Colors.green.shade700,
                  size: 13,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Hide sidebar button
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: Icon(Icons.chevron_left,
                        size: 18, color: Colors.green.shade700),
                    onPressed: () {
                      setState(() {
                        isSidebarVisible = false;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = subcategories[index];
                final bool isSelected =
                    selectedSubcategoryId == subcategory['id'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSubcategorySelected(subcategory['id']),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.shade50
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.green.shade700
                              : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          if (isSelected)
                            Container(
                              width: 4,
                              height: 4,
                              margin: EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              subcategory['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green.shade700,
                              ),
                            ),
                        ],
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

  Widget buildSubcategoryHeader() {
    final selectedSubcategory = selectedSubcategoryId != null
        ? subcategories.firstWhere(
            (sub) => sub['id'] == selectedSubcategoryId,
            orElse: () => subcategories.isNotEmpty
                ? subcategories[0]
                : {'name': 'All Products', 'id': null},
          )
        : subcategories.isNotEmpty
            ? subcategories[0]
            : {'name': 'All Products', 'id': null};

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.category_outlined,
              color: Colors.green.shade700,
              size: 16,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedSubcategoryId != null
                      ? (selectedSubcategory['name'] ?? 'All Products')
                      : 'All Products',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '${products.length} products available',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsContent() {
    if (isLoading) {
      return buildProductsLoadingState();
    } else if (products.isEmpty) {
      return buildEmptyState();
    } else {
      return buildProductsGrid();
    }
  }

  Widget buildProductsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep 2 columns but adjust aspect ratio based on sidebar visibility
        double childAspectRatio = 0.55;

        if (!isSidebarVisible) {
          // When sidebar is hidden, make images smaller (larger aspect ratio = shorter/wider images)
          childAspectRatio = 0.85;
        } else {
          // When sidebar is visible, use normal size
          childAspectRatio = 0.55;
        }

        return GridView.builder(
          controller: scrollController,
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final isHighlighted = highlightedProductId == product['id'];

            return Container(
              decoration: isHighlighted
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.green.shade700, width: 3),
                    )
                  : null,
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                openColor: Theme.of(context).scaffoldBackgroundColor,
                closedColor: Colors.transparent,
                closedElevation: 0,
                openElevation: 0,
                transitionDuration: Duration(milliseconds: 200),
                closedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                openBuilder: (context, _) {
                  String? itemDetailURL = product['urlname'] ??
                      product['url'] ??
                      product['inventory']?['urlname'] ??
                      product['route']?.split('/').last;

                  if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
                    final isPrescribed =
                        product['otcpom']?.toString().toLowerCase() == 'pom';
                    debugPrint(
                        '🔍 Navigation Debug - Product: ${product['name']}, otcpom: ${product['otcpom']}, isPrescribed: $isPrescribed');
                    return ItemPage(
                      urlName: itemDetailURL,
                      isPrescribed: isPrescribed,
                    );
                  } else {
                    final productId = product['id']?.toString();
                    if (productId != null) {
                      return ItemPage(
                        urlName: productId,
                        isPrescribed:
                            product['otcpom']?.toString().toLowerCase() ==
                                'pom',
                      );
                    } else {
                      // Fallback to a default page if navigation fails
                      return CategoryPage();
                    }
                  }
                },
                closedBuilder: (context, openContainer) => ProductCard(
                  product: product,
                  onTap: openContainer,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSubcategoriesLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
      ),
    );
  }

  Widget buildProductsLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.orange.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = '';
              });
              fetchSubcategories();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final dynamic product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Product? _product;
  Timer? _cacheCheckTimer;

  @override
  void initState() {
    super.initState();
    _convertToProduct();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _convertToProduct() {
    try {
      _product = Product.fromJson(Map<String, dynamic>.from(widget.product));
      debugPrint(
          '🔍 Converted ${_product!.name} to Product object with otcpom: ${_product!.otcpom}');
    } catch (e) {
      debugPrint('🔍 Error converting product to Product object: $e');
      _product = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_product == null) {
      // Fallback to original logic if conversion failed
      final otcpomValue = widget.product['otcpom']?.toString().toLowerCase();
      final isPrescribed = otcpomValue == 'pom';
      debugPrint(
          '🔍 ProductCard Debug (fallback) - ${widget.product['name']}: otcpom=$otcpomValue, isPrescribed=$isPrescribed');
      return _buildProductCard(context, isPrescribed, widget.product);
    }

    // Use Product object logic (same as HomeProductCard)
    final isPrescribed = _product!.otcpom?.toLowerCase() == 'pom';
    debugPrint(
        '🔍 ProductCard Debug (Product object) - ${_product!.name}: otcpom=${_product!.otcpom}, isPrescribed=$isPrescribed');

    // Additional debug for badge rendering
    if (isPrescribed) {
      debugPrint('🔍 WILL SHOW BADGE for ${_product!.name}');
    } else {
      debugPrint(
          '🔍 NO BADGE for ${_product!.name} - otcpom: ${_product!.otcpom}');
    }

    return _buildProductCard(context, isPrescribed, widget.product);
  }

  Widget _buildProductCard(
      BuildContext context, bool isPrescribed, dynamic productData) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: productData['thumbnail'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 300,
                        memCacheHeight: 300,
                        maxWidthDiskCache: 300,
                        maxHeightDiskCache: 300,
                        fadeInDuration: Duration(milliseconds: 100),
                        fadeOutDuration: Duration(milliseconds: 100),
                        cacheKey:
                            'product_${productData['id']}_${productData['thumbnail']}',
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Prescribed medicine badge
                  if (isPrescribed)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Prescribed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productData['name'] ?? 'Unknown Product',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: Colors.black87,
                      height: 1.3,
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

class ProductListPage extends StatefulWidget {
  final String categoryName;
  final int categoryId;
  final String? searchedProductName;
  final int? searchedProductId;

  ProductListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
  }) {
    debugPrint(
        '🔍 ProductListPage constructor called for category: $categoryName (ID: $categoryId)');
  }

  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<dynamic> products = [];
  bool isLoading = true;
  String errorMessage = '';
  final ScrollController scrollController = ScrollController();
  bool showScrollToTop = false;
  String sortOption = 'Latest';
  int? highlightedProductId;
  Timer? highlightTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 ProductListPage initState() called');
    fetchProducts();
    scrollController.addListener(() {
      setState(() {
        showScrollToTop = scrollController.offset > 300;
      });
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchProducts() async {
    debugPrint('🔍 fetchProducts() method started');
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await http.get(
        Uri.parse(
          'https://eclcommerce.ernestchemists.com.gh/api/product-categories/${widget.categoryId}',
        ),
      );

      debugPrint('🔍 API Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('🔍 API Response Success: ${data['success']}');
        if (data['success'] == true) {
          setState(() {
            products = data['data'];
            isLoading = false;
          });

          // Debug: Check if products have otcpom field
          if (products.isNotEmpty) {
            final firstProduct = products.first;
            debugPrint('🔍 Category Products Debug:');
            debugPrint('First Product: ${firstProduct['name']}');
            debugPrint('First Product OTCPOM: ${firstProduct['otcpom']}');
            debugPrint('First Product Keys: ${firstProduct.keys.toList()}');
            debugPrint(
                '🔍 WARNING: Category API does not include otcpom field!');
          }

          // Enhance products with otcpom data from cached products if missing
          debugPrint('🔍 About to call _enhanceProductsWithOtcpom()');
          try {
            await _enhanceProductsWithOtcpom();
            debugPrint(
                '🔍 _enhanceProductsWithOtcpom() completed successfully');
          } catch (e) {
            debugPrint('🔍 ERROR in _enhanceProductsWithOtcpom(): $e');
          }

          // Highlight searched product if available
          if (widget.searchedProductId != null) {
            _highlightSearchedProduct();
          }
        } else {
          debugPrint('🔍 API returned success=false');
          setState(() {
            isLoading = false;
            errorMessage = 'There is no product available currently';
          });
        }
      } else {
        debugPrint('🔍 API returned status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load products: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('🔍 ERROR in fetchProducts(): $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
    }
    debugPrint('🔍 fetchProducts() method completed');
  }

  Future<void> _enhanceProductsWithOtcpom() async {
    debugPrint('🔍 _enhanceProductsWithOtcpom() method started');

    // Get cached products from homepage
    final cachedProducts = ProductCache.cachedProducts;

    debugPrint(
        '🔍 ProductCache status: ${cachedProducts.length} cached products');

    // Since category API doesn't include otcpom data, always fetch it from API
    debugPrint(
        '🔍 Category API missing otcpom data, fetching from individual product APIs');
    await _fetchOtcpomDataFromAPI();
    debugPrint('🔍 _enhanceProductsWithOtcpom() method completed');

    // Trigger rebuild to show the enhanced data
    setState(() {});
  }

  Future<void> _fetchOtcpomDataFromAPI() async {
    debugPrint('🔍 _fetchOtcpomDataFromAPI() method started');
    debugPrint(
        '🔍 Fetching otcpom data directly from API for ${products.length} products');

    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final productId = product['id'];

      try {
        final response = await http.get(
          Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/products/$productId'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final productData = data['data'];
            final otcpom = productData['otcpom'];

            if (otcpom != null) {
              products[i]['otcpom'] = otcpom;
              debugPrint('🔍 Fetched otcpom for ${product['name']}: $otcpom');
            } else {
              debugPrint(
                  '🔍 No otcpom data in API response for ${product['name']}');
            }
          }
        }
      } catch (e) {
        debugPrint(
            '🔍 Error fetching otcpom for product ${product['name']}: $e');
      }
    }

    // Trigger rebuild to show the enhanced data
    setState(() {});
    debugPrint('🔍 _fetchOtcpomDataFromAPI() method completed');
  }

  void _highlightSearchedProduct() {
    if (widget.searchedProductId != null && mounted) {
      setState(() {
        highlightedProductId = widget.searchedProductId;
      });

      // Find the index of the searched product
      final productIndex = products.indexWhere(
        (product) => product['id'] == widget.searchedProductId,
      );

      if (productIndex != -1) {
        // Wait for the widget to be built and then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            // Calculate the position to scroll to
            final itemHeight = 250.0;
            final crossAxisCount = 2;
            final rowIndex = productIndex ~/ crossAxisCount;
            final scrollPosition = (rowIndex * itemHeight) + 100;

            // Scroll to the product
            scrollController.animateTo(
              scrollPosition,
              duration: Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      // Do NOT remove highlight after a timer; keep it until the page is left.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade700, Colors.green.shade900],
            ),
          ),
        ),
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.green[700] ?? Colors.green,
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            }
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${products.length} products found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildProductsList()),
        ],
      ),
      floatingActionButton: showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.green.shade700,
              child: Icon(Icons.keyboard_arrow_up, color: Colors.white),
              onPressed: () {
                scrollController.animateTo(
                  0,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
            )
          : null,
    );
  }

  Widget _buildProductsList() {
    if (isLoading) {
      return _buildSkeletonWithLoading();
    }

    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: fetchProducts,
      color: Colors.green.shade700,
      child: GridView.builder(
        controller: scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final isHighlighted = highlightedProductId == product['id'];

          return Container(
            decoration: isHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade700, width: 3),
                  )
                : null,
            child: OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedColor: Colors.transparent,
              closedElevation: 0,
              openElevation: 0,
              transitionDuration: Duration(milliseconds: 200),
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              openBuilder: (context, _) {
                String? itemDetailURL = product['urlname'] ??
                    product['url'] ??
                    product['inventory']?['urlname'] ??
                    product['route']?.split('/').last;

                if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
                  final isPrescribed =
                      product['otcpom']?.toString().toLowerCase() == 'pom';
                  debugPrint(
                      '🔍 Navigation Debug - Product: ${product['name']}, otcpom: ${product['otcpom']}, isPrescribed: $isPrescribed');
                  return ItemPage(
                    urlName: itemDetailURL,
                    isPrescribed: isPrescribed,
                  );
                } else {
                  final productId = product['id']?.toString();
                  if (productId != null) {
                    return ItemPage(
                      urlName: productId,
                      isPrescribed:
                          product['otcpom']?.toString().toLowerCase() == 'pom',
                    );
                  } else {
                    // Fallback to a default page if navigation fails
                    return CategoryPage();
                  }
                }
              },
              closedBuilder: (context, openContainer) => ProductCard(
                product: product,
                onTap: openContainer,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonWithLoading() {
    return Stack(
      children: [
        const ProductListPageSkeletonBody(),
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
                    'Loading products...',
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

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
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
            size: 64,
            color: Colors.orange.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = '';
              });
              fetchProducts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'There is no product available currently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Please check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> products;
  final Function(int categoryId, int? subcategoryId) onCategorySelected;
  final String? currentCategoryName;

  ProductSearchDelegate({
    required this.products,
    required this.onCategorySelected,
    this.currentCategoryName,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredProducts = query.isEmpty
        ? []
        : products.where((product) {
            return product['name'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                );
          }).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              currentCategoryName != null
                  ? 'Search in $currentCategoryName'
                  : 'Search all products',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'There is no product available currently',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final itemDetailURL = product['urlname'] ??
            product['url'] ??
            product['inventory']?['urlname'] ??
            product['route']?.split('/').last;
        final categoryId = product['category_id'];
        final subcategoryId = product['subcategory_id'];
        final categoryName = product['category_name'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: product['thumbnail'] ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 120,
                memCacheHeight: 120,
                maxWidthDiskCache: 120,
                maxHeightDiskCache: 120,
                cacheKey:
                    'search_list_${product['id']}_${product['thumbnail']}',
                errorWidget: (context, url, error) => Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          title: Text(
            product['name'] ?? 'Unknown Product',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GHS ${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: Colors.green.shade700, fontSize: 14),
              ),
              if (categoryName != null)
                Text(
                  'Category: $categoryName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            close(context, '');
            // Highlight the category first
            onCategorySelected(categoryId, subcategoryId);
            // Then navigate to product detail
            if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemPage(
                    urlName: itemDetailURL!,
                    isPrescribed:
                        product['otcpom']?.toString().toLowerCase() == 'pom',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
