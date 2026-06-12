import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/services/product_image_preload_service.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:eclapp/utils/product_detail_navigation.dart';
import 'package:flutter/material.dart';

/// Bento popular products — large hero + two stacked cards per page.
/// Order is shuffled daily; hero slot rotates on each swipe page.
class HomePopularProductsFeatured extends StatefulWidget {
  const HomePopularProductsFeatured({
    super.key,
    required this.products,
    this.isTablet = false,
  });

  final List<Product> products;
  final bool isTablet;

  @override
  State<HomePopularProductsFeatured> createState() =>
      _HomePopularProductsFeaturedState();
}

class _HomePopularProductsFeaturedState
    extends State<HomePopularProductsFeatured> {
  static const int _productsPerPage = 3;

  final PageController _pageController = PageController(viewportFraction: 1);
  int _pageIndex = 0;

  double get _horizontalPadding => widget.isTablet ? 20 : 14;
  double get _bentoHeight => widget.isTablet ? 188 : 158;
  double get _pageGap => 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<List<Product>> _bentoPages(List<Product> eligible) {
    final shuffled = _dailyShuffled(eligible);
    final pages = <List<Product>>[];
    for (var i = 0; i < shuffled.length; i += _productsPerPage) {
      final end = (i + _productsPerPage).clamp(0, shuffled.length);
      final chunk = shuffled.sublist(i, end);
      pages.add(_rotateChunkForHero(chunk, pages.length));
    }
    return pages;
  }

  /// Stable shuffle for the day so spotlight order rotates fairly.
  List<Product> _dailyShuffled(List<Product> products) {
    if (products.length <= 1) return products;
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final list = List<Product>.from(products);
    list.shuffle(Random(seed));
    return list;
  }

  /// Rotate each page so a different product gets the large hero card.
  List<Product> _rotateChunkForHero(List<Product> chunk, int pageIndex) {
    if (chunk.length <= 1) return chunk;
    final offset = pageIndex % chunk.length;
    return [
      for (var i = 0; i < chunk.length; i++)
        chunk[(offset + i) % chunk.length],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final eligible = ProductCache.withoutPrescriptionProducts(widget.products);
    if (eligible.isEmpty) return const SizedBox.shrink();

    final pages = _bentoPages(eligible);
    final theme = context.appColors;
    final isDark = theme.isDark;

    return Padding(
      padding: EdgeInsets.fromLTRB(_horizontalPadding, 0, _horizontalPadding, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF151D2B), Color(0xFF0F1623)]
                : const [Color(0xFFF4FAF6), Color(0xFFFFFFFF)],
          ),
          border: Border.all(
            color: isDark
                ? AppColors.primaryLight.withValues(alpha: 0.18)
                : AppColors.primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryLight, AppColors.primaryDark],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trending picks',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: widget.isTablet ? 13 : 12,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.local_mall_outlined,
                    size: 15,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _bentoHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, pageIndex) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: _BentoSpotlightPage(
                      products: pages[pageIndex],
                      isTablet: widget.isTablet,
                      gap: _pageGap,
                    ),
                  );
                },
              ),
            ),
            if (pages.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  final active = index == _pageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 12 : 4,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: active
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _BentoSpotlightPage extends StatelessWidget {
  const _BentoSpotlightPage({
    required this.products,
    required this.isTablet,
    required this.gap,
  });

  final List<Product> products;
  final bool isTablet;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (products.length == 1) {
      return _BentoHeroCard(
        product: products.first,
        isTablet: isTablet,
      );
    }

    if (products.length == 2) {
      return Column(
        children: [
          Expanded(
            child: _BentoHeroCard(
              product: products[0],
              isTablet: isTablet,
            ),
          ),
          SizedBox(height: gap),
          Expanded(
            child: _BentoSideCard(
              product: products[1],
              isTablet: isTablet,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _BentoHeroCard(
            product: products[0],
            isTablet: isTablet,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 9,
          child: Column(
            children: [
              Expanded(
                child: _BentoSideCard(
                  product: products[1],
                  isTablet: isTablet,
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: _BentoSideCard(
                  product: products[2],
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BentoHeroCard extends StatelessWidget {
  const _BentoHeroCard({
    required this.product,
    required this.isTablet,
  });

  final Product product;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return _BentoProductTile(
      product: product,
      isTablet: isTablet,
      layout: _BentoTileLayout.hero,
    );
  }
}

class _BentoSideCard extends StatelessWidget {
  const _BentoSideCard({
    required this.product,
    required this.isTablet,
  });

  final Product product;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return _BentoProductTile(
      product: product,
      isTablet: isTablet,
      layout: _BentoTileLayout.side,
    );
  }
}

enum _BentoTileLayout { hero, side }

class _BentoProductTile extends StatelessWidget {
  const _BentoProductTile({
    required this.product,
    required this.isTablet,
    required this.layout,
  });

  final Product product;
  final bool isTablet;
  final _BentoTileLayout layout;

  String get _priceLabel {
    final parsed = double.tryParse(product.price);
    if (parsed == null) return 'View details';
    return 'GH₵ ${parsed.toStringAsFixed(2)}';
  }

  void _open(BuildContext context) {
    ProductDetailNavigation.pushNamed(
      context,
      urlName: product.urlName,
      product: product,
      fromProductCard: true,
    );
  }

  Widget _productImage(BuildContext context, {BoxFit fit = BoxFit.contain}) {
    final theme = context.appColors;
    final imageUrl = ProductImagePreloadService.imageUrlFor(product);

    return ColoredBox(
      color: theme.fieldBg,
      child: imageUrl.isEmpty
          ? Center(
              child: Icon(
                Icons.medical_services_outlined,
                color: theme.muted,
                size: layout == _BentoTileLayout.hero ? 22 : 16,
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              cacheManager: ProductImagePreloadService.cacheManager,
              fit: fit,
              memCacheWidth: ProductImagePreloadService.homeThumbDiskSize,
              memCacheHeight: ProductImagePreloadService.homeThumbDiskSize,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final isDark = theme.isDark;
    final radius = layout == _BentoTileLayout.hero ? 10.0 : 9.0;

    if (layout == _BentoTileLayout.side) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _open(context),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2332) : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: theme.border),
            ),
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _productImage(context),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isTablet ? 9.5 : 9,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _priceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: isTablet ? 9 : 8.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.primaryDark,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () => _open(context),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _productImage(context),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Popular',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isTablet ? 10 : 9.5,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isTablet ? 9.5 : 9,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primaryDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
