import 'dart:async';

import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/widgets/product_card.dart';
import 'package:flutter/material.dart';

/// Horizontal popular-products row — scroll updates stay local (no full home rebuild).
class HomePopularProductsStrip extends StatefulWidget {
  const HomePopularProductsStrip({
    super.key,
    required this.products,
    this.isTablet = false,
  });

  final List<Product> products;
  final bool isTablet;

  @override
  State<HomePopularProductsStrip> createState() =>
      _HomePopularProductsStripState();
}

class _HomePopularProductsStripState extends State<HomePopularProductsStrip> {
  static const double _cardSpacing = 12;
  static const double _centerScale = 1.1;
  static const double _sideScale = 0.98;

  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  double get _cardWidth => widget.isTablet ? 132 : 112;
  double get _stripHeight => widget.isTablet ? 168 : 148;
  double get _itemStride => _cardWidth + _cardSpacing;
  double get _imageHeight => widget.isTablet ? 128 : 108;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void didUpdateWidget(HomePopularProductsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.isEmpty && widget.products.isNotEmpty) {
      _startAutoScroll();
    }
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  void _startAutoScroll() {
    if (widget.products.isEmpty || !mounted) return;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || widget.products.isEmpty) {
        timer.cancel();
        return;
      }
      try {
        if (!_scrollController.hasClients) return;
        final current = _scrollController.offset;
        final max = _scrollController.position.maxScrollExtent;
        final step = _itemStride;
        final next = current + step;
        if (next >= max * 0.75) {
          final base = widget.products.take(6).length;
          final jump = current % (base * _itemStride);
          _scrollController.jumpTo(jump);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                jump + step,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        } else {
          _scrollController.animateTo(
            next,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.isTablet;
    final eligible = ProductCache.withoutPrescriptionProducts(widget.products);
    if (eligible.isEmpty) {
      return const SizedBox.shrink();
    }
    final baseProducts = eligible.take(6).toList();
    final infiniteProducts = <Product>[];
    for (var i = 0; i < 10; i++) {
      infiniteProducts.addAll(baseProducts);
    }

    final currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportWidth = MediaQuery.sizeOf(context).width;

    return SizedBox(
      height: _stripHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: infiniteProducts.length,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final product = infiniteProducts[index];
          final itemCenter = index * _itemStride + _cardWidth / 2;
          final viewportCenter = currentOffset + viewportWidth / 2;
          final isInCenter =
              (itemCenter - viewportCenter).abs() < _itemStride * 0.55;

          return AnimatedScale(
            scale: isInCenter ? _centerScale : _sideScale,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(
                top: isInCenter ? 0 : 8,
                right: _cardSpacing,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isInCenter
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: SizedBox(
                  width: _cardWidth,
                  child: HomeProductCard(
                    product: product,
                    fontSize: isTablet ? 16 : 14,
                    padding: 0,
                    imageHeight: _imageHeight,
                    showWishlistButton: false,
                    showPrice: false,
                    showName: false,
                    showHero: false,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
