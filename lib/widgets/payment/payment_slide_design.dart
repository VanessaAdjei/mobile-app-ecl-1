import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';

/// Visual tokens for the payment page slide-to-pay control.
abstract final class PaymentSlideDesign {
  static AppThemeColors _theme(BuildContext context) => context.appColors;

  static Color trackBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF111827) : const Color(0xFFEEF9F3);
  }

  static Color trackBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.primary.withValues(alpha: 0.4);
  }

  static double trackBorderWidth(BuildContext context) => 1;

  static List<Color> progressColors(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return const [
        AppColors.primaryDark,
        AppColors.primary,
      ];
    }
    return const [AppColors.primaryDark, AppColors.primary];
  }

  static Color accent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primary;

  static Color labelColor(BuildContext context, {required bool onProgress}) {
    if (onProgress) return Colors.white;
    return _theme(context).muted;
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
    return Border.all(
      color: t.isDark
          ? Colors.white.withValues(alpha: 0.1)
          : AppColors.primary.withValues(alpha: 0.15),
    );
  }

  static List<BoxShadow> handleShadow(BuildContext context) {
    final t = _theme(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: t.isDark ? 0.35 : 0.1),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static Color processingOverlay(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.25);
  }

  static double disabledOpacity(BuildContext context) =>
      _theme(context).isDark ? 0.5 : 0.6;
}
