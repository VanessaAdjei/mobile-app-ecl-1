// pages/categories.dart
// pages/categories.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'bottomnav.dart';
import 'homepage.dart';
import 'itemdetail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'AppBackButton.dart';
import 'bulk_purchase_page.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/settings.dart';
import 'package:eclapp/pages/purchases.dart';
import 'package:eclapp/pages/notifications.dart';
import 'package:eclapp/pages/prescription_history.dart';
import 'package:eclapp/pages/aboutus.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/pages/tandc.dart';
import 'package:eclapp/pages/addpayment.dart';
import 'package:eclapp/pages/changepassword.dart';
import 'package:eclapp/pages/forgot_password.dart';
import 'package:eclapp/pages/theme_provider.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/widgets/error_display.dart';

class CategoryPage extends StatefulWidget {
  final bool isBulkPurchase;

  const CategoryPage({
    Key? key,
    this.isBulkPurchase = false,
  }) : super(key: key);

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
  int? _highlightedCategoryId;
  int? _highlightedSubcategoryId;
  Timer? _highlightTimer;
  List<dynamic> _allProducts = [];
  bool _isLoadingProducts = false;
  bool _showSearchDropdown = false;
  List<dynamic> _searchResults = [];
  FocusNode _searchFocusNode = FocusNode();
  bool _isSearchLoading = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    print('🚀 CategoryPage initState called');
    _fetchTopCategories();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
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

  void _highlightCategory(int categoryId, int? subcategoryId) {
    setState(() {
      _highlightedCategoryId = categoryId;
      _highlightedSubcategoryId = subcategoryId;
    });

    // Automatically remove highlight after 5 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _highlightedCategoryId = null;
          _highlightedSubcategoryId = null;
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
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/top-categories'),
      );

      print('=== FETCH TOP CATEGORIES DEBUG ===');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded data: ${json.encode(data)}');

