import 'package:flutter/material.dart';

import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_utils.dart';

/// Shared card styling for payment information sections.
abstract final class PaymentSectionStyle {
  static EdgeInsets marginOf(BuildContext context) => EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.pageHorizontalPadding(context),
      );

  static EdgeInsets paddingOf(BuildContext context) =>
      EdgeInsets.all(ResponsiveUtils.scaled(context, 14));

  static double radiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 15);

  static double innerRadiusOf(BuildContext context) =>
      ResponsiveUtils.scaled(context, 11);

  static BoxDecoration cardDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(radiusOf(context)),
      border: Border.all(color: t.border),
      boxShadow: t.isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: ResponsiveUtils.scaled(context, 8),
                offset: Offset(0, ResponsiveUtils.scaled(context, 2)),
              ),
            ]
          : [
              BoxShadow(
                color: const Color(0x12000000),
                blurRadius: ResponsiveUtils.scaled(context, 8),
                offset: Offset(0, ResponsiveUtils.scaled(context, 2)),
              ),
            ],
    );
  }

  static BoxDecoration innerPanelDecoration(BuildContext context) {
    final t = context.appColors;
    return BoxDecoration(
      color: t.fieldBg,
      borderRadius: BorderRadius.circular(innerRadiusOf(context)),
      border: Border.all(color: t.border),
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
}
