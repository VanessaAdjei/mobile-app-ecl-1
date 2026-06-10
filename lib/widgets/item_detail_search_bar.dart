import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/cache/product_catalog_memory.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/pages/search_results_page.dart';
import 'package:eclapp/widgets/safe_typeahead_host.dart';
import 'package:eclapp/widgets/typeahead_box_style.dart';
import 'package:eclapp/services/product_catalog_service.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:eclapp/utils/product_detail_navigation.dart';
import 'package:eclapp/widgets/item_detail/item_detail_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';

/// Product search on the item detail screen — same typeahead API as [HomePage].
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
  final TextEditingController _controller = TextEditingController();
  final ProductCatalogService _catalogService = ProductCatalogService();

  @override
  void deactivate() {
    widget.focusNode?.unfocus();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.focusNode?.unfocus();
    _controller.dispose();
    super.dispose();
  }

  List<Product> _catalogProductsForSearch() {
    if (ProductCache.hasProductsInMemory) {
      return ProductCache.cachedProducts;
    }
    if (ProductCatalogMemory.hasProducts) {
      return List<Product>.from(ProductCatalogMemory.products);
    }
    return const [];
  }

  Product _matchingCatalogProduct(Product suggestion) {
    return _catalogProductsForSearch().firstWhere(
      (p) => p.id == suggestion.id || p.name == suggestion.name,
      orElse: () => suggestion,
    );
  }

  static Product _typeaheadViewMoreRow() {
    return Product(
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
          products: _catalogProductsForSearch(),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _controller.clear();
      setState(() {});
    });
  }

  void _openProduct(Product suggestion) {
    if (!mounted) return;
    final matching = _matchingCatalogProduct(suggestion);
    final urlName = matching.urlName.isNotEmpty
        ? matching.urlName
        : suggestion.urlName.trim();
    if (urlName.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailNavigation.itemPage(
          urlName: urlName,
          product: matching,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _controller.clear();
      setState(() {});
    });
  }

  /// GET /api/search/{query} — same as home [SafeTypeAheadField].
  Future<List<Product>> _fetchSuggestions(String pattern) async {
    if (pattern.trim().isEmpty) return const [];
    try {
      final products = await _catalogService.searchForTypeahead(
        pattern,
        timeout: const Duration(seconds: 10),
      );
      if (products.length > 1) {
        return [_typeaheadViewMoreRow(), ...products.take(6)];
      }
      return products;
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Widget _buildSuggestionTile(Product suggestion) {
    final ink = context.appColors.ink;
    final accent = ItemDetailDesign.priceAccent(context);
    final imageWell = ItemDetailDesign.imageWell(context);

    if (suggestion.name == '__VIEW_MORE__') {
      return ListTile(
        dense: true,
        leading: Icon(
          Icons.list,
          color: accent,
          size: 22,
        ),
        title: Text(
          'View All Results',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accent,
            fontSize: 14,
          ),
        ),
      );
    }

    final matching = _matchingCatalogProduct(suggestion);
    final imageUrl = ApiConfig.getProductImageUrl(
      matching.thumbnail.isNotEmpty ? matching.thumbnail : suggestion.thumbnail,
    );

    return ListTile(
      dense: true,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                  fadeInDuration: const Duration(milliseconds: 100),
                  placeholder: (_, __) => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                )
              : ColoredBox(
                  color: imageWell,
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: accent,
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
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }

  Widget _buildTypeAhead() {
    final inHeader = widget.inHeader;
    final ink = context.appColors.ink;
    final muted = context.appColors.muted;
    final fieldBg = context.appColors.fieldBg;
    const boxStyle = TypeAheadBoxStyle(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      elevation: 8,
      verticalOffset: 6,
      constraints: BoxConstraints(maxHeight: 280),
    );

    return SafeTypeAheadHost<Product>(
      focusNode: widget.focusNode,
      builder: (context, suggestionsController) => TypeAheadField<Product>(
        controller: _controller,
        focusNode: widget.focusNode,
        suggestionsController: suggestionsController,
        offset: boxStyle.offset,
        constraints: boxStyle.constraints,
        decorationBuilder: boxStyle.decorationBuilder,
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: widget.autofocus,
            style: GoogleFonts.poppins(
              fontSize: inHeader ? 14 : 15,
              color: inHeader ? Colors.white : ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search medicines, products...',
              hintStyle: GoogleFonts.poppins(
                fontSize: inHeader ? 13 : 14,
                color: inHeader
                    ? Colors.white.withValues(alpha: 0.65)
                    : muted,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: inHeader
                  ? Colors.white.withValues(alpha: 0.14)
                  : fieldBg,
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
                            : muted.withValues(alpha: 0.9),
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
          );
        },
        debounceDuration: const Duration(milliseconds: 250),
        hideOnEmpty: true,
        hideOnLoading: false,
        suggestionsCallback: _fetchSuggestions,
        itemBuilder: (context, suggestion) => _buildSuggestionTile(suggestion),
        onSelected: (suggestion) {
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
            style: GoogleFonts.poppins(fontSize: 13, color: muted),
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

    final accent = ItemDetailDesign.priceAccent(context);

    return Padding(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: ItemDetailDesign.searchShellDecoration(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ItemDetailDesign.accentTint(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ItemDetailDesign.accentBorder(context),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: accent,
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
