// pages/homepage.dart
import 'dart:math';
import 'package:eclapp/pages/signinpage.dart';
import 'package:eclapp/pages/storelocation.dart';
import 'package:eclapp/pages/categories.dart';
import 'package:eclapp/pages/pharmacists.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eclapp/pages/cart.dart';
import 'ProductModel.dart';
import 'auth_service.dart';
import 'bottomnav.dart';
import 'clickableimage.dart';
import 'itemdetail.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_results_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/splashscreen.dart';
import 'package:provider/provider.dart';
import '../widgets/cart_icon_button.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isLoadingPopular = true;
  String? _error;
  String? _popularError;
  List<Product> _products = [];
  List<Product> filteredProducts = [];
  List<Product> popularProducts = [];
  final RefreshController _refreshController = RefreshController();
  bool _allContentLoaded = false;
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

  _launchPhoneDialer(String phoneNumber) async {
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus.isGranted) {
      final String formattedPhoneNumber = 'tel:$phoneNumber';
      print("Dialing number: $formattedPhoneNumber");
      if (await canLaunch(formattedPhoneNumber)) {
        await launch(formattedPhoneNumber);
      } else {
        print("Error: Could not open the dialer.");
      }
    } else {
      print("Permission denied.");
    }
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
      print("Phone number or message is empty");
      return;
    }

    if (!phoneNumber.startsWith('+')) {
      print("Phone number must include the country code (e.g., +233*******)");
      return;
    }

    String whatsappUrl =
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';

    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      print("WhatsApp is not installed or cannot be launched.");
      showTopSnackBar(
          context, 'Could not open WhatsApp. Please ensure it is installed.');
    }
  }

  Future<void> _loadAllContent() async {
    setState(() => _allContentLoaded = false);
    try {
      // Load products first, then popular products
      await loadProducts();
      // Load popular products in background
      _fetchPopularProducts();
    } catch (e) {
      // Handle error without cache fallback
      print('Error loading content: $e');
    } finally {
      if (mounted) {
        setState(() => _allContentLoaded = true);
      }
    }
  }

  Future<void> loadProducts() async {
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
            _products = allProducts;
            filteredProducts = allProducts;
            drugsSectionProducts = otcDrugProducts;
            wellnessProducts = wellnessList;
            selfcareProducts = selfcareList;
            accessoriesProducts = accessoriesList;
            _isLoading = false;
          });
        }
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

  Future<void> _fetchPopularProducts() async {
    if (!mounted) return;
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
        setState(() {
          popularProducts = productsData.map<Product>((item) {
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
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.call, color: Colors.green),
                title: Text('Call'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchPhoneDialer(phoneNumber);
                  makePhoneCall(phoneNumber);
                },
              ),
              ListTile(
                leading:
                    FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                title: Text('WhatsApp'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchWhatsApp(
                      phoneNumber, "Hello, I'm interested in your products!");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAllContent();
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
  void dispose() {
    searchController.dispose();
    super.dispose();
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
          print(
              'Search suggestion: \\${suggestion.name}, thumbnail: \\${suggestion.thumbnail}, used thumbnail: \\${matchingProduct.thumbnail}, imageUrl: \\${imageUrl}');
          return ListTile(
            leading: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
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
          print('Navigating to item page with urlName: $urlName');
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          SizedBox(width: 12),
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
          SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.contact_support_rounded,
              title: "Contact Us",
              color: Colors.orange[600]!,
              onTap: () => _showContactOptions("+233504518047"),
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

  Widget _buildPopularProducts() {
    if (_isLoadingPopular) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_popularError != null) {
      return ErrorDisplayWidget(
        onRetry: () {
          setState(() {
            _popularError = null;
          });
          _fetchPopularProducts();
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
        _getLimitedProducts(popularProducts, limit: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCapsuleHeading('Popular Products', Colors.green[700]!),
        SingleChildScrollView(
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
                          height: 90,
                          width: 80,
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
        Divider(
          color: Colors.grey.shade300,
          thickness: 2.0,
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
      children: [
        // Card is only the image (square) - more compact
        Container(
          width: cardWidth,
          margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.008, vertical: 0),
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
        SizedBox(
          width: cardWidth,
          child: Column(
            children: [
              const SizedBox(height: 1),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize * 0.95,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'GHS ${product.price}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize * 0.95,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with See More button on same row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
          padding: EdgeInsets.symmetric(horizontal: 8),
          itemCount: products.length > 6 ? 6 : products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            mainAxisSpacing: 2,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            return _buildProductCard(
              products[index],
              fontSize: fontSize * 0.95,
              padding: padding * 0.8,
              imageHeight: imageHeight * 0.85,
            );
          },
        ),
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
              onRefresh: loadProducts,
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
                  // Bulk Purchase Card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) => _buildProductSkeleton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Container(
                  width: 150,
                  height: 24,
                  color: Colors.white,
                ),
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
                      decoration: BoxDecoration(
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
    _pageController = PageController(viewportFraction: 0.85);
    fetchBanners();
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

  Future<void> fetchBanners() async {
    if (!mounted) return;
    setState(() => _isLoadingBanners = true);
    try {
      final response = await http
          .get(
            Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/banner'),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List bannersData = data['data'] ?? [];
        if (mounted) {
          setState(() {
            banners = bannersData
                .map<BannerModel>((item) => BannerModel.fromJson(item))
                .toList();
          });
        }
      } else {
        throw Exception('Server error');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    } on http.ClientException {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBanners = false);
      }
    }
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
        height: 150,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }
    if (banners.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text(
          'No banners available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return Container(
      height: 150,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: PageView.builder(
        controller: _pageController,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = banner.img.startsWith('http')
              ? banner.img
              : 'https://eclcommerce.ernestchemists.com.gh/storage/banners/${Uri.encodeComponent(banner.img)}';
          print('Banner image URL: ' + imageUrl);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  cacheHeight: 300,
                  cacheWidth:
                      (MediaQuery.of(context).size.width * 0.85).round(),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.broken_image, size: 40),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String getProductImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    print('Empty or null URL provided');
    return '';
  }

  // If it's already a full URL, return it
  if (url.startsWith('http')) {
    print('Full URL provided: $url');
    return url;
  }

  // Use the correct path 'product' (singular) instead of 'products'
  final finalUrl =
      'https://adm-ecommerce.ernestchemists.com.gh/uploads/product/$url';
  print('Original URL: $url');
  print('Final URL: $finalUrl');
  return finalUrl;
}

class BannerModel {
  final int id;
  final String img;
  final String? urlName;

  BannerModel({required this.id, required this.img, this.urlName});

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      img: json['img'],
      urlName: json['inventory']?['url_name'],
    );
  }
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
