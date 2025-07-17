// pages/section_products_page.dart
import 'package:flutter/material.dart';
import 'ProductModel.dart';
import '../services/homepage_optimization_service.dart';
import '../widgets/product_card.dart';
import 'AppBackButton.dart';
import 'itemdetail.dart';

class SectionProductsPage extends StatefulWidget {
  final String sectionTitle;
  final List<Product> products;

  const SectionProductsPage({
    Key? key,
    required this.sectionTitle,
    required this.products,
  }) : super(key: key);

  @override
  State<SectionProductsPage> createState() => _SectionProductsPageState();
}

class _SectionProductsPageState extends State<SectionProductsPage> {
  int _tappedIndex = -1;
  List<Product> _filteredProducts = [];
  String _sortOption = 'NameAsc';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _filteredProducts = List<Product>.from(widget.products);
    _categories = ['All'];
    final uniqueCategories = widget.products.map((p) => p.category).toSet();
    if (uniqueCategories.length > 1) {
      _categories.addAll(uniqueCategories.where((c) => c.isNotEmpty));
    }
    _filterAndSort();
  }

  void _openFilterSheet() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.grey, size: 26),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                    const Divider(height: 24, thickness: 1.2),
                    Row(
                      children: [
                        const Icon(Icons.sort, color: Color(0xFF22C55E)),
                        const SizedBox(width: 8),
                        const Text('Sort by',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Price: Low to High'),
                          selected: _sortOption == 'PriceAsc',
                          selectedColor: const Color(0xFF22C55E),
                          labelStyle: TextStyle(
                            color: _sortOption == 'PriceAsc'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: Colors.grey[100],
                          onSelected: (_) => _applySort('PriceAsc'),
                        ),
                        ChoiceChip(
                          label: const Text('Price: High to Low'),
                          selected: _sortOption == 'PriceDesc',
                          selectedColor: const Color(0xFF22C55E),
                          labelStyle: TextStyle(
                            color: _sortOption == 'PriceDesc'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: Colors.grey[100],
                          onSelected: (_) => _applySort('PriceDesc'),
                        ),
                        ChoiceChip(
                          label: const Text('Name: A-Z'),
                          selected: _sortOption == 'NameAsc',
                          selectedColor: const Color(0xFF22C55E),
                          labelStyle: TextStyle(
                            color: _sortOption == 'NameAsc'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: Colors.grey[100],
                          onSelected: (_) => _applySort('NameAsc'),
                        ),
                        ChoiceChip(
                          label: const Text('Name: Z-A'),
                          selected: _sortOption == 'NameDesc',
                          selectedColor: const Color(0xFF22C55E),
                          labelStyle: TextStyle(
                            color: _sortOption == 'NameDesc'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: Colors.grey[100],
                          onSelected: (_) => _applySort('NameDesc'),
                        ),
                      ],
                    ),
                    if (_categories.length > 1) ...[
                      const SizedBox(height: 22),
                      const Divider(height: 24, thickness: 1.2),
                      Row(
                        children: [
                          const Icon(Icons.category, color: Color(0xFF22C55E)),
                          const SizedBox(width: 8),
                          const Text('Category',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: _categories
                            .map((cat) => ChoiceChip(
                                  label: Text(cat),
                                  selected: _selectedCategory == cat,
                                  selectedColor: const Color(0xFF22C55E),
                                  labelStyle: TextStyle(
                                    color: _selectedCategory == cat
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  backgroundColor: Colors.grey[100],
                                  onSelected: (_) => _applyCategory(cat),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _applySort(String sort) {
    setState(() {
      _sortOption = sort;
      _filterAndSort();
    });
  }

  void _applyCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterAndSort();
    });
  }

  void _filterAndSort() {
    List<Product> filtered = widget.products;
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }
    switch (_sortOption) {
      case 'PriceAsc':
        filtered.sort((a, b) =>
            double.tryParse(a.price)
                ?.compareTo(double.tryParse(b.price) ?? 0) ??
            0);
        break;
      case 'PriceDesc':
        filtered.sort((a, b) =>
            double.tryParse(b.price)
                ?.compareTo(double.tryParse(a.price) ?? 0) ??
            0);
        break;
      case 'NameAsc':
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'NameDesc':
        filtered.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
    _filteredProducts = filtered;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.green.shade700,
          elevation: 0,
          centerTitle: true,
          leading: AppBackButton(
            backgroundColor: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.sectionTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF4ADE80), // Soft green accent
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_alt_rounded, color: Colors.white),
              tooltip: 'Filter',
              onPressed: _openFilterSheet,
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7FB), Color(0xFFE9ECF3)],
          ),
        ),
        child: products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No products found in this section.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return HomeProductCard(
                    product: product,
                    fontSize: 15,
                    imageHeight: 70,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemPage(
                            urlName: product.urlName,
                            isPrescribed:
                                product.otcpom?.toLowerCase() == 'pom',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
