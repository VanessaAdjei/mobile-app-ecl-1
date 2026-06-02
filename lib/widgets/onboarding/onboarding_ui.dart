import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared onboarding palette and layout tokens.
abstract final class OnboardingUi {
  static const Color ink = Color(0xFF111827);
  static const Color inkMuted = Color(0xFF6B7280);
  static const Color surface = Color(0xFFF7FAF8);
  static const Color card = Colors.white;

  static const List<Color> heroGradient = [
    Color(0xFF041F0E),
    Color(0xFF0A3A1C),
    Color(0xFF157A42),
    AppColors.primary,
  ];

  static const List<double> heroGradientStops = [0.0, 0.35, 0.72, 1.0];

  static TextStyle get displayTitle => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
        letterSpacing: -0.4,
      );

  static TextStyle get sectionTitle => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: ink,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: inkMuted,
      );

  static TextStyle get bodyStrong => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: ink,
      );

  static TextStyle get featureTitle => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: ink,
      );

  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDark,
        letterSpacing: 0.3,
      );
}

/// Step counter shown under the hero on intro-style slides.
class OnboardingStepLabel extends StatelessWidget {
  const OnboardingStepLabel({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Step $current of $total',
      style: OnboardingUi.label,
    );
  }
}

/// Animated page progress dots.
class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    super.key,
    required this.count,
    required this.current,
    this.light = false,
  });

  final int count;
  final int current;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = current == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? (light ? Colors.white : AppColors.primary)
                : (light
                    ? Colors.white.withValues(alpha: 0.35)
                    : AppColors.primary.withValues(alpha: 0.22)),
          ),
        );
      }),
    );
  }
}

/// Primary CTA used across onboarding slides.
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Footer chrome: progress dots + primary button.
class OnboardingSlideFooter extends StatelessWidget {
  const OnboardingSlideFooter({
    super.key,
    required this.progressDots,
    required this.buttonLabel,
    required this.onPressed,
    this.isLoading = false,
    this.buttonIcon,
    this.bottomPadding = 24,
  });

  final Widget progressDots;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? buttonIcon;
  final double bottomPadding;

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
          OnboardingPrimaryButton(
            label: buttonLabel,
            onPressed: onPressed,
            isLoading: isLoading,
            icon: buttonIcon,
          ),
        ],
      ),
    );
  }
}

/// Curved bottom edge for green hero bands.
class OnboardingHeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 6,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Green gradient hero with optional photo overlay and centered logo.
class OnboardingHeroHeader extends StatelessWidget {
  const OnboardingHeroHeader({
    super.key,
    this.height = 220,
    this.imageAsset,
    this.imageOpacity = 0.35,
    this.showLogo = true,
    this.child,
  });

  final double height;
  final String? imageAsset;
  final double imageOpacity;
  final bool showLogo;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipPath(
      clipper: OnboardingHeroClipper(),
      child: SizedBox(
        height: height + topInset,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: OnboardingUi.heroGradient,
                  stops: OnboardingUi.heroGradientStops,
                ),
              ),
            ),
            if (imageAsset != null)
              Positioned.fill(
                child: Opacity(
                  opacity: imageOpacity,
                  child: Image.asset(imageAsset!, fit: BoxFit.cover),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -40,
              top: topInset + 12,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: -24,
              bottom: 40,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.12),
              ),
            ),
            if (child != null)
              Positioned.fill(child: child!)
            else if (showLogo)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topInset * 0.35),
                  child: const _OnboardingLogoBadge(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingLogoBadge extends StatelessWidget {
  const _OnboardingLogoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 44,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        child: CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/images/png.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded card shell for list content on onboarding slides.
class OnboardingContentCard extends StatelessWidget {
  const OnboardingContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: OnboardingUi.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F0EB)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
