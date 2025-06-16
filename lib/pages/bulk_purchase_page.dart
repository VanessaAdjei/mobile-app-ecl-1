// pages/bulk_purchase_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'homepage.dart';
import 'cartprovider.dart';
import 'CartItem.dart';
import 'cart.dart';
import 'itemdetail.dart';
import 'bottomnav.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BulkPurchasePage extends StatefulWidget {
  const BulkPurchasePage({Key? key}) : super(key: key);

  @override
  State<BulkPurchasePage> createState() => _BulkPurchasePageState();
}

class _BulkPurchasePageState extends State<BulkPurchasePage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  String? selectedCategory = 'all';
  bool _isLoading = true;
  String? _error;

  String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return 'https://eclcommerce.ernestchemists.com.gh/storage/$imagePath';
  }

  final List<Map<String, dynamic>> categories = [
    {
      'id': 'all',
      'name': 'All',
      'icon': Icons.all_inclusive,
    },
    {
      'id': 'drugs',
      'name': 'Drugs',
      'icon': Icons.medication,
    },
    {
      'id': 'wellness',
      'name': 'Wellness',
      'icon': Icons.favorite,
    },
    {
      'id': 'selfcare',
      'name': 'Self Care',
      'icon': Icons.spa,
    },
    {
      'id': 'accessories',
      'name': 'Accessories',
      'icon': Icons.medical_services,
    },
  ];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];
        setState(() {
          products = dataList;
          filteredProducts = dataList;
          _isLoading = false;
        });
        print('Products loaded: ${products.length}'); // Debug print
      } else {
        setState(() {
          _error = 'Failed to load products';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading products: $e';
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    setState(() {
      if (_searchController.text.isEmpty && selectedCategory == null) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((product) {
          final name = product['product']['name']?.toLowerCase() ?? '';
          final matchesSearch = _searchController.text.isEmpty ||
              name.contains(_searchController.text.toLowerCase());

          if (selectedCategory == null || selectedCategory == 'all') {
            return matchesSearch;
          }

          final productData = product['product'];
          bool matchesCategory = false;

          switch (selectedCategory) {
            case 'drugs':
              matchesCategory =
                  (productData['otcpom']?.toString().toLowerCase() == 'otc' ||
                      productData['drug']?.toString().toLowerCase() == 'drug');
              break;
            case 'wellness':
              matchesCategory =
                  productData['wellness']?.toString().trim().isNotEmpty ??
                      false;
              break;
            case 'selfcare':
              matchesCategory =
                  productData['selfcare']?.toString().trim().isNotEmpty ??
                      false;
              break;
            case 'accessories':
              matchesCategory =
                  productData['accessories']?.toString().trim().isNotEmpty ??
                      false;
              break;
          }

          return matchesSearch && matchesCategory;
        }).toList();
      }
    });
  }

  void _addToCart(dynamic product) {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      print('Adding to cart: ${product['product']['name']}'); // Debug print

      final cartItem = CartItem(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        productId: product['product']['id'].toString(),
        name: product['product']['name'],
        price: double.tryParse(product['price'].toString()) ?? 0.0,
        quantity: 1,
        image: product['product']['thumbnail'] ??
            product['product']['image'] ??
            '',
        batchNo: product['batch_no'] ?? '',
        lastModified: DateTime.now(),
        urlName: product['product']['url_name'] ?? '',
        totalPrice: (double.tryParse(product['price'].toString()) ?? 0.0) * 1,
      );

      cartProvider.addToCart(cartItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['product']['name']} added to cart'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding to cart: $e'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Bulk Purchase',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green,
          elevation: 1,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Return to Retail Card
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomePage(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Return to Retail Purchase',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Categories
            Container(
              height: 80,
              margin: EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedCategory == category['id'];
                  return Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedCategory = category['id'];
                        });
                        _filterProducts();
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green[300]!
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              category['icon'],
                              color: isSelected
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            category['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _filterProducts();
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : filteredProducts.isEmpty
                          ? Center(child: Text('No products found'))
                          : GridView.builder(
                              padding: EdgeInsets.all(10),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.5,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 13,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                print(
                                    'Building product: ${product['product']['name']}'); // Debug print
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ItemPage(
                                          urlName: product['product']
                                              ['url_name'],
                                        
                                          isPrescribed: product['product']
                                                      ['otcpom']
                                                  ?.toString()
                                                  .toLowerCase() ==
                                              'pom',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      top: Radius.circular(16)),
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: Container(
                                                  color: Colors.grey[100],
                                                  child: CachedNetworkImage(
                                                    imageUrl: getImageUrl(
                                                        product['product']
                                                            ['thumbnail']),
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                    errorWidget: (_, __, ___) =>
                                                        Container(
                                                      color: Colors.grey[200],
                                                      child: Center(
                                                        child: Icon(
                                                            Icons.broken_image,
                                                            size: 30),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (product['product']['otcpom']
                                                    ?.toString()
                                                    .toLowerCase() ==
                                                'pom')
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red[600],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .medical_services_outlined,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Prescription',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['product']['name'] ??
                                                      'Unknown Product',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'GHS ${product['price']}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _addToCart(product);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green[700],
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .shopping_cart_outlined,
                                                          size: 16),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Add to Cart',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          initialIndex: 0,
        ),
      ),
    );
  }
}
