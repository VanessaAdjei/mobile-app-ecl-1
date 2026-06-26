import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Home promo carousel — local banner assets.
class HomePromoBannerCarousel extends StatefulWidget {
  const HomePromoBannerCarousel({super.key});

  @override
  State<HomePromoBannerCarousel> createState() =>
      _HomePromoBannerCarouselState();
}

class _HomePromoBannerCarouselState extends State<HomePromoBannerCarousel> {
  static const _banners = <_BannerData>[
    _BannerData(image: 'assets/images/banner3.jpg'),
    _BannerData(image: 'assets/images/banner4.jpg'),
    _BannerData(image: 'assets/images/Con 2.2.jpg'),
  ];

  static int get _slideCount => _banners.length;
  static const int _infiniteOffset = 10000;

  late final PageController _pageController;
  Timer? _autoTimer;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _infiniteOffset,
      viewportFraction: 0.88,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoScroll());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
    final bannerHeight = isTablet ? 220.0 : 140.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) =>
                setState(() => _activeIndex = i % _slideCount),
            itemBuilder: (context, index) {
              final data = _banners[index % _slideCount];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? index.toDouble()) - index;
                  }
                  value = value.clamp(-1.0, 1.0);
                  final scale = 1 - (0.15 * value.abs());
                  final angle = value * 0.18;
                  final translateX = value * (isTablet ? 40.0 : 24.0);

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translate(translateX)
                      ..scale(scale, scale)
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: child,
                  );
                },
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 2 : 1,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.13),
                        blurRadius: isTablet ? 10 : 7,
                        offset: Offset(0, isTablet ? 4 : 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          data.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: bannerHeight * 0.45,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slideCount, (i) {
            final active = _activeIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerData {
  const _BannerData({
    required this.image,
  });

  final String image;
}

/// Shimmer placeholder matching the previous banner layout.
class HomePromoBannerCarouselSkeleton extends StatelessWidget {
  const HomePromoBannerCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width > 600;
    final height = isTablet ? 220.0 : 140.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
