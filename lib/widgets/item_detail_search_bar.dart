import 'dart:async';

import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/cache/product_catalog_memory.dart';
import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/search_results_page.dart';
import 'package:eclapp/services/product_catalog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';

/// Product search on the item detail screen — typeahead + results navigation.
class ItemDetailSearchBar extends StatefulWidget {
  const ItemDetailSearchBar({
    super.key,
    this.padding,
    this.elevated = true,
    this.inHeader = false,
    this.autofocus = false,
    this.focusNode,
    this.onClose,
  });

  final EdgeInsetsGeometry? padding;
  final bool elevated;
  /// Compact field embedded in the green app bar toolbar.
  final bool inHeader;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onClose;

  @override
  State<ItemDetailSearchBar> createState() => _ItemDetailSearchBarState();
}

class _ItemDetailSearchBarState extends State<ItemDetailSearchBar> {
  static const Color _ink = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _greenTint = Color(0xFFEEF9F3);
  static const Color _greenBorder = Color(0xFFBBEAD3);

  final TextEditingController _controller = TextEditingController();
  final ProductCatalogService _catalogService = ProductCatalogService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Product> get _catalogProducts {
    if (ProductCache.hasProductsInMemory) {
      return ProductCache.cachedProducts;
    }
    if (ProductCatalogMemory.hasProducts) {
      return List<Product>.from(ProductCatalogMemory.products);
    }
    return const [];
  }

  void _openSearchResults(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SearchResultsPage(
          query: trimmed,
          products: _catalogProducts,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _controller.clear();
        setState(() {});
      }
    });
  }

  void _openProduct(Product product) {
    if (!mounted) return;
    final urlName = product.urlName.trim();
    if (urlName.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppRoutes.itemDetail,
      arguments: {
        'urlName': urlName,
        'isPrescribed': product.otcpom?.toLowerCase() == 'pom',
      },
    );
  }

  Future<List<Product>> _fetchSuggestions(String pattern) async {
    if (pattern.trim().isEmpty) return const [];
    try {
      final products = await _catalogService.searchForTypeahead(pattern);
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
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Widget _buildTypeAhead() {
    final inHeader = widget.inHeader;
    return TypeAheadField<Product>(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    autofocus: widget.autofocus,
                    style: GoogleFonts.poppins(
                      fontSize: inHeader ? 14 : 15,
                      color: inHeader ? Colors.white : _ink,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search products…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: inHeader ? 13 : 14,
                        color: inHeader
                            ? Colors.white.withValues(alpha: 0.65)
                            : _muted,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: inHeader,
                      fillColor: inHeader
                          ? Colors.white.withValues(alpha: 0.14)
                          : null,
                      border: inHeader
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            )
                          : InputBorder.none,
                      enabledBorder: inHeader
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            )
                          : InputBorder.none,
                      focusedBorder: inHeader
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            )
                          : InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: inHeader ? 8 : 10,
                        horizontal: inHeader ? 12 : 4,
                      ),
                      prefixIcon: inHeader
                          ? Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.85),
                            )
                          : null,
                      suffixIcon: inHeader || _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: inHeader
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : _muted.withValues(alpha: 0.9),
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() {});
                                widget.onClose?.call();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _openSearchResults,
                  ),
                  debounceDuration: const Duration(milliseconds: 280),
                  hideOnEmpty: true,
                  hideOnLoading: false,
                  suggestionsBoxVerticalOffset: 6,
                  suggestionsBoxDecoration: SuggestionsBoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    elevation: 8,
                    color: Colors.white,
                    shadowColor: Colors.black.withValues(alpha: 0.12),
                    constraints: const BoxConstraints(maxHeight: 280),
                  ),
                  suggestionsCallback: _fetchSuggestions,
                  itemBuilder: (context, suggestion) {
                    if (suggestion.name == '__VIEW_MORE__') {
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        title: Text(
                          'View all results',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    final imageUrl = ApiConfig.getProductImageUrl(
                      suggestion.thumbnail,
                    );

                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: _greenTint,
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.medical_services_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                )
                              : const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    Icons.medical_services_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        suggestion.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                      subtitle: Text(
                        'GHS ${suggestion.price}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  onSuggestionSelected: (suggestion) {
                    if (suggestion.name == '__VIEW_MORE__') {
                      _openSearchResults(_controller.text);
                    } else {
                      _openProduct(suggestion);
                    }
                  },
                  noItemsFoundBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No matches — try another keyword',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ),
                );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inHeader) {
      return _buildTypeAhead();
    }

    return Padding(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _greenTint.withValues(alpha: 0.65),
            ],
          ),
          border: Border.all(color: _greenBorder),
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildTypeAhead()),
            ],
          ),
        ),
      ),
    );
  }
}
