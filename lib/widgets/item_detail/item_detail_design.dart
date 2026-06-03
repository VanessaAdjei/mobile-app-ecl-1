import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens for the product detail page body (header excluded).
abstract final class ItemDetailDesign {
  static const Color pageBg = Color(0xFFF5F7F6);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE8ECEA);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color accentLight = Color(0xFFE8F5EE);
  static const Color imageWell = Color(0xFFF0F7F3);

  static const double pagePadding = 14;
  static const double radiusLg = 16;
  static const double radiusMd = 12;

  static BoxDecoration surfaceCard({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: border),
      );

  /// Card with left accent stripe (status / section emphasis).
  static Widget accentStripeCard({
    required Widget child,
    Color stripeColor = AppColors.primary,
    EdgeInsets padding = const EdgeInsets.all(12),
    Color? backgroundColor,
  }) {
    return Container(
      decoration: surfaceCard(color: backgroundColor),
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

  static TextStyle sectionTitle() => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.2,
        height: 1.1,
      );

  static TextStyle sectionCaption() => GoogleFonts.poppins(
        fontSize: 12,
        color: muted,
        height: 1.2,
      );

  static TextStyle priceLarge() => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: -0.35,
        height: 1.1,
      );

  static Widget sectionLabel(String title, {String? subtitle, IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: sectionTitle()),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle, style: sectionCaption()),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
