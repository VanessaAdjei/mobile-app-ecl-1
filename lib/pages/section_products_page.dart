// pages/section_products_page.dart
import 'package:flutter/material.dart';
import 'product_model.dart';
import 'app_back_button.dart';
import 'itemdetail.dart';
import 'homepage.dart';
import 'package:animations/animations.dart';

class SectionProductsPage extends StatefulWidget {
  final String sectionTitle;
  final List<Product> products;

  const SectionProductsPage({
    super.key,
    required this.sectionTitle,
    required this.products,
  });

  @override
  State<SectionProductsPage> createState() => _SectionProductsPageState();
}

class _SectionProductsPageState extends State<SectionProductsPage> {
  final int _tappedIndex = -1;
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Let the AppBackButton handle the navigation
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            backgroundColor: Colors.green.shade700,
            elevation: 0,
            centerTitle: true,
            leading: BackButtonUtils.simple(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              iconColor: Colors.white,
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
                const SizedBox(height: 2),
                Text(
                  '${products.length} products',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
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
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return OpenContainer(
                      transitionType: ContainerTransitionType.fadeThrough,
                      openColor: Theme.of(context).scaffoldBackgroundColor,
                      closedColor: Colors.transparent,
                      closedElevation: 0,
                      openElevation: 0,
                      transitionDuration: Duration(milliseconds: 200),
                      closedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      openBuilder: (context, _) => ItemPage(
                        urlName: product.urlName,
                        isPrescribed: product.otcpom?.toLowerCase() == 'pom',
                      ),
                      closedBuilder: (context, openContainer) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: openContainer,
                              child: Column(
                                children: [
                                  // Image Section
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                      ),
                                      child: Stack(
                                        children: [
                                          // Product Image
                                          Center(
                                            child: product.thumbnail.isNotEmpty
                                                ? Image.network(
                                                    product.thumbnail,
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(20),
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported_outlined,
                                                          color: Colors.grey,
                                                          size: 28,
                                                        ),
                                                      );
                                                    },
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
                                                      if (loadingProgress ==
                                                          null) {
                                                        return child;
                                                      }
                                                      return const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            Color(0xFF22C55E),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    child: const Icon(
                                                      Icons
                                                          .image_not_supported_outlined,
                                                      color: Colors.grey,
                                                      size: 28,
                                                    ),
                                                  ),
                                          ),
                                          // Prescribed medicine badge
                                          if (product.otcpom?.toLowerCase() ==
                                              'pom')
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[700],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                  ),
                                  // Content Section
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          // Product Name
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              height: 1.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          // Bottom Row
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Price
                                              Text(
                                                'GHS ${product.price}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[800],
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              // Empty space to maintain layout
                                              const SizedBox(width: 16),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
