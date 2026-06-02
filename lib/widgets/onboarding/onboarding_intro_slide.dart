import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:eclapp/widgets/onboarding/onboarding_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// First onboarding step — brand hero and feature highlights.
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
      subtitle: 'Medicines and essentials at your door — quickly and reliably.',
      illustration: _IntroIllustration.delivery,
    ),
    _IntroFeature(
      title: 'Everything in one place',
      subtitle: 'Prescriptions, wellness, and everyday care — all in one app.',
      svgAsset: 'assets/images/Add to Cart-bro.svg',
    ),
    _IntroFeature(
      title: 'Talk to a pharmacist',
      subtitle: 'Licensed pharmacists when you need guidance or reassurance.',
      svgAsset: 'assets/images/Medical prescription-bro.svg',
    ),
  ];

  final PageController _featureController = PageController();
  int _featureIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_featureController.hasClients) return;
      final next = (_featureIndex + 1) % _features.length;
      _featureController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feature = _features[_featureIndex];

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ColoredBox(
        color: OnboardingUi.surface,
        child: Column(
          children: [
            const OnboardingHeroHeader(
              height: 200,
              imageAsset: 'assets/images/onboarding2.png',
              imageOpacity: 0.42,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  children: [
                    const OnboardingStepLabel(current: 1, total: 4),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to\nErnest Chemists',
                      textAlign: TextAlign.center,
                      style: OnboardingUi.displayTitle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your trusted partner for health and wellness across Ghana.',
                      textAlign: TextAlign.center,
                      style: OnboardingUi.body,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 168,
                      child: PageView.builder(
                        controller: _featureController,
                        onPageChanged: (i) => setState(() => _featureIndex = i),
                        itemCount: _features.length,
                        itemBuilder: (context, index) {
                          return _FeatureIllustration(
                            feature: _features[index],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    OnboardingProgressDots(
                      count: _features.length,
                      current: _featureIndex,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Column(
                        key: ValueKey<int>(_featureIndex),
                        children: [
                          Text(
                            feature.title,
                            textAlign: TextAlign.center,
                            style: OnboardingUi.featureTitle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feature.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: OnboardingUi.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OnboardingSlideFooter(
              progressDots: widget.progressDots,
              buttonLabel: 'Continue',
              onPressed: widget.isLoading ? null : widget.onContinue,
              isLoading: widget.isLoading,
              buttonIcon: Icons.arrow_forward_rounded,
              bottomPadding: 20,
            ),
          ],
        ),
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

class _FeatureIllustration extends StatelessWidget {
  const _FeatureIllustration({required this.feature});

  final _IntroFeature feature;

  @override
  Widget build(BuildContext context) {
    if (feature.illustration == _IntroIllustration.delivery) {
      return Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.16),
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            size: 52,
            color: AppColors.primaryDark,
          ),
        ),
      );
    }

    if (feature.svgAsset != null) {
      return SvgPicture.asset(
        feature.svgAsset!,
        height: 160,
        fit: BoxFit.contain,
      );
    }

    return const SizedBox.shrink();
  }
}
