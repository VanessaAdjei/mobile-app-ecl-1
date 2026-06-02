import 'package:flutter/material.dart';

/// Soft photo + gradient overlay used on intro and safety onboarding slides.
class OnboardingSlideBackground extends StatelessWidget {
  const OnboardingSlideBackground({
    super.key,
    this.imageAsset = 'assets/images/onboarding2.png',
    this.imageOpacity = 0.52,
    this.child,
  });

  final String imageAsset;
  final double imageOpacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: imageOpacity,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  const Color(0xE6F8F9FA),
                  const Color(0xCCE0F2F1),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
