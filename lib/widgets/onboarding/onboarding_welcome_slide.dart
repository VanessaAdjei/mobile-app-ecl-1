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

class _OnboardingWelcomeSlideState extends State<OnboardingWelcomeSlide>
    with TickerProviderStateMixin {
  int _catalogCount = 0;

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;
  late final Animation<double> _buttonPulse;

  @override
  void initState() {
    super.initState();
    _catalogCount = ProductCache.catalogProductCount;
    ProductCache.addCatalogListener(_onCatalogUpdated);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _buttonFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _buttonPulse = Tween<double>(begin: 1, end: 1.045).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward().then((_) {
      if (mounted && !widget.isLoading) _startButtonPulse();
    });
  }

  void _startButtonPulse() {
    if (_pulseController.isAnimating) return;
    _pulseController.repeat(reverse: true);
  }

  void _stopButtonPulse() {
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.value = 0;
  }

  @override
  void didUpdateWidget(OnboardingWelcomeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _stopButtonPulse();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _startButtonPulse();
    }
  }

  @override
  void dispose() {
    ProductCache.removeCatalogListener(_onCatalogUpdated);
    _entranceController.dispose();
    _pulseController.dispose();
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
            _AnimatedGetStartedFooter(
              progressDots: widget.progressDots,
              buttonLabel: 'Get started',
              onPressed: widget.isLoading ? null : widget.onGetStarted,
              isLoading: widget.isLoading,
              bottomPadding: 20,
              fade: _buttonFade,
              slide: _buttonSlide,
              pulse: _buttonPulse,
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer with entrance + gentle pulse on the primary CTA (welcome slide only).
class _AnimatedGetStartedFooter extends StatelessWidget {
  const _AnimatedGetStartedFooter({
    required this.progressDots,
    required this.buttonLabel,
    required this.onPressed,
    required this.fade,
    required this.slide,
    required this.pulse,
    this.isLoading = false,
    this.bottomPadding = 24,
  });

  final Widget progressDots;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double bottomPadding;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          progressDots,
          const SizedBox(height: 16),
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isLoading ? 1 : pulse.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: OnboardingPrimaryButton(
                  label: buttonLabel,
                  onPressed: onPressed,
                  isLoading: isLoading,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
