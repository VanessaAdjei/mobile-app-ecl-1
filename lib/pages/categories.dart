// pages/categories.dart
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

class Categories extends StatefulWidget {
  const Categories({super.key});

  @override
  _CategoriesState createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/categories'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _categories = data['categories'] ?? [];
            _isLoading = false;
          });
        } else {
          throw Exception(
              'Failed to load categories: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _buildCategoryCard(category);
                  },
                ),
    );
  }

  Widget _buildCategoryCard(dynamic category) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade500,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                category['name'] ?? 'Unknown Category',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  final bool isBulkPurchase;

  const CategoryPage({
    super.key,
    this.isBulkPurchase = false,
  });

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

  @override
  void initState() {
    super.initState();
    _fetchTopCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTopCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/top-categories'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _categories = data['data'];
              _filteredCategories = data['data'];
              _isLoading = false;
            });
          }
        } else {
          throw Exception('Unable to load categories at this time');
        }
      } else {
        throw Exception('Unable to connect to the server');
      }
    } catch (e) {
      print('Error fetching top categories: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to load categories. Please check your internet connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _searchProduct(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCategories = _categories;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((category) {
        return category['name'].toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  String _getCategoryImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return 'https://eclcommerce.ernestchemists.com.gh/storage/$imagePath';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
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
                      onChanged: _searchProduct,
                      decoration: InputDecoration(
                        hintText: "Search Categories...",
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
                  SizedBox(height: 4),
                  Text(
                    'Find your products by category',
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
      icon: Icons.wifi_off_rounded,
      title: 'Connection Issue',
    );
  }

  Widget _buildEmptyState() {
    return ErrorDisplay(
      errorMessage:
          'We couldn\'t find any categories matching your search. Please try a different search term.',
      icon: Icons.search_off_rounded,
      title: 'No Categories Found',
      iconColor: Colors.blue,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
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
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(widget.imageRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                    maxWidthDiskCache: 200,
                    maxHeightDiskCache: 200,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholderFadeInDuration:
                        const Duration(milliseconds: 150),
                    imageBuilder: (context, imageProvider) => Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                    ),
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
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
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 32,
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
                        stops: const [0.7, 1.0],
                      ),
                    ),
                  ),
                ],
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
      final response = await http
          .get(
            Uri.parse(
                'https://eclcommerce.ernestchemists.com.gh/api/categories/${widget.categoryId}'),
          )
          .timeout(const Duration(seconds: 15));

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

            if (mounted) {
              setState(() {
                subcategories = subcategoriesData;
                isLoading = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                errorMessage = 'No subcategories found for this category.';
                isLoading = false;
              });
            }
          }
        } else {
          throw Exception('Failed to load subcategories');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching subcategories: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load subcategories. Please try again.';
          isLoading = false;
        });
      }
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
      delegate: ProductSearchDelegate(products),
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
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                      child: Row(
                        children: [
                          if (isSelected)
                            Container(
                              width: 2,
                              height: 2,
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
        final itemDetailURL = product['inventory']?['urlname'] ??
            product['route']?.split('/').last;
        return ProductCard(
          product: product,
          onTap: () {
            if (itemDetailURL != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemPage(urlName: itemDetailURL),
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
            size: 80,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (selectedSubcategoryId != null) {
                onSubcategorySelected(selectedSubcategoryId!);
              } else {
                fetchSubcategories();
              }
            },
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: TextStyle(fontSize: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 24),
          Text(
            'No products available',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We couldn\'t find any products in this category',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.black,
            ),
            label: Text('Browse Categories'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              side: BorderSide(color: Colors.green.shade700),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
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

  ProductSearchDelegate(this.products);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
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
            SizedBox(height: 16),
            Text(
              'Search for products',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final filteredProducts = products.where((product) {
      return product['name']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();

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
            SizedBox(height: 16),
            Text(
              'No products found',
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

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            'In Stock',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
            ),
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: () {
            if (itemDetailURL != null) {
              close(context, '');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemPage(urlName: itemDetailURL),
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
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(products),
              );
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
          final itemDetailURL = product['inventory']?['urlname'] ??
              product['route']?.split('/').last;

          return ProductCard(
            product: product,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemPage(urlName: itemDetailURL),
              ),
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
