// pages/search_results_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'ProductModel.dart';
import 'itemdetail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/product_card.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;
  final List<Product> products;

  const SearchResultsPage({
    super.key,
    required this.query,
    required this.products,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<Product>? _filteredProducts;
  String? _lastQuery;
  String _searchText = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All',
    'Drugs',
    'Wellness',
    'Selfcare',
    'Accessories'
  ];
  Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  void _performSearch() {
    final query =
        (_searchText.isEmpty ? widget.query : _searchText).toLowerCase();
    List<Product> filtered = widget.products.where((product) {
      final matchesQuery = product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All' ||
          (product.category.toLowerCase() == _selectedCategory.toLowerCase() ||
              (product.otcpom?.toLowerCase() ==
                  _selectedCategory.toLowerCase()) ||
              (product.drug?.toLowerCase() ==
                  _selectedCategory.toLowerCase()) ||
              (product.wellness?.toLowerCase() ==
                  _selectedCategory.toLowerCase()) ||
              (product.selfcare?.toLowerCase() ==
                  _selectedCategory.toLowerCase()) ||
              (product.accessories?.toLowerCase() ==
                  _selectedCategory.toLowerCase()));
      return matchesQuery && matchesCategory;
    }).toList();
    setState(() {
      _filteredProducts = filtered;
      _lastQuery = widget.query;
    });
  }

  @override
  Widget build(BuildContext context) {
    _performSearch(); // Ensure search is performed on build

    final isLoading = _filteredProducts == null;
    final isEmpty = _filteredProducts?.isEmpty ?? false;
    final resultCount = _filteredProducts?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.green[700]),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Results for',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '"${widget.query}"',
                                style: GoogleFonts.poppins(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (!isLoading)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$resultCount found',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 70, color: Colors.grey[400]),
                      const SizedBox(height: 18),
                      Text('No products found',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      Text('Try a different keyword.',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 14,
                          )),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        label: Text('Back',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(
                      left: 30.0), // Increased left padding
                  child: Column(
                    children: [
                      // Animated search bar (bigger)
                      AnimatedContainer(
                        duration: Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20), // Increased vertical padding
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(32), // More pill-like
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.10), // More prominent shadow
                              blurRadius: 18,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                color: Colors.grey[500], size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500), // Larger font
                                decoration: InputDecoration(
                                  hintText: 'Refine search...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchText = val;
                                  });
                                },
                                onSubmitted: (_) => _performSearch(),
                                textInputAction: TextInputAction.search,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchText = '';
                                  });
                                },
                                child: Icon(Icons.close,
                                    color: Colors.grey[400], size: 26),
                              ),
                          ],
                        ),
                      ),
                      // (Filter chips row removed)
                      // Results grid
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 0,
                            mainAxisSpacing: 0,
                            childAspectRatio: 1,
                          ),
                          itemCount: _filteredProducts!.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts![index];
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration:
                                  Duration(milliseconds: 350 + index * 40),
                              curve: Curves.easeIn,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ItemPage(
                                        urlName: product.urlName,
                                        isPrescribed:
                                            product.otcpom?.toLowerCase() ==
                                                'pom',
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    GenericProductCard(
                                      product: product,
                                      showPrice: true,
                                      showPrescriptionBadge: true,
                                      // Remove or minimize internal padding if supported
                                      padding: 0,
                                    ),
                                    // Badge for prescribed
                                    if (product.otcpom?.toLowerCase() == 'pom')
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red[700],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Prescribed',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                ),
    );
  }
}
