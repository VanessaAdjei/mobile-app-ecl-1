// pages/section_products_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../models/product_model.dart';
import '../utils/app_theme_colors.dart';
import '../utils/responsive_extension.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_header_bar.dart';
import '../utils/product_tap_guard.dart';
import '../widgets/product_card.dart';

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
  static const _pageSize = 18;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Product> _filteredProducts = [];
  String _sortOption = 'NameAsc';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  String _searchQuery = '';
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  static const _sortLabels = <String, String>{
    'PriceAsc': 'Price ↑',
    'PriceDesc': 'Price ↓',
    'NameAsc': 'A–Z',
    'NameDesc': 'Z–A',
  };

  @override
  void initState() {
    super.initState();
    _categories = ['All'];
    final uniqueCategories = widget.products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet();
    if (uniqueCategories.length > 1) {
      _categories.addAll(uniqueCategories);
    }
    _filterAndSort();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() {
        _searchQuery = next;
        _filterAndSort();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _gridColumns(BuildContext context) {
    if (context.isTabletLayout) return 3;
    return 2;
  }

  double _gridAspectRatio(BuildContext context) {
    if (context.isTabletLayout) return 1.08;
    return 1.02;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) return;
    _loadMoreProducts();
  }

  void _resetPagination() {
    _visibleCount = _pageSize;
    _isLoadingMore = false;
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || _visibleCount >= _filteredProducts.length) return;
    setState(() => _isLoadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(
        0,
        _filteredProducts.length,
      );
      _isLoadingMore = false;
    });
  }

  List<Product> get _visibleProducts =>
      _filteredProducts.take(_visibleCount).toList();

  bool get _hasMoreProducts => _visibleCount < _filteredProducts.length;

  void _openFilterSheet() {
    final theme = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
            child: Container(
            decoration: BoxDecoration(
              color: theme.sheetBg,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.rs(20)),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rs(12),
              context.rs(20),
              context.rs(20) + MediaQuery.paddingOf(sheetContext).bottom,
            ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Center(
                  child: Container(
                    width: context.rs(40),
                    height: context.rs(4),
                    decoration: BoxDecoration(
                      color: theme.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: context.rs(16)),
                Text(
                  'Filter & sort',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                  ),
                ),
                SizedBox(height: context.rs(4)),
                Text(
                  'Refine what you see in this section',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(12),
                    color: theme.muted,
                  ),
                ),
                SizedBox(height: context.rs(18)),
                _FilterSectionTitle(
                  icon: Icons.sort_rounded,
                  label: 'Sort by',
                ),
                SizedBox(height: context.rs(10)),
                Wrap(
                  spacing: context.rs(8),
                  runSpacing: context.rs(8),
                  children: _sortLabels.entries
                      .map(
                        (e) => _FilterChip(
                          label: e.value,
                          selected: _sortOption == e.key,
                          onTap: () => _applySort(e.key),
                        ),
                      )
                      .toList(),
                    ),
                    if (_categories.length > 1) ...[
                  SizedBox(height: context.rs(20)),
                  _FilterSectionTitle(
                    icon: Icons.category_outlined,
                    label: 'Category',
                  ),
                  SizedBox(height: context.rs(10)),
                      Wrap(
                    spacing: context.rs(8),
                    runSpacing: context.rs(8),
                        children: _categories
                        .map(
                          (cat) => _FilterChip(
                            label: cat,
                                  selected: _selectedCategory == cat,
                            onTap: () => _applyCategory(cat),
                          ),
                        )
                            .toList(),
                      ),
                    ],
                SizedBox(height: context.rs(24)),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: context.rs(14)),
                          shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(15),
                    ),
                  ),
                ),
              ],
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

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _sortOption = 'NameAsc';
      _selectedCategory = 'All';
      _filterAndSort();
    });
  }

  void _filterAndSort() {
    List<Product> filtered = List<Product>.from(widget.products);

    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final tokens = _searchQuery
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      filtered = filtered.where((product) {
        final haystack = [
          product.name,
          product.description,
          product.category,
        ].join(' ').toLowerCase();
        return tokens.every(haystack.contains);
      }).toList();
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
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'NameDesc':
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }

    _filteredProducts = filtered;
    _resetPagination();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != 'All' ||
      _sortOption != 'NameAsc';

  String _headerSubtitle(int total, int visible) {
    if (total == 0) return 'No matches';
    if (visible < total) {
      return 'Showing $visible of $total';
    }
    return '$total product${total == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final totalCount = _filteredProducts.length;
    final visibleProducts = _visibleProducts;
    final horizontalPad = ResponsiveUtils.pageHorizontalPadding(context);

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppHeaderBar.forScaffold(
        context,
        title: widget.sectionTitle,
        subtitle: _headerSubtitle(totalCount, visibleProducts.length),
        background: AppHeaderBackground.accent,
        showCart: true,
      ),
      body: ProductTapScrollScope(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  context.rs(14),
                  horizontalPad,
                  context.rs(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchField(
                      controller: _searchController,
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _filterAndSort();
                        });
                      },
                    ),
                    SizedBox(height: context.rs(12)),
                    _QuickSortRow(
                      sortOption: _sortOption,
                      sortLabels: _sortLabels,
                      hasActiveFilters: _hasActiveFilters,
                      onSortTap: _applySort,
                      onFilterTap: _openFilterSheet,
                      onClearTap: _clearFilters,
                    ),
                    if (_categories.length > 1) ...[
                      SizedBox(height: context.rs(10)),
                      SizedBox(
                        height: context.rs(34),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: context.rs(8)),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final selected = _selectedCategory == cat;
                            return FilterChip(
                              label: Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  fontSize: context.sp(11),
                                  fontWeight: FontWeight.w500,
                                  color: selected ? Colors.white : theme.ink,
                                ),
                              ),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: theme.surface,
                              side: BorderSide(
                                color:
                                    selected ? AppColors.primary : theme.border,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rs(4),
                              ),
                              onSelected: (_) => _applyCategory(cat),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (totalCount == 0)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptySectionState(
                  hasFilters: _hasActiveFilters,
                  onClear: _clearFilters,
                ),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  context.rs(4),
                  horizontalPad,
                  context.rs(8),
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridColumns(context),
                    crossAxisSpacing: context.rs(6),
                    mainAxisSpacing: context.rs(6),
                    childAspectRatio: _gridAspectRatio(context),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = visibleProducts[index];
                      return HomeProductCard(
                        key: ValueKey(
                            'section-${product.id}-${product.urlName}'),
                        product: product,
                        fontSize: context.sp(9),
                        compact: true,
                        showWishlistButton: true,
                        showHero: false,
                      );
                    },
                    childCount: visibleProducts.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PaginationFooter(
                  visibleCount: visibleProducts.length,
                  totalCount: totalCount,
                  isLoading: _isLoadingMore,
                  hasMore: _hasMoreProducts,
                  onLoadMore: _loadMoreProducts,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.visibleCount,
    required this.totalCount,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
  });

  final int visibleCount;
  final int totalCount;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        context.rs(8),
        context.rs(16),
        context.rs(24),
      ),
      child: Column(
        children: [
          Text(
            'Showing $visibleCount of $totalCount',
            style: GoogleFonts.poppins(
              fontSize: context.sp(11),
              color: theme.muted,
            ),
          ),
          if (hasMore) ...[
            SizedBox(height: context.rs(10)),
            if (isLoading)
              SizedBox(
                height: context.rs(28),
                width: context.rs(28),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: Icon(Icons.expand_more_rounded, size: context.rs(18)),
                label: Text(
                  'Load more',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rs(10)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rs(16),
                    vertical: context.rs(8),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.isNotEmpty;
        return DecoratedBox(
                        decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(context.rs(14)),
            border: Border.all(color: theme.border),
            boxShadow: theme.isDark
                ? null
                : [
                            BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: context.rs(10),
                      offset: Offset(0, context.rs(2)),
                            ),
                          ],
                        ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(
              fontSize: context.sp(14),
              color: theme.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Search in this section…',
              hintStyle: GoogleFonts.poppins(
                fontSize: context.sp(14),
                color: theme.muted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.muted,
                size: context.rs(22),
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.muted,
                        size: context.rs(20),
                      ),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: context.rs(12),
                horizontal: context.rs(4),
              ),
            ),
            textInputAction: TextInputAction.search,
                                                        ),
                                                      );
                                                    },
    );
  }
}

