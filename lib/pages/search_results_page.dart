// pages/search_results_page.dart
import 'package:flutter/material.dart';
import 'ProductModel.dart';
import 'itemdetail.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchResultsPage extends StatelessWidget {
  final String query;
  final List<Product> products;

  const SearchResultsPage({
    super.key,
    required this.query,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((product) {
      final q = query.toLowerCase();
      return product.name.toLowerCase().contains(q) ||
          (product.description.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results'),
        backgroundColor: Colors.green.shade700,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                  SizedBox(height: 12),
                  Text('No products found',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      )),
                  SizedBox(height: 6),
                  Text('Try a different keyword.',
                      style: TextStyle(color: Colors.grey[500])),
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
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final product = filtered[index];
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
    double cardWidth = screenWidth * (screenWidth < 600 ? 0.45 : 0.60);
    double cardHeight = screenHeight * (screenHeight < 800 ? 0.15 : 0.20);
    double imageHeight = cardHeight * (cardHeight < 800 ? 0.5 : 1);
    double fontSize = screenWidth * 0.032;
    double paddingValue = screenWidth * 0.02;

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
            offset: Offset(0, 1),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: product.thumbnail,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: Center(
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
