import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';

/// Visual tokens for the payment page slide-to-pay control.
abstract final class PaymentSlideDesign {
  static AppThemeColors _theme(BuildContext context) => context.appColors;

  static Color trackBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF141C2B) : t.fieldBg;
  }

  static Color trackBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? t.accentBorder : AppColors.primary;
  }

  static double trackBorderWidth(BuildContext context) =>
      _theme(context).isDark ? 1.0 : 1.5;

  static List<Color> progressColors(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return const [
        AppColors.primaryDark,
        AppColors.primary,
        AppColors.primaryLight,
      ];
    }
    return const [AppColors.primary, AppColors.primary];
  }

  static Color accent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primary;

  static Color labelColor(BuildContext context, {required bool onProgress}) {
    if (onProgress) return Colors.white;
    return _theme(context).ink;
  }

  static Color labelIconColor(BuildContext context, {required bool onProgress}) {
    if (onProgress) return Colors.white70;
    return _theme(context).muted;
  }

  static Color handleBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1E293B) : Colors.white;
  }

  static Border? handleBorder(BuildContext context) {
    final t = _theme(context);
    if (!t.isDark) return null;
    return Border.all(color: t.accentBorder, width: 1);
  }

  static List<BoxShadow> handleShadow(BuildContext context) {
    final t = _theme(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: t.isDark ? 0.45 : 0.12),
        blurRadius: t.isDark ? 8 : 4,
        offset: Offset(0, t.isDark ? 2 : 1),
      ),
    ];
  }

  static Color processingOverlay(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.2);
  }

  static double disabledOpacity(BuildContext context) =>
      _theme(context).isDark ? 0.55 : 0.65;
}