        if (data['success'] == true) {
          setState(() {
            _categories = data['data'];
            _filteredCategories = data['data'];
            _isLoading = false;
          });

          print('Number of categories loaded: ${_categories.length}');
          print('Categories:');
          for (var category in _categories) {
            print('- ${category['name']} (ID: ${category['id']})');
          }

          // Debug: Print the structure of the first category
          if (_categories.isNotEmpty) {
            print('First category structure:');
            print(json.encode(_categories.first));
          }
        } else {
          throw Exception('Unable to load categories at this time');
        }
      } else {
        throw Exception('Unable to connect to the server');
      }
      print('=== END FETCH TOP CATEGORIES DEBUG ===');
    } catch (e) {
      print('Error fetching top categories: $e');
      setState(() {
        _errorMessage =
            'Unable to load categories. Please check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _getAllProductsFromCategories(
      {bool forceRefresh = false}) async {
    print('=== GET ALL PRODUCTS DEBUG ===');
    print('Current _allProducts length: ${_allProducts.length}');
    print('Is loading products: $_isLoadingProducts');
    print('Force refresh: $forceRefresh');

    if (_allProducts.isNotEmpty && !forceRefresh) {
      print('Products already loaded, returning existing products');
      return _allProducts;
    }

    if (_isLoadingProducts) {
      print('Already loading products, returning empty list');
      return [];
    }

    setState(() {
      _isLoadingProducts = true;
    });

    List<dynamic> allProducts = [];

    try {
      print('=== FETCHING ALL PRODUCTS DEBUG ===');
      print('Number of categories to fetch from: ${_categories.length}');
      print('Categories to process:');
      for (var cat in _categories) {
        print('- ${cat['name']} (ID: ${cat['id']})');
      }

      // Fetch products from all categories and their subcategories
      for (var category in _categories) {
        try {
          print(
              '\n--- Processing main category: ${category['name']} (ID: ${category['id']}) ---');

          // First, get subcategories for this main category
          final subcategoriesResponse = await http.get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/categories/${category['id']}'),
          );

          if (subcategoriesResponse.statusCode == 200) {
            final subcategoriesData = json.decode(subcategoriesResponse.body);
            if (subcategoriesData['success'] == true) {
              final subcategories = subcategoriesData['data'] as List;
              print(
                  'Found ${subcategories.length} subcategories for ${category['name']}');

              // Fetch products from each subcategory
              for (var subcategory in subcategories) {
                try {
                  final subcategoryId = subcategory['id'];
                  final subcategoryName = subcategory['name'];
                  print(
                      'Fetching products for subcategory: $subcategoryName (ID: $subcategoryId)');

                  final apiUrl =
                      'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId';
                  print('API URL: $apiUrl');

                  final response = await http.get(Uri.parse(apiUrl));

                  print('Response status code: ${response.statusCode}');

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);

                    if (data['success'] == true && data['data'] != null) {
                      final products = data['data'] as List;
                      print(
                          'Number of products found for subcategory $subcategoryName: ${products.length}');

                      for (var product in products) {
                        allProducts.add({
                          ...product,
                          'category_id': category['id'],
                          'category_name': category['name'],
                          'subcategory_id': subcategoryId,
                          'subcategory_name': subcategoryName,
                        });
                      }
                    } else {
                      print(
                          'API returned success: false for subcategory $subcategoryName');
                    }
                  } else {
                    print(
                        'API request failed with status code: ${response.statusCode} for subcategory $subcategoryName');
                  }
                } catch (e) {
                  print(
                      'Error fetching products for subcategory ${subcategory['id']}: $e');
                  // Continue with other subcategories even if one fails
                }
              }
            } else {
              print(
                  'Failed to get subcategories for category ${category['name']}');
            }
          } else {
            print(
                'Failed to get subcategories for category ${category['name']}: ${subcategoriesResponse.statusCode}');
          }
        } catch (e) {
          print('Error processing category ${category['id']}: $e');
          // Continue with other categories even if one fails
        }
      }

      print('Total products collected: ${allProducts.length}');
      _allProducts = allProducts;
    } catch (e) {
      print('Error fetching all products: $e');
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }

    print('=== END FETCHING ALL PRODUCTS DEBUG ===');
    return allProducts;
  }

  void _showSearch(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        );
      },
    );

    // Fetch all products
    final products = await _getAllProductsFromCategories();

    // Hide loading indicator
    Navigator.of(context).pop();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No products available for search'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Show search
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
      print('Query is empty, clearing search results');
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
    print('🔍 PERFORMING SEARCH with query: "$query"');
    print('=== SEARCH DEBUG ===');
    print('Search query: "$query"');
    print('Query length: ${query.length}');
    print('Current _allProducts length: ${_allProducts.length}');

    print('Setting search dropdown to visible');
    setState(() {
      _showSearchDropdown = true;
      _searchResults = []; // Clear previous results while searching
    });

    // Search through products, not categories
    List<dynamic> productResults = [];

    // Only fetch all products if we don't have them cached and query is long enough
    if (_allProducts.isEmpty && query.length >= 2) {
      print('🔄 Fetching all products for comprehensive search...');
      await _getAllProductsFromCategories(
          forceRefresh: false); // Don't force refresh
      print('✅ Products fetched, total: ${_allProducts.length}');
    } else if (_allProducts.isNotEmpty) {
      print(
          '✅ Using cached products for search (${_allProducts.length} products)');
    }

    print('Total products available for search: ${_allProducts.length}');

    // Search through products
    productResults = _allProducts.where((product) {
      final productName = product['name']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      final contains = productName.contains(searchQuery);
      return contains;
    }).toList();

    print('Found ${productResults.length} matching products');

    setState(() {
      _searchResults = productResults
          .map((prod) => {
                'type': 'product',
                'data': prod,
                'name': prod['name'],
                'id': prod['id'],
                'category_name': prod['category_name'],
                'price': prod['price'],
                'thumbnail': prod['thumbnail'],
                'urlname': prod['urlname'],
              })
          .toList();
    });

    print('Search results set: ${_searchResults.length} items');
    print('Show dropdown: $_showSearchDropdown');
    print('=== END SEARCH DEBUG ===');
  }

  void _onSearchItemTap(dynamic item) {
    print('=== PRODUCT TAP DEBUG ===');
    print('Product tapped: ${json.encode(item)}');
    print('Product name: ${item['name']}');
    print('Product price: ${item['price']}');
    print('Product ID: ${item['id']}');
    print('Category ID: ${item['category_id']}');
    print('Category name: ${item['category_name']}');
    print('Data category ID: ${item['data']?['category_id']}');
    print('Data category name: ${item['data']?['category_name']}');

    setState(() {
      _showSearchDropdown = false;
      _searchController.clear();
    });

    // Navigate to the category page where this product belongs
    final categoryId = item['category_id'] ?? item['data']?['category_id'];
    final categoryName =
        item['category_name'] ?? item['data']?['category_name'];

    print('Resolved category ID: $categoryId');
    print('Resolved category name: $categoryName');

    if (categoryId != null && categoryName != null) {
      print('Navigating to category: $categoryName (ID: $categoryId)');

      // Check if the category has subcategories by looking at the original categories data
      final category = _categories.firstWhere(
        (cat) => cat['id'] == categoryId,
        orElse: () => {'has_subcategories': false},
      );

      if (category['has_subcategories'] == true) {
        print('Category has subcategories, navigating to SubcategoryPage');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubcategoryPage(
              categoryName: categoryName,
              categoryId: categoryId,
            ),
          ),
        );
      } else {
        print('Category has no subcategories, navigating to ProductListPage');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListPage(
              categoryName: categoryName,
              categoryId: categoryId,
            ),
          ),
        );
      }
    } else {
      print('ERROR: Could not determine category information');
      print('Available fields in item: ${item.keys.toList()}');
      print('Available fields in item data: ${item['data']?.keys.toList()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not navigate to category'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    print('=== END PRODUCT TAP DEBUG ===');
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
    print('=== BUILD DEBUG ===');
    print('_showSearchDropdown: $_showSearchDropdown');
    print('_searchResults.length: ${_searchResults.length}');
    print('_isLoadingProducts: $_isLoadingProducts');
    print('_allProducts.length: ${_allProducts.length}');
    print('=== END BUILD DEBUG ===');

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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
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
                                color: Colors.grey.shade400, fontSize: 13),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.green.shade700, size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
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
                                color: Colors.green.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Debug header
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search,
                                        size: 14, color: Colors.green.shade700),
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
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                              'No products found',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
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
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Categories Grid
            Expanded(
              child: _buildCategoriesGrid(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        initialIndex: 2,
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    return InkWell(
      onTap: () => _onSearchItemTap(item),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
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
                child: Image.network(
                  item['thumbnail'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
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
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
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
            crossAxisSpacing: 19,
            mainAxisSpacing: 1,
            childAspectRatio: 0.85,
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
    return ErrorDisplay(
      errorMessage: _errorMessage,
      onRetry: () {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
        _fetchTopCategories();
      },
      icon: Icons.error_outline,
      title: 'Connection Issue',
    );
  }

  Widget _buildEmptyState() {
    return ErrorDisplay(
      errorMessage: 'No products available',
      icon: Icons.shopping_bag_outlined,
      title: 'No Products Found',
      iconColor: Colors.grey.shade400,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.imageRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      maxWidthDiskCache: 300,
                      maxHeightDiskCache: 300,
                      fadeInDuration: Duration(milliseconds: 200),
                      placeholderFadeInDuration: Duration(milliseconds: 200),
                      imageBuilder: (context, imageProvider) => Image(
                        image: imageProvider,
                        fit: BoxFit.contain,
                      ),
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                            size: 36,
                          ),
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
                            Colors.black.withOpacity(0.2),
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

  const SubcategoryPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
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

  @override
  void initState() {
    super.initState();
    fetchSubcategories();
    setupScrollListener();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchSubcategories() async {
    try {
      print(
          'Fetching subcategories for main category ID: ${widget.categoryId}');
      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/categories/${widget.categoryId}'),
      );

      print('Subcategories API Response Status Code: ${response.statusCode}');
      print('Subcategories API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded Subcategories Response: ${json.encode(data)}');

        if (data['success'] == true) {
          final subcategoriesData = data['data'] as List;
          print('Number of subcategories: ${subcategoriesData.length}');
          if (subcategoriesData.isNotEmpty) {
            print(
                'First subcategory data: ${json.encode(subcategoriesData.first)}');
            // Print all subcategory IDs
            print('All subcategory IDs:');
            subcategoriesData.forEach((sub) {
              print('Subcategory: ${sub['name']}, ID: ${sub['id']}');
            });
          }
          handleSubcategoriesSuccess(data);
        } else {
          handleSubcategoriesError('Failed to load subcategories');
        }
      } else {
        handleSubcategoriesError(
            'Failed to load subcategories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchSubcategories: $e');
      handleSubcategoriesError('Error: ${e.toString()}');
    }
  }

  Future<void> onSubcategorySelected(int subcategoryId) async {
    setState(() {
      selectedSubcategoryId = subcategoryId;
      isLoading = true;
      products = [];
    });

    try {
      print('Fetching products for subcategory ID: $subcategoryId');
      print('Selected subcategory details:');
      final selectedSubcategory = subcategories.firstWhere(
        (sub) => sub['id'] == subcategoryId,
        orElse: () => {'name': 'Unknown', 'id': subcategoryId},
      );
      print('Name: ${selectedSubcategory['name']}');
      print('ID: ${selectedSubcategory['id']}');
      print(
          'Has product categories: ${selectedSubcategory['has_product_categories']}');

      // Use the correct endpoint for products in a subcategory
      final apiUrl =
          'https://eclcommerce.ernestchemists.com.gh/api/product-categories/$subcategoryId';
      print('Using API URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      print('Products API Response Status Code: ${response.statusCode}');
      print('Products API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded Products Response: ${json.encode(data)}');

        if (data['success'] == true) {
          final allProducts = data['data'] as List;
          print('Total products received: ${allProducts.length}');

          if (allProducts.isEmpty) {
            print(
                'No products found for subcategory: ${selectedSubcategory['name']}');
            handleProductsError('No products available in this category');
          } else {
            if (allProducts.isNotEmpty) {
              print('First product data: ${json.encode(allProducts.first)}');
            }
            handleProductsSuccess(data);
          }
        } else {
          print('API returned success: false');
          handleProductsError('No products available');
        }
      } else {
        print('API request failed with status code: ${response.statusCode}');
        handleProductsError('Failed to load products');
      }
    } catch (e, stackTrace) {
      print('Error in onSubcategorySelected: $e');
      print('Stack trace: $stackTrace');
      handleProductsError('Error: ${e.toString()}');
    }
  }

  void setupScrollListener() {
    scrollController.addListener(() {
      setState(() {
        showScrollToTop = scrollController.offset > 300;
      });
    });
  }

  void handleSubcategoriesSuccess(dynamic data) {
    setState(() {
      subcategories = data['data'];
      isLoading = false;
    });
    print('Subcategories loaded: ${json.encode(subcategories)}');

    if (subcategories.isNotEmpty) {
      final firstSubcategory = subcategories[0];
      print('First subcategory details:');
      print('Name: ${firstSubcategory['name']}');
      print('ID: ${firstSubcategory['id']}');
      print('All fields: ${json.encode(firstSubcategory)}');

      onSubcategorySelected(firstSubcategory['id']);
    }
  }

  void handleSubcategoriesError(String message) {
    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  void handleProductsSuccess(dynamic data) {
    setState(() {
      products = data['data'];
      isLoading = false;
    });

    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void handleProductsError(String message) {
    setState(() {
      isLoading = false;
      errorMessage = message;
    });
  }

  void sortProducts(String option) {
    setState(() {
      sortOption = option;

      switch (option) {
        case 'Price: Low to High':
          products.sort((a, b) {
            final double priceA =
                double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final double priceB =
                double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceA.compareTo(priceB);
          });
          break;
        case 'Price: High to Low':
          products.sort((a, b) {
            final double priceA =
                double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final double priceB =
                double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceB.compareTo(priceA);
          });
          break;
        case 'Popular':
          break;
        case 'Latest':
        default:
          break;
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
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearch(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              sortProducts(value);
            },
            offset: Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Latest',
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18,
                        color: sortOption == 'Latest'
                            ? Colors.green.shade700
                            : Colors.grey.shade800),
                    SizedBox(width: 12),
                    Text(
                      'Latest',
                      style: TextStyle(
                        color: sortOption == 'Latest'
                            ? Colors.green.shade700
                            : Colors.grey.shade800,
                        fontWeight: sortOption == 'Latest'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Price: Low to High',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward,
                        size: 18,
                        color: sortOption == 'Price: Low to High'
                            ? Colors.green.shade700
                            : Colors.grey.shade800),
                    SizedBox(width: 12),
                    Text(
                      'Price: Low to High',
                      style: TextStyle(
                        color: sortOption == 'Price: Low to High'
                            ? Colors.green.shade700
                            : Colors.grey.shade800,
                        fontWeight: sortOption == 'Price: Low to High'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Price: High to Low',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward,
                        size: 18,
                        color: sortOption == 'Price: High to Low'
                            ? Colors.green.shade700
                            : Colors.grey.shade800),
                    SizedBox(width: 12),
                    Text(
                      'Price: High to Low',
                      style: TextStyle(
                        color: sortOption == 'Price: High to Low'
                            ? Colors.green.shade700
                            : Colors.grey.shade800,
                        fontWeight: sortOption == 'Price: High to Low'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.sort, color: Colors.white, size: 24),
            ),
          ),
        ],
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

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        products: products,
        onCategorySelected: (categoryId, subcategoryId) {
          // Handle category selection if needed
        },
        currentCategoryName: widget.categoryName,
      ),
    );
  }

  Widget buildBody() {
    return Row(
      children: [
        buildSideNavigation(),
        Expanded(
          child: Container(
            color: Color(0xFFF8F9FA),
            child: Column(
              children: [
                if (selectedSubcategoryId != null) buildSubcategoryHeader(),
                Expanded(
                  child: _buildProductsContent(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSubcategoryHeader() {
    final selectedSubcategory = subcategories.firstWhere(
      (sub) => sub['id'] == selectedSubcategoryId,
      orElse: () => {'name': 'All Products', 'id': null},
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
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

  Widget buildSideNavigation() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.shade100,
                  width: 1,
                ),
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
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
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
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          if (isSelected)
                            Container(
                              width: 3,
                              height: 3,
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
        return ProductCard(
          product: product,
          onTap: () async {
            print('=== PRODUCT CARD TAP DEBUG ===');
            print('Product tapped: ${json.encode(product)}');
            print('Product name: ${product['name']}');
            print('Product price: ${product['price']}');
            print('Product inventory: ${product['inventory']}');
            print('Product route: ${product['route']}');
            print('Product ID: ${product['id']}');
            print('Product URL name: ${product['urlname']}');

            // Use urlname directly from product data
            String? itemDetailURL = product['urlname'] ??
                product['inventory']?['urlname'] ??
                product['route']?.split('/').last;

            print('Final item detail URL: $itemDetailURL');

            if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
              print('Navigating to product detail page...');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemPage(urlName: itemDetailURL!),
                ),
              );
            } else {
              print('ERROR: Could not determine item detail URL');
              print('Available fields in product: ${product.keys.toList()}');
              print(
                  'Available fields in product data: ${product['data']?.keys.toList()}');

              // Try using the product ID as a fallback
              final productId = product['id']?.toString();
              if (productId != null) {
                print('Trying to navigate using product ID: $productId');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemPage(urlName: productId),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not load product details'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            }
            print('=== END PRODUCT CARD TAP DEBUG ===');
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
    return ErrorDisplay(
      errorMessage: message,
      onRetry: () {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
        fetchSubcategories();
      },
      icon: Icons.error_outline,
      title: 'Connection Issue',
    );
  }

  Widget buildEmptyState() {
    return ErrorDisplay(
      errorMessage: 'No products available',
      icon: Icons.shopping_bag_outlined,
      title: 'No Products Found',
      iconColor: Colors.grey.shade400,
    );
  }
}

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        product['thumbnail'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                              size: 36,
                            ),
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
            return product['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase());
          }).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              currentCategoryName != null
                  ? 'Search in $currentCategoryName'
                  : 'Search all products',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
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
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found for "$query"',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final itemDetailURL = product['inventory']?['urlname'] ??
            product['route']?.split('/').last;
        final categoryId = product['category_id'];
        final subcategoryId = product['subcategory_id'];
        final categoryName = product['category_name'];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product['thumbnail'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          title: Text(
            product['name'] ?? 'Unknown Product',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GHS ${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 14,
                ),
              ),
              if (categoryName != null)
                Text(
                  'Category: $categoryName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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

class ProductListPage extends StatefulWidget {
  final String categoryName;
  final int categoryId;

  const ProductListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
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
            'https://eclcommerce.ernestchemists.com.gh/api/product-categories/${widget.categoryId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            products = data['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'No products available';
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

  void sortProducts(String option) {
    setState(() {
      sortOption = option;

      switch (option) {
        case 'Price: Low to High':
          products.sort((a, b) {
            final double priceA =
                double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final double priceB =
                double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceA.compareTo(priceB);
          });
          break;
        case 'Price: High to Low':
          products.sort((a, b) {
            final double priceA =
                double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final double priceB =
                double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return priceB.compareTo(priceA);
          });
          break;
      }
    });
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        products: products,
        onCategorySelected: (categoryId, subcategoryId) {
          // Handle category selection if needed
        },
        currentCategoryName: widget.categoryName,
      ),
    );
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
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearch(context);
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [],
          ),
          SizedBox(width: 8),
        ],
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
          Expanded(
            child: _buildProductsList(),
          ),
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
          return ProductCard(
            product: product,
            onTap: () async {
              print('=== PRODUCT CARD TAP DEBUG ===');
              print('Product tapped: ${json.encode(product)}');
              print('Product name: ${product['name']}');
              print('Product price: ${product['price']}');
              print('Product inventory: ${product['inventory']}');
              print('Product route: ${product['route']}');
              print('Product ID: ${product['id']}');
              print('Product URL name: ${product['urlname']}');

              // Use urlname directly from product data
              String? itemDetailURL = product['urlname'] ??
                  product['inventory']?['urlname'] ??
                  product['route']?.split('/').last;

              print('Final item detail URL: $itemDetailURL');

              if (itemDetailURL != null && itemDetailURL.isNotEmpty) {
                print('Navigating to product detail page...');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemPage(urlName: itemDetailURL!),
                  ),
                );
              } else {
                print('ERROR: Could not determine item detail URL');
                print('Available fields in product: ${product.keys.toList()}');
                print(
                    'Available fields in product data: ${product['data']?.keys.toList()}');

                // Try using the product ID as a fallback
                final productId = product['id']?.toString();
                if (productId != null) {
                  print('Trying to navigate using product ID: $productId');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemPage(urlName: productId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not load product details'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
              print('=== END PRODUCT CARD TAP DEBUG ===');
            },
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
    return ErrorDisplay(
      errorMessage: errorMessage,
      onRetry: () {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
        fetchProducts();
      },
      icon: Icons.error_outline,
      title: 'Connection Issue',
    );
  }

  Widget _buildEmptyState() {
    return ErrorDisplay(
      errorMessage: 'No products available',
      icon: Icons.shopping_bag_outlined,
      title: 'No Products Found',
      iconColor: Colors.grey.shade400,
    );
  }
}
