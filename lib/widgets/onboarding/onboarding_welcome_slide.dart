import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/widgets/onboarding/onboarding_ui.dart';
import 'package:flutter/material.dart';

/// Final onboarding step before the home screen.
class OnboardingWelcomeSlide extends StatefulWidget {
  const OnboardingWelcomeSlide({
    super.key,
    required this.onGetStarted,
    required this.progressDots,
    this.isLoading = false,
  });

  final VoidCallback onGetStarted;
  final Widget progressDots;
  final bool isLoading;

  @override
  State<OnboardingWelcomeSlide> createState() => _OnboardingWelcomeSlideState();
}

class _OnboardingWelcomeSlideState extends State<OnboardingWelcomeSlide> {
  int _catalogCount = 0;

  @override
  void initState() {
    super.initState();
    _catalogCount = ProductCache.catalogProductCount;
    ProductCache.addCatalogListener(_onCatalogUpdated);
  }

  @override
  void dispose() {
    ProductCache.removeCatalogListener(_onCatalogUpdated);
    super.dispose();
  }

  void _onCatalogUpdated() {
    if (!mounted) return;
    final count = ProductCache.catalogProductCount;
    if (count != _catalogCount) {
      setState(() => _catalogCount = count);
    }
  }

  String get _catalogStatusLine {
    if (!widget.isLoading) return '';
    if (_catalogCount > 0) {
      return '';
    }
    if (ProductCache.isCatalogLoadInFlight) {
      return '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final statusLine = _catalogStatusLine;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ColoredBox(
        color: OnboardingUi.surface,
        child: Column(
          children: [
            const OnboardingHeroHeader(height: 240),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const OnboardingStepLabel(current: 4, total: 4),
                    const SizedBox(height: 14),
                    Text(
                      "You're all set",
                      textAlign: TextAlign.center,
                      style: OnboardingUi.displayTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We appreciate you choosing Ernest Chemists for your health and wellness essentials.',
                      textAlign: TextAlign.center,
                      style: OnboardingUi.body,
                    ),
                    if (statusLine.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              statusLine,
                              textAlign: TextAlign.center,
                              style: OnboardingUi.body.copyWith(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    OnboardingContentCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: AppColors.primary.withValues(alpha: 0.9),
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your health, our priority',
                            textAlign: TextAlign.center,
                            style: OnboardingUi.bodyStrong,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Our team is ready to help you shop, refill prescriptions, and get expert advice whenever you need it.',
                            textAlign: TextAlign.center,
                            style: OnboardingUi.body.copyWith(fontSize: 14),
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
              buttonLabel: 'Get started',
              onPressed: widget.isLoading ? null : widget.onGetStarted,
              isLoading: widget.isLoading,
              bottomPadding: 20,
            ),
          ],
        ),
      ),
    );
  }
}
