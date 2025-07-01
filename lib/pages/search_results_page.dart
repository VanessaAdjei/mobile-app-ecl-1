// pages/search_results_page.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  void _performSearch() {
    if (_lastQuery == widget.query && _filteredProducts != null) {
      return; // Use cached result
    }

    final query = widget.query.toLowerCase();
    final filtered = widget.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _filteredProducts = filtered;
      _lastQuery = widget.query;
    });
  }

  @override
  Widget build(BuildContext context) {
    _performSearch(); // Ensure search is performed on build

    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results'),
        backgroundColor: Colors.green.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: _filteredProducts == null
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text('No products found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 6),
                      const Text('Try a different keyword.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _filteredProducts!.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts![index];
                    return GenericProductCard(
                      product: product,
                      showPrice: true,
                      showPrescriptionBadge: true,
                    );
                  },
                ),
    );
  }
}
