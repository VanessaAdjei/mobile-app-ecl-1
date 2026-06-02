import 'dart:async';

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
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

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
        const step = 96.0;
        final next = current + step;
        if (next >= max * 0.75) {
          final base = widget.products.take(6).length;
          final jump = current % (base * 96.0);
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
    final baseProducts = widget.products.take(6).toList();
    final infiniteProducts = <Product>[];
    for (var i = 0; i < 10; i++) {
      infiniteProducts.addAll(baseProducts);
    }

    final currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    return Container(
      height: isTablet ? 80 : 120,
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: infiniteProducts.length,
        padding: const EdgeInsets.only(right: 2),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final product = infiniteProducts[index];
          final isInCenter = ((index * 82.0) - currentOffset).abs() < 48.0;

          return AnimatedScale(
            scale: isInCenter ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(top: isInCenter ? 8.0 : 0.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: SizedBox(
                  width: isTablet ? 100 : 80,
                  child: HomeProductCard(
                    product: product,
                    fontSize: isTablet ? 16 : 15,
                    padding: 0,
                    imageHeight: isTablet ? 80 : 100,
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
