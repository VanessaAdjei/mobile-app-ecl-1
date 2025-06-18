// pages/search_results_page.dart
import 'package:flutter/material.dart';
import 'ProductModel.dart';
import 'itemdetail.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _filteredProducts!.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts![index];
                    return _ProductCard(product: product);
                  },
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth * (screenWidth < 600 ? 0.45 : 0.60);
    final cardHeight = screenHeight * (screenHeight < 800 ? 0.15 : 0.20);
    final imageHeight = cardHeight * (cardHeight < 800 ? 0.5 : 1);
    final fontSize = screenWidth * 0.032;
    final paddingValue = screenWidth * 0.02;

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: EdgeInsets.all(screenWidth * 0.019),
      decoration: BoxDecoration(
        color: Colors.white30,
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemPage(urlName: product.urlName),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: imageHeight,
              padding: EdgeInsets.all(paddingValue * 0.01),
              constraints: BoxConstraints(
                maxHeight: imageHeight,
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: product.thumbnail,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 30),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: paddingValue * 0.8,
                vertical: paddingValue * 0.3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: cardHeight < 600 ? 30 : 50,
                    child: Text(
                      product.name,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize * 1.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
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
