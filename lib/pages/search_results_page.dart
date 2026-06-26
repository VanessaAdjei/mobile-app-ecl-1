// pages/search_results_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/product_model.dart';
import '../utils/app_theme_colors.dart';
import '../utils/product_detail_navigation.dart';
import '../utils/product_tap_guard.dart';
import '../widgets/product_card.dart';
import '../widgets/app_header_bar.dart';

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
  String _searchText = '';
  final String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query =
        (_searchText.isEmpty ? widget.query : _searchText).toLowerCase().trim();
    final tokens =
        query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    List<Product> filtered = widget.products.where((product) {
      final haystack = [
        product.name,
        product.description,
        product.category,
      ].join(' ').toLowerCase();
      // Match when every typed word appears somewhere in the product text.
      final matchesQuery = tokens.isEmpty || tokens.every(haystack.contains);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final isLoading = _filteredProducts == null;
    final isEmpty = _filteredProducts?.isEmpty ?? false;
    final resultCount = _filteredProducts?.length ?? 0;

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppHeaderBar.forScaffold(
        context,
        title: 'Results for "${widget.query}"',
        subtitle: isLoading ? null : '$resultCount found',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 70, color: theme.muted),
                      const SizedBox(height: 18),
                      Text("Sorry, we couldn't find your product.",
                          style: GoogleFonts.poppins(
                            color: theme.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
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
                      // animated search bar (bigger)
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
                              color: Colors.black.withValues(
                                  alpha: 0.10), // More prominent shadow
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
                                  _searchText = val;
                                  _performSearch();
                                },
                                onSubmitted: (_) => _performSearch(),
                                textInputAction: TextInputAction.search,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _searchText = '';
                                  _performSearch();
                                },
                                child: Icon(Icons.close,
                                    color: Colors.grey[400], size: 26),
                              ),
                          ],
                        ),
                      ),
                      // (filter chips row removed)
                      // results grid
                      Expanded(
                        child: ProductTapScrollScope(
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
                                    ProductDetailNavigation.push(
                                      context,
                                      urlName: product.urlName,
                                      product: product,
                                      fromProductCard: true,
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
                                      // badge showing if its prescribed
                                      if (product.otcpom?.toLowerCase() ==
                                          'pom')
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
                                              'Prescription',
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
                      ),
                    ],
                  ),
                ),
    );
  }
}