class _QuickSortRow extends StatelessWidget {
  const _QuickSortRow({
    required this.sortOption,
    required this.sortLabels,
    required this.hasActiveFilters,
    required this.onSortTap,
    required this.onFilterTap,
    required this.onClearTap,
  });

  final String sortOption;
  final Map<String, String> sortLabels;
  final bool hasActiveFilters;
  final ValueChanged<String> onSortTap;
  final VoidCallback onFilterTap;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: context.rs(34),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sortLabels.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rs(8)),
              itemBuilder: (context, index) {
                final entry = sortLabels.entries.elementAt(index);
                final selected = sortOption == entry.key;
                return ChoiceChip(
                  label: Text(
                    entry.value,
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : theme.ink,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: theme.surface,
                  side: BorderSide(
                    color: selected ? AppColors.primary : theme.border,
                  ),
                  onSelected: (_) => onSortTap(entry.key),
                );
              },
                                                    ),
                                                  ),
                                          ),
        SizedBox(width: context.rs(8)),
        Material(
          color: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rs(10)),
            side: BorderSide(color: theme.border),
          ),
          child: InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(context.rs(10)),
            child: Padding(
              padding: EdgeInsets.all(context.rs(8)),
              child: Icon(
                Icons.tune_rounded,
                size: context.rs(20),
                color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
        if (hasActiveFilters) ...[
          SizedBox(width: context.rs(6)),
          TextButton(
            onPressed: onClearTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: context.rs(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                                      ),
                                    ),
                                  ),
        ],
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Row(
                                        children: [
        Icon(icon, size: context.rs(18), color: AppColors.primary),
        SizedBox(width: context.rs(8)),
                                          Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: context.sp(14),
                                              fontWeight: FontWeight.w600,
            color: theme.ink,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Material(
      color: selected ? AppColors.primary : theme.fieldBg,
      borderRadius: BorderRadius.circular(context.rs(999)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.rs(999)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(14),
            vertical: context.rs(8),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rs(999)),
            border: Border.all(
              color: selected ? AppColors.primary : theme.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: context.sp(12),
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : theme.ink,
                              ),
                            ),
                          ),
                        ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({
    required this.hasFilters,
    required this.onClear,
  });

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    return Padding(
      padding: EdgeInsets.all(context.rs(32)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(context.rs(20)),
            decoration: BoxDecoration(
              color: theme.accentTint,
              shape: BoxShape.circle,
              border: Border.all(color: theme.accentBorder),
            ),
            child: Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: context.rs(40),
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: context.rs(18)),
          Text(
            hasFilters ? 'No matching products' : 'Nothing here yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: context.sp(17),
              fontWeight: FontWeight.w600,
              color: theme.ink,
            ),
          ),
          SizedBox(height: context.rs(8)),
          Text(
            hasFilters
                ? 'Try another keyword or reset your filters.'
                : 'This section has no products right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: context.sp(13),
              color: theme.muted,
              height: 1.45,
            ),
          ),
          if (hasFilters) ...[
            SizedBox(height: context.rs(20)),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Reset filters',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rs(12)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(18),
                  vertical: context.rs(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
