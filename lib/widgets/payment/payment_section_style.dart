import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_utils.dart';

/// Section title row used across payment information cards.
class PaymentSectionHeader extends StatelessWidget {
  const PaymentSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.accentColors,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color>? accentColors;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final gradient = accentColors ??
        [
          AppColors.primary,
          AppColors.primaryDark,
        ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.15,
                  color: t.ink,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.2,
                    color: t.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Payment section card with a left accent stripe (safe with borderRadius).
class PaymentSectionCard extends StatelessWidget {
  const PaymentSectionCard({
    super.key,
    required this.child,
    this.accentStripe,
    this.padding,
  });

  final Widget child;
  final Color? accentStripe;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final stripe = accentStripe ?? AppColors.primary;
    final pad = padding ?? PaymentSectionStyle.paddingOf(context);

    return Container(
      margin: PaymentSectionStyle.marginOf(context),
      decoration: PaymentSectionStyle.cardDecoration(
        context,
        accentStripe: stripe,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: stripe,
              child: const SizedBox(width: 4),
            ),
            Expanded(
              child: Padding(
                padding: pad,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared card styling for payment information sections.
abstract final class PaymentSectionStyle {
  static EdgeInsets marginOf(BuildContext context) => EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.pageHorizontalPadding(context),
      );

  static EdgeInsets paddingOf(BuildContext context) =>
      EdgeInsets.all(ResponsiveUtils.scaled(context, 13));

  static double radiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 14);

  static double innerRadiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 10);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? accentStripe,
  }) {
    final t = context.appColors;
    final stripe = accentStripe ?? AppColors.primary;
    final edgeColor =
        t.isDark ? t.border : t.accentBorder.withValues(alpha: 0.4);
    return BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(radiusOf(context)),
      border: Border.all(color: edgeColor),
      boxShadow: t.isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: ResponsiveUtils.scaled(context, 8),
                offset: Offset(0, ResponsiveUtils.scaled(context, 2)),
              ),
            ]
          : [
              BoxShadow(
                color: stripe.withValues(alpha: 0.1),
                blurRadius: ResponsiveUtils.scaled(context, 10),
                offset: Offset(0, ResponsiveUtils.scaled(context, 3)),
              ),
            ],
    );
  }

  static BoxDecoration innerPanelDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      color: t.fieldBg,
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(color: t.border.withValues(alpha: 0.8)),
    );
  }

  static BoxDecoration accentPanelDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      color: t.accentTint,
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(color: t.accentBorder),
    );
  }

  static BoxDecoration totalPanelDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: t.isDark
            ? [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.primaryDark.withValues(alpha: 0.38),
              ]
            : [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primary.withValues(alpha: 0.2),
              ],
      ),
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: t.isDark ? 0.45 : 0.28),
      ),
    );
  }
}
