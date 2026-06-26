import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';

/// Visual tokens for post-checkout / order tracking screens.
abstract final class PostCheckoutDesign {
  static const Color accent = Color(0xFF0D7A4C);

  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double radiusSm = 10;

  static const String logoAsset = 'assets/images/app_logo.png';

  static AppThemeColors _t(BuildContext context) => context.appColors;

  static Color pageBg(BuildContext context) => _t(context).pageBg;

  static Color surface(BuildContext context) => _t(context).surface;

  static Color sheetBg(BuildContext context) =>
      _t(context).isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFBFA);

  static Color border(BuildContext context) => _t(context).border;

  static Color ink(BuildContext context) => _t(context).ink;

  static Color muted(BuildContext context) => _t(context).muted;

  static Color fieldBg(BuildContext context) => _t(context).fieldBg;

  static Color accentLight(BuildContext context) {
    final t = _t(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.14)
        : const Color(0xFFE8F5EE);
  }

  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: _t(context).isDark ? 0.22 : 0.05,
          ),
          blurRadius: _t(context).isDark ? 8 : 16,
          offset: Offset(0, _t(context).isDark ? 2 : 4),
        ),
      ];

  static BoxDecoration surfaceCard(BuildContext context, {Color? color}) =>
      BoxDecoration(
        color: color ?? surface(context),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border(context)),
        boxShadow: cardShadow(context),
      );

  /// Subtle bordered surface — no drop shadow (confirmation summary rows).
  static BoxDecoration compactCard(BuildContext context, {Color? color}) =>
      BoxDecoration(
        color: color ?? surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border(context)),
      );

  /// Centered ECL mark at the top of post-checkout scroll content.
  static Widget pageLogo(BuildContext context, {double height = 34}) {
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
  static Widget logoMark(
    BuildContext context, {
    double size = 36,
    EdgeInsets padding = const EdgeInsets.all(7),
    Color? backgroundColor,
    Color? borderColor,
    Widget? overlay,
  }) {
    final bg = backgroundColor ?? surface(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
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
        gradient: const LinearGradient(
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
