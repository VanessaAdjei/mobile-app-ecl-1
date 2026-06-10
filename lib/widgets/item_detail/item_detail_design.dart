import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens for the product detail page body (header excluded).
abstract final class ItemDetailDesign {
  static const double pagePadding = 14;
  static const double radiusLg = 16;
  static const double radiusMd = 12;

  static AppThemeColors _theme(BuildContext context) => context.appColors;

  /// Page canvas — same as global [AppThemeColors.pageBg].
  static Color pageBg(BuildContext context) => _theme(context).pageBg;

  /// Primary content card (gallery, sections, bottom bar).
  static Color card(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF141C2B) : t.surface;
  }

  /// Product image backdrop inside the gallery card.
  static Color imageWell(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1A2433) : const Color(0xFFF0F7F3);
  }

  static Color cardBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8ECEA);
  }

  static Color ink(BuildContext context) => _theme(context).ink;

  static Color muted(BuildContext context) => _theme(context).muted;

  static Color accentTint(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.12)
        : const Color(0xFFE8F5EE);
  }

  static Color accentBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.35)
        : const Color(0xFFBBEAD3);
  }

  /// Muted chip / empty-state well.
  static Color mutedWell(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF9FAFB);
  }

  static Color headingAccent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primaryDark;

  static Color priceAccent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primary;

  static Color rxTint(BuildContext context) =>
      _theme(context).isDark
          ? const Color(0xFF3B1518)
          : const Color(0xFFFEF2F2);

  static Color rxBorder(BuildContext context) =>
      _theme(context).isDark
          ? const Color(0xFF7F1D1D)
          : const Color(0xFFFECACA);

  static Color rxInk(BuildContext context) =>
      _theme(context).isDark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFF991B1B);

  /// Prescription CTA when upload is still required.
  static Color prescriptionAction(BuildContext context) =>
      _theme(context).isDark
          ? const Color(0xFFEF4444)
          : const Color(0xFFB91C1C);

  static Color warningAccent(BuildContext context) =>
      _theme(context).isDark
          ? const Color(0xFFFCD34D)
          : const Color(0xFFFBBF24);

  static Color galleryDotInactive(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.white.withValues(alpha: 0.22)
        : const Color(0xFFD1E7DD);
  }

  static (Color base, Color highlight) shimmerColors(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return (const Color(0xFF1E293B), const Color(0xFF334155));
    }
    return (Colors.grey.shade300, Colors.grey.shade100);
  }

  static List<BoxShadow>? bottomBarShadow(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, -2),
      ),
    ];
  }

  static BoxDecoration searchShellDecoration(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLg),
        color: card(context),
        border: Border.all(color: cardBorder(context)),
        boxShadow: cardShadow(context),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusLg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          t.surface,
          accentTint(context).withValues(alpha: 0.65),
        ],
      ),
      border: Border.all(color: accentBorder(context)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration tagChipDecoration(BuildContext context) {
    return BoxDecoration(
      color: mutedWell(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cardBorder(context)),
    );
  }

  static BoxDecoration categoryChipDecoration(BuildContext context) {
    return BoxDecoration(
      color: accentTint(context),
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(color: accentBorder(context)),
    );
  }

  static List<BoxShadow>? cardShadow(BuildContext context) {
    if (!_theme(context).isDark) return null;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static BoxDecoration surfaceCard(BuildContext context, {Color? color}) {
    return BoxDecoration(
      color: color ?? card(context),
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: cardBorder(context)),
      boxShadow: cardShadow(context),
    );
  }

  /// Card with left accent stripe (status / section emphasis).
  static Widget accentStripeCard({
    required BuildContext context,
    required Widget child,
    Color stripeColor = AppColors.primary,
    EdgeInsets padding = const EdgeInsets.all(12),
    Color? backgroundColor,
  }) {
    return Container(
      decoration: surfaceCard(context, color: backgroundColor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusLg - 1),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: stripeColor),
            ),
            Padding(
              padding: padding.copyWith(left: padding.left + 4),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink(context),
        letterSpacing: -0.2,
        height: 1.1,
      );

  static TextStyle sectionCaption(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 12,
        color: muted(context),
        height: 1.2,
      );

  static Widget sectionLabel(
    BuildContext context,
    String title, {
    String? subtitle,
    IconData? icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: priceAccent(context).withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: sectionTitle(context)),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle, style: sectionCaption(context)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
