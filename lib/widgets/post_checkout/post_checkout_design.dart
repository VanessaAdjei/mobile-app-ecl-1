import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// Visual tokens for post-checkout / order tracking screens.
abstract final class PostCheckoutDesign {
  static const Color accent = Color(0xFF0D7A4C);
  static const Color accentLight = Color(0xFFE8F5EE);
  static const Color pageBg = Color(0xFFF5F7F6);
  static const Color sheetBg = Color(0xFFFAFBFA);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE8ECEA);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double radiusSm = 10;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration surfaceCard({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border),
        boxShadow: cardShadow,
      );

  /// Subtle bordered surface — no drop shadow (confirmation summary rows).
  static BoxDecoration compactCard({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );

  static const String logoAsset = 'assets/images/png.png';

  /// Centered ECL mark at the top of post-checkout scroll content.
  static Widget pageLogo({double height = 34}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Image.asset(
          logoAsset,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_pharmacy_rounded,
            color: accent,
            size: height * 0.85,
          ),
        ),
      ),
    );
  }

  /// Circular logo badge for status cards.
  static Widget logoMark({
    double size = 36,
    EdgeInsets padding = const EdgeInsets.all(7),
    Color backgroundColor = Colors.white,
    Color? borderColor,
    Widget? overlay,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: borderColor != null
                ? Border.all(color: borderColor)
                : Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: padding,
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_pharmacy_rounded,
                color: accent,
                size: size * 0.45,
              ),
            ),
          ),
        ),
        if (overlay != null) overlay,
      ],
    );
  }

  static Widget successCheckOverlay({double size = 16}) {
    return Positioned(
      right: -2,
      bottom: -2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 10,
          color: Colors.white,
        ),
      ),
    );
  }

  static BoxDecoration accentHero() => BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );
}
