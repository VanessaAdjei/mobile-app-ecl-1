import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_utils.dart';

/// Section accent palette for payment cards.
class PaymentSectionAccent {
  const PaymentSectionAccent({
    required this.gradient,
    this.tint,
    this.border,
  });

  final List<Color> gradient;
  final Color? tint;
  final Color? border;

  static PaymentSectionAccent delivery(BuildContext context) {
    final dark = context.appColors.isDark;
    return PaymentSectionAccent(
      gradient: const [Color(0xFF42A5F5), Color(0xFF1565C0)],
      tint: dark
          ? const Color(0xFF1565C0).withValues(alpha: 0.14)
          : const Color(0xFFE3F2FD),
      border: dark
          ? const Color(0xFF42A5F5).withValues(alpha: 0.28)
          : const Color(0xFF90CAF9),
    );
  }

  static PaymentSectionAccent order(BuildContext context) {
    final dark = context.appColors.isDark;
    return PaymentSectionAccent(
      gradient: const [Color(0xFF66BB6A), AppColors.primary],
      tint: dark
          ? AppColors.primary.withValues(alpha: 0.12)
          : const Color(0xFFE8F5E9),
      border: dark
          ? AppColors.primaryLight.withValues(alpha: 0.28)
          : const Color(0xFFA5D6A7),
    );
  }

  static PaymentSectionAccent bill(BuildContext context) {
    final dark = context.appColors.isDark;
    return PaymentSectionAccent(
      gradient: const [Color(0xFF43A047), AppColors.primaryDark],
      tint: dark
          ? AppColors.primaryDark.withValues(alpha: 0.16)
          : const Color(0xFFEEF9F3),
      border: dark
          ? AppColors.primary.withValues(alpha: 0.3)
          : const Color(0xFFBBEAD3),
    );
  }
}

/// Section title with gradient icon badge.
class PaymentSectionHeader extends StatelessWidget {
  const PaymentSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.icon,
    this.accent,
    this.compact = false,
  });

  final String title;
  final String? eyebrow;
  final String? trailing;
  final IconData? icon;
  final PaymentSectionAccent? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final colors =
        accent?.gradient ?? const [AppColors.primary, AppColors.primaryDark];
    final badgeSize = compact ? 28.0 : 32.0;
    final iconSize = compact ? 14.0 : 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
              boxShadow: compact
                  ? null
                  : [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Icon(icon, size: iconSize, color: Colors.white),
          ),
          SizedBox(width: compact ? 10 : 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact && eyebrow != null && eyebrow!.isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: colors.first.withValues(alpha: t.isDark ? 0.9 : 1),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: t.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null && trailing!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (accent?.tint ?? t.accentTint),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent?.border ?? t.accentBorder,
              ),
            ),
            child: Text(
              trailing!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.last,
              ),
            ),
          ),
      ],
    );
  }
}

/// Payment section card with optional accent tint.
class PaymentSectionCard extends StatelessWidget {
  const PaymentSectionCard({
    super.key,
    required this.child,
    this.padding,
    this.accent,
    this.inFlow = false,
  });

  final Widget child;
  final EdgeInsets? padding;
  final PaymentSectionAccent? accent;
  final bool inFlow;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? PaymentSectionStyle.paddingOf(context);

    return Container(
      margin: inFlow ? EdgeInsets.zero : PaymentSectionStyle.marginOf(context),
      decoration: PaymentSectionStyle.cardDecoration(
        context,
        accent: accent,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accent != null)
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: accent!.gradient),
              ),
            ),
          Padding(
            padding: pad,
            child: child,
          ),
        ],
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
      EdgeInsets.all(ResponsiveUtils.scaled(context, 10));

  static double radiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 13);

  static double innerRadiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 8);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    PaymentSectionAccent? accent,
  }) {
    final t = context.appColors;
    final stripe = accent?.gradient.last ?? AppColors.primary;
    return BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(radiusOf(context)),
      border: Border.all(
        color: accent?.border?.withValues(alpha: 0.55) ?? t.border,
      ),
      boxShadow: t.isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: ResponsiveUtils.scaled(context, 12),
                offset: Offset(0, ResponsiveUtils.scaled(context, 4)),
              ),
            ]
          : [
              BoxShadow(
                color: stripe.withValues(alpha: 0.1),
                blurRadius: ResponsiveUtils.scaled(context, 14),
                offset: Offset(0, ResponsiveUtils.scaled(context, 5)),
              ),
            ],
    );
  }

  static BoxDecoration innerPanelDecoration(
    BuildContext context, {
    PaymentSectionAccent? accent,
  }) {
    final t = context.appColors;
    return BoxDecoration(
      color: accent?.tint ?? t.fieldBg,
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(
        color: accent?.border?.withValues(alpha: 0.5) ?? t.border,
      ),
    );
  }

  static BoxDecoration accentPanelDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      color: t.accentTint,
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(color: t.accentBorder.withValues(alpha: 0.8)),
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
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primaryDark.withValues(alpha: 0.35),
              ]
            : [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.primary.withValues(alpha: 0.16),
              ],
      ),
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: t.isDark ? 0.4 : 0.22),
      ),
    );
  }

  static Widget sectionDivider(BuildContext context) {
    final t = context.appColors;
    return Divider(
      height: 1,
      thickness: 1,
      color: t.border.withValues(alpha: 0.75),
    );
  }
}
