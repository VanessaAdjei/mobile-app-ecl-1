import 'package:flutter/material.dart';

class ProductPage extends StatelessWidget {
  final String category;
  final List<String> products;

  const ProductPage({super.key, required this.category, required this.products});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: Colors.green,
      ),
      body: products.isEmpty
          ? Center(
        child: Text(
          "No products available in this category",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )
          : Padding(
        padding: EdgeInsets.all(10),
        child: GridView.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        'https://via.placeholder.com/150',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      products[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                      child: Text("Add to Cart"),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
