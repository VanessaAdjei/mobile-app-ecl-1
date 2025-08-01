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
import 'package:eclapp/pages/AppBackButton.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/pages/bulk_purchase_page.dart';
import 'package:eclapp/pages/bottomnav.dart';

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
  static List<dynamic> get cachedAllProducts => _cachedAllProducts;

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
  Timer? _highlightTimer;
  List<dynamic> _allProducts = [];
  bool _isLoadingProducts = false;
  bool _showSearchDropdown = false;
  List<dynamic> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    // Load cached data immediately if available
    if (CategoryCache.isCacheValid) {
      setState(() {
        _categories = CategoryCache.cachedCategories;
        _filteredCategories = CategoryCache.cachedCategories;
        _isLoading = false;
        _errorMessage = '';
      });
    }
    _loadCategoriesOptimized();

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          _showSearchDropdown = false;
        });
      }
    });
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
        if (CategoryCache.isCacheValid &&
        CategoryCache.cachedCategories.isNotEmpty) {
      final cachedCategories = CategoryCache.cachedCategories;
      _processCategories(cachedCategories);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
      }

      // Preload images in background
      _preloadCategoryImages(cachedCategories);
      return;
    }

    // Only show loading if we don't have cached data
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Otherwise, load normally
    await _fetchTopCategories();
  }

  // Process categories and update state
  void _processCategories(List<dynamic> categories) {
    if (!mounted) return;

    setState(() {
      _categories = categories;
      _filteredCategories = categories;
      _isLoading = false; // Ensure loading is set to false
    });
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

      if (subcategory != null) {
        // Remove the call to onSubcategorySelected as it doesn't exist in this class
        // This method is only available in SubcategoryPageState
      }
    }
  }

  Future<void> _fetchTopCategories() async {
    try {
      final response = await http
          .get(
        Uri.parse(
          'https://eclcommerce.ernestchemists.com.gh/api/top-categories',
        ),
      )
          .timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final categories = data['data'];

          // Cache the categories
          CategoryCache.cacheCategories(categories);

          // Process categories and update state immediately
          _processCategories(categories);

          // Preload images in background without blocking UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _preloadCategoryImages(categories);
          });
        } else {
          throw Exception('Unable to load categories at this time');
        }
      } else {
        throw Exception('Unable to connect to the server');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('timeout')
              ? 'Connection timeout. Please check your internet connection.'
              : 'Unable to load categories. Please check your internet connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<dynamic>> _getAllProductsFromCategories({
    bool forceRefresh = false,
  }) async {
    // Check if we have cached products and don't need to force refresh
    if (CategoryCache.cachedAllProducts.isNotEmpty && !forceRefresh) {
      _allProducts = CategoryCache.cachedAllProducts;
      return _allProducts;
    }

    if (_isLoadingProducts) {
      return [];
    }

    setState(() {
      _isLoadingProducts = true;
    });

    List<dynamic> allProducts = [];

    try {
      // Use concurrent requests for better performance
      final futures = <Future<void>>[];

      for (var category in _categories) {
        futures.add(_fetchProductsForCategory(category, allProducts));
      }

      // Wait for all requests to complete with timeout
      await Future.wait(futures).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          // Continue with what we have
          return <void>[];
        },
      );

      // Cache the products
      CategoryCache.cacheAllProducts(allProducts);
      _allProducts = allProducts;
    } catch (e) {
      // Continue with other categories even if one fails
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }

    return allProducts;
  }

  Future<void> _fetchProductsForCategory(
      dynamic category, List<dynamic> allProducts) async {
    try {
      final subcategoriesResponse = await http
          .get(
            Uri.parse(
              'https://eclcommerce.ernestchemists.com.gh/api/categories/${category['id']}',
            ),
          )
          .timeout(Duration(seconds: 5));

      if (subcategoriesResponse.statusCode == 200) {
        final subcategoriesData = json.decode(subcategoriesResponse.body);
        if (subcategoriesData['success'] == true) {
          final subcategories = subcategoriesData['data'] as List;

          // Fetch products for all subcategories concurrently
          final futures = <Future<List<dynamic>>>[];

          for (final subcategory in subcategories) {
            futures.add(_fetchProductsForSubcategory(category, subcategory));
          }

          final productLists = await Future.wait(futures);
          for (final productList in productLists) {
            allProducts.addAll(productList);
          }
        }
      }
    } catch (e) {
      // Continue with other categories
    }
  }

  Future<List<dynamic>> _fetchProductsForSubcategory(
      dynamic category, dynamic subcategory) async {
    try {
      final subcategoryId = subcategory['id'];
      final subcategoryName = subcategory['name'];

      final apiUrl =
          'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId';

      final response =
          await http.get(Uri.parse(apiUrl)).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final products = data['data'] as List;

          return products
              .map((product) => {
                    ...product,
                    'category_id': category['id'],
                    'category_name': category['name'],
                    'subcategory_id': subcategoryId,
                    'subcategory_name': subcategoryName,
                  })
              .toList();
        }
      }
    } catch (e) {
      // Continue with other subcategories
    }
    return <dynamic>[];
  }

  void _showSearch(BuildContext context) async {
    // Check if we already have products cached
    if (CategoryCache.cachedAllProducts.isNotEmpty) {
      _showSearchWithProducts(context, CategoryCache.cachedAllProducts);
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

  Future<void> _performSearch(String query) async {
    setState(() {
      _showSearchDropdown = true;
      _searchResults = []; // Clear previous results while searching
    });

    // Search through products, not categories
    List<dynamic> productResults = [];

    // Use cached products if available, otherwise fetch only if query is long enough
    if (CategoryCache.cachedAllProducts.isNotEmpty) {
      // Search through cached products
      productResults = CategoryCache.cachedAllProducts.where((product) {
        final productName = product['name']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        final contains = productName.contains(searchQuery);
        return contains;
      }).toList();
    } else if (_allProducts.isNotEmpty) {
      // Search through already loaded products
      productResults = _allProducts.where((product) {
        final productName = product['name']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        final contains = productName.contains(searchQuery);
        return contains;
      }).toList();
    } else if (query.length >= 2) {
      // Only fetch all products if query is long enough and we don't have cached data
      await _getAllProductsFromCategories(forceRefresh: false);
      productResults = _allProducts.where((product) {
        final productName = product['name']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        final contains = productName.contains(searchQuery);
        return contains;
      }).toList();
    }

    setState(() {
      _searchResults = productResults
          .map(
            (prod) => {
              'type': 'product',
              'data': prod,
              'name': prod['name'],
              'id': prod['id'],
              'category_id': prod['category_id'],
              'category_name': prod['category_name'],
              'subcategory_id': prod['subcategory_id'],
              'subcategory_name': prod['subcategory_name'],
              'price': prod['price'],
              'thumbnail': prod['thumbnail'],
              'urlname': prod['urlname'],
            },
          )
          .toList();
    });
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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar with Dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          constraints: BoxConstraints(maxHeight: 300),
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
                              Expanded(
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
                                                    AlwaysStoppedAnimation<
                                                            Color>(
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
                                            padding: EdgeInsets.all(24),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.search_off,
                                                  size: 48,
                                                  color: Colors.grey.shade400,
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  'There is no product available currently',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: _searchResults.length,
                                            itemBuilder: (context, index) {
                                              final item =
                                                  _searchResults[index];
                                              return _buildSearchResultItem(
                                                  item);
                                            },
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
        ),
      ),
      bottomNavigationBar: CustomBottomNav(initialIndex: 2),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    return InkWell(
      onTap: () => _onSearchItemTap(item),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Product thumbnail
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item['thumbnail'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      Icon(Icons.broken_image),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Product content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'GHS ${_formatPrice(item['price'])}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item['category_name'] != null) ...[
                    SizedBox(height: 2),
                    Text(
                      item['category_name'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item['subcategory_name'] != null) ...[
                    SizedBox(height: 1),
                    Text(
                      '→ ${item['subcategory_name']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_isLoading) {
      return _buildShimmerGrid();
    }

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
            return CategoryGridItem(
              categoryName: category['name'],
              subcategories: _subcategoriesMap[category['id']] ?? [],
              hasSubcategories: category['has_subcategories'],
              imageUrl: _getCategoryImageUrl(category['image_url']),
              onTap: () {
                if (category['has_subcategories']) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubcategoryPage(
                        categoryName: category['name'],
                        categoryId: category['id'],
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductListPage(
                        categoryName: category['name'],
                        categoryId: category['id'],
                      ),
                    ),
                  );
                }
              },
              fontSize: screenWidth < 400 ? 13 : (screenWidth < 600 ? 14 : 15),
              imageRadius: 8,
              verticalSpacing: 4,
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
}

class CategoryGridItem extends StatefulWidget {
  final String categoryName;
  final List<dynamic> subcategories;
  final bool hasSubcategories;
  final VoidCallback onTap;
  final String imageUrl;
  final double fontSize;
  final double imageRadius;
  final double verticalSpacing;

  const CategoryGridItem({
    super.key,
    required this.categoryName,
    required this.hasSubcategories,
    required this.subcategories,
    required this.onTap,
    required this.imageUrl,
    this.fontSize = 15,
    this.imageRadius = 16,
    this.verticalSpacing = 4,
  });

  @override
  State<CategoryGridItem> createState() => _CategoryGridItemState();
}

class _CategoryGridItemState extends State<CategoryGridItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(widget.imageRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.imageRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.fill,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      maxWidthDiskCache: 300,
                      maxHeightDiskCache: 300,
                      fadeInDuration: Duration(milliseconds: 100),
                      fadeOutDuration: Duration(milliseconds: 100),
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
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
                            Colors.black.withAlpha((0.2 * 255).toInt()),
                          ],
                          stops: [0.7, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: widget.verticalSpacing),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              widget.categoryName,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
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

  // Cache for subcategories and products
  static Map<int, List<dynamic>> _subcategoriesCache = {};
  static Map<int, List<dynamic>> _productsCache = {};
  static Map<int, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
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
      final selectedSubcategory = subcategories.firstWhere(
        (sub) => sub['id'] == subcategoryId,
        orElse: () => {'name': 'Unknown', 'id': subcategoryId},
      );

      // Use the correct endpoint for products in a subcategory
      final apiUrl =
          'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId';

      final response =
          await http.get(Uri.parse(apiUrl)).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final allProducts = data['data'] as List;

          if (allProducts.isEmpty) {
            handleProductsError('There is no product available currently');
          } else {
            // Cache the products
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

      // Remove highlight after 8 seconds
      highlightTimer?.cancel();
      highlightTimer = Timer(Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            highlightedProductId = null;
          });
        }
      });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout based on screen width
        bool isTablet = constraints.maxWidth > 600;
        double sideNavWidth = isTablet ? 280 : constraints.maxWidth * 0.4;

        return Row(
          children: [
            SizedBox(
              width: sideNavWidth,
              child: buildSideNavigation(),
            ),
            Expanded(
              child: Container(
                color: Color(0xFFF8F9FA),
                child: Column(
                  children: [
                    if (selectedSubcategoryId != null) buildSubcategoryHeader(),
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
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
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
                                fontSize: 13,
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
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green.shade700,
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
    final selectedSubcategory = subcategories.firstWhere(
      (sub) => sub['id'] == selectedSubcategoryId,
      orElse: () => {'name': 'All Products', 'id': null},
    );

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
                  selectedSubcategory['name'] ?? 'All Products',
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
    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(16),
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
          child: ProductCard(
            product: product,
            onTap: () async {
              String? itemDetailURL = product['urlname'] ??
                  product['url'] ??
                  product['inventory']?['urlname'] ??
                  product['route']?.split('/').last;

              if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemPage(urlName: itemDetailURL!),
                  ),
                );
              } else {
                final productId = product['id']?.toString();
                if (productId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemPage(urlName: productId),
                    ),
                  );
                } else {
                  SnackBarUtils.showError(
                    context,
                    'Could not load product details',
                  );
                }
              }
            },
          ),
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

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                        imageUrl: product['thumbnail'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 120,
                        memCacheHeight: 120,
                        maxWidthDiskCache: 120,
                        maxHeightDiskCache: 120,
                        fadeInDuration: Duration(milliseconds: 100),
                        fadeOutDuration: Duration(milliseconds: 100),
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
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
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
                    product['name'] ?? 'Unknown Product',
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

  const ProductListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.searchedProductName,
    this.searchedProductId,
  });

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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            products = data['data'];
            isLoading = false;
          });

          // Highlight searched product if available
          if (widget.searchedProductId != null) {
            _highlightSearchedProduct();
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'There is no product available currently';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load products: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
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

      // Remove highlight after 8 seconds
      highlightTimer?.cancel();
      highlightTimer = Timer(Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            highlightedProductId = null;
          });
        }
      });
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
      return _buildLoadingState();
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
            child: ProductCard(
              product: product,
              onTap: () async {
                String? itemDetailURL = product['urlname'] ??
                    product['url'] ??
                    product['inventory']?['urlname'] ??
                    product['route']?.split('/').last;

                if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemPage(urlName: itemDetailURL!),
                    ),
                  );
                } else {
                  final productId = product['id']?.toString();
                  if (productId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemPage(urlName: productId),
                      ),
                    );
                  } else {
                    SnackBarUtils.showError(
                      context,
                      'Could not load product details',
                    );
                  }
                }
              },
            ),
          );
        },
      ),
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
                  builder: (context) => ItemPage(urlName: itemDetailURL!),
                ),
              );
            }
          },
        );
      },
    );
  }
}
