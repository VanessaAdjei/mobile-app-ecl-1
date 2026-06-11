import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../models/product_model.dart';
import '../../pages/search_results_page.dart';
import '../../services/product_catalog_service.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/product_detail_navigation.dart';
import '../safe_typeahead_field.dart';
import '../typeahead_box_style.dart';

/// Home screen product search — isolated from [CustomScrollView] sliver rebuilds.
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.isTablet,
    required this.catalogProducts,
  });

  final bool isTablet;
  final List<Product> catalogProducts;

  /// Height for [SliverPersistentHeader] — must fit padding + field (never clip).
  static double headerExtent({required bool isTablet}) {
    final top = isTablet ? 18.0 : 12.0;
    final field = isTablet ? 52.0 : 48.0;
    final bottom = isTablet ? 10.0 : 6.0;
    return top + field + bottom;
  }

  @override
  HomeSearchBarState createState() => HomeSearchBarState();
}

class HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final ProductCatalogService _catalogService = ProductCatalogService();

  void clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  Product _matchingProduct(Product suggestion) {
    return widget.catalogProducts.firstWhere(
      (p) => p.id == suggestion.id || p.name == suggestion.name,
      orElse: () => suggestion,
    );
  }

  void _openSearchResults(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SearchResultsPage(
          query: trimmed,
          products: widget.catalogProducts,
        ),
      ),
    ).then((_) {
      if (mounted) clear();
    });
  }

  void _openProduct(Product suggestion) {
    if (!mounted) return;
    final matching = _matchingProduct(suggestion);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailNavigation.itemPage(
          urlName: matching.urlName.isNotEmpty
              ? matching.urlName
              : suggestion.urlName,
          product: matching,
        ),
      ),
    ).then((_) {
      if (mounted) clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.isTablet;

    final fieldHeight = isTablet ? 52.0 : 48.0;
    final radius = isTablet ? 24.0 : 18.0;
    final theme = context.appColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        isTablet ? 18 : 12,
        isTablet ? 24 : 16,
        isTablet ? 10 : 6,
      ),
      child: Container(
        height: fieldHeight,
        decoration: BoxDecoration(
          color: theme.fieldBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return SafeTypeAheadField<Product>(
              controller: _controller,
              borderRadius: radius,
              fillColor: theme.fieldBg,
              suffixIconBuilder: (controller) => controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: controller.clear,
                    )
                  : null,
              onSubmitted: _openSearchResults,
              suggestionsCallback: (pattern) async {
                if (pattern.isEmpty || !mounted) return [];
                try {
                  final products = await _catalogService.searchForTypeahead(
                    pattern,
                    timeout: const Duration(seconds: 10),
                  );
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
                } on TimeoutException {
                  return [];
                } catch (_) {
                  return [];
                }
              },
              itemBuilder: (context, Product suggestion) {
                if (suggestion.name == '__VIEW_MORE__') {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Icon(Icons.list, color: Colors.green[700]),
                      title: Text(
                        'View All Results',
                        style: _poppins(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                final matching = _matchingProduct(suggestion);
                final imageUrl = ApiConfig.getProductImageUrl(
                  matching.thumbnail.isNotEmpty
                      ? matching.thumbnail
                      : suggestion.thumbnail,
                );
                final theme = context.appColors;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(color: theme.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () {
                      if (suggestion.name == '__VIEW_MORE__') {
                        _openSearchResults(_controller.text);
                      } else {
                        _openProduct(suggestion);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              fadeInDuration: const Duration(milliseconds: 100),
                              placeholder: (_, __) => const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.broken_image,
                                size: 20,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              onSuggestionSelected: (Product suggestion) {
                if (suggestion.name == '__VIEW_MORE__') {
                  _openSearchResults(_controller.text);
                } else {
                  _openProduct(suggestion);
                }
              },
              emptyBuilder: (context) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No products found',
                  style: TextStyle(color: context.appColors.muted),
                ),
              ),
              hideOnEmpty: true,
              hideOnLoading: false,
              debounceDuration: const Duration(milliseconds: 250),
              boxStyle: TypeAheadBoxStyle(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(isTablet ? 24 : 18),
                elevation: isTablet ? 15 : 10,
              ),
            );
          },
        ),
      ),
    );
  }
}
