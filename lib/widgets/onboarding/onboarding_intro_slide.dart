import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Intro onboarding — compact header, feature carousel, single copy block.
class OnboardingIntroSlide extends StatefulWidget {
  const OnboardingIntroSlide({
    super.key,
    required this.progressDots,
    required this.onContinue,
    this.isLoading = false,
  });

  final Widget progressDots;
  final VoidCallback onContinue;
  final bool isLoading;

  @override
  State<OnboardingIntroSlide> createState() => _OnboardingIntroSlideState();
}

class _OnboardingIntroSlideState extends State<OnboardingIntroSlide> {
  static const _features = [
    _IntroFeature(
      title: 'Fast delivery, anytime',
      subtitle: 'Medicines and essentials delivered quickly and reliably.',
      illustration: _IntroIllustration.delivery,
    ),
    _IntroFeature(
      title: 'All your health needs, one app',
      subtitle: 'Prescriptions, wellness products, and everyday care.',
      svgAsset: 'assets/images/Add to Cart-bro.svg',
    ),
    _IntroFeature(
      title: 'Speak to a pharmacist',
      subtitle: 'Chat with a licensed pharmacist when you need guidance.',
      svgAsset: 'assets/images/Medical prescription-bro.svg',
    ),
  ];

  final PageController _heroController = PageController();
  int _heroIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroController.hasClients) return;
      final next = (_heroIndex + 1) % _features.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const headerHeight = 132.0;
    final feature = _features[_heroIndex];

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
        children: [
          ClipPath(
            clipper: _WaveClipper(),
            child: SizedBox(
              height: headerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF062A12),
                          Color(0xFF0D3D18),
                          AppColors.accent,
                          Color(0xFF2E7D32),
                        ],
                        stops: [0.0, 0.28, 0.62, 1.0],
                      ),
                    ),
                  ),
                  Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/png.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAFCFB), Color(0xFFF0F7F2)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Column(
                  children: [
                    Text(
                      'Welcome to Ernest Chemists Limited',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your trusted partner for health and wellness.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 188,
                      child: PageView.builder(
                        controller: _heroController,
                        onPageChanged: (i) => setState(() => _heroIndex = i),
                        itemCount: _features.length,
                        itemBuilder: (context, index) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: _IntroIllustrationView(
                              feature: _features[index],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 58),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _features.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _heroIndex == i ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _heroIndex == i
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Column(
                        key: ValueKey<int>(_heroIndex),
                        children: [
                          Text(
                            feature.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          widget.progressDots,
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _IntroIllustration { delivery, svg }

class _IntroFeature {
  const _IntroFeature({
    required this.title,
    required this.subtitle,
    this.illustration = _IntroIllustration.svg,
    this.svgAsset,
  });

  final String title;
  final String subtitle;
  final _IntroIllustration illustration;
  final String? svgAsset;
}

class _IntroIllustrationView extends StatelessWidget {
  const _IntroIllustrationView({required this.feature});

  final _IntroFeature feature;

  @override
  Widget build(BuildContext context) {
    const maxIllustrationHeight = 176.0;

    if (feature.illustration == _IntroIllustration.delivery) {
      return const _DeliveryIllustration(size: 120);
    }

    if (feature.svgAsset != null) {
      return SvgPicture.asset(
        feature.svgAsset!,
        height: maxIllustrationHeight,
        fit: BoxFit.contain,
      );
    }

    return const SizedBox.shrink();
  }
}

class _DeliveryIllustration extends StatelessWidget {
  const _DeliveryIllustration({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.local_shipping_rounded,
        size: size * 0.42,
        color: AppColors.primaryDark,
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 16);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 4,
      size.width,
      size.height - 16,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
