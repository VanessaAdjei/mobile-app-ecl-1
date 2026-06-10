import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';

/// Visual tokens for [SubcategoryPage] (rail, header band, product grid).
abstract final class SubcategoryDesign {
  static AppThemeColors _theme(BuildContext context) => context.appColors;

  static Color pageBg(BuildContext context) => _theme(context).pageBg;

  static Color canvasBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF111827) : const Color(0xFFF3F7F4);
  }

  static Color contentBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFCFB);
  }

  static Color railBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF141C2B) : const Color(0xFFF8FBF8);
  }

  static Color railHeaderBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1E293B) : const Color(0xFFF2F8F2);
  }

  static Color railBorder(BuildContext context) => _theme(context).border;

  static Color ink(BuildContext context) => _theme(context).ink;

  static Color muted(BuildContext context) => _theme(context).muted;

  static Color accent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primary;

  static Color accentDark(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primaryDark;

  static Color selectedTint(BuildContext context) => _theme(context).accentTint;

  static Color selectedBorder(BuildContext context) =>
      _theme(context).accentBorder;

  static Color unselectedItemBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1A2332) : Colors.white;
  }

  static Color selectedInk(BuildContext context) => accentDark(context);

  static Color unselectedInk(BuildContext context) => muted(context);

  static Color railActionBg(BuildContext context) => selectedTint(context);

  static List<Color> headerBandGradient(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return const [Color(0xFF1A2332), Color(0xFF141C2B)];
    }
    return const [Color(0xFFF7FBF7), Color(0xFFFBFCFB)];
  }

  static Color iconWell(BuildContext context) => selectedTint(context);

  static Color countChipBg(BuildContext context) => selectedTint(context);

  static Color countChipBorder(BuildContext context) => selectedBorder(context);

  static Color imageWellTop(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1A2433) : const Color(0xFFF4FAF6);
  }

  static Color imageWellBottom(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF141C2B) : const Color(0xFFE8F3EC);
  }

  static Color placeholderIcon(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? Colors.white38 : const Color(0xFFB0BEC5);
  }

  static Color brandChipBg(BuildContext context) => selectedTint(context);

  static Color brandChipBorder(BuildContext context) => selectedBorder(context);

  static List<BoxShadow>? cardShadow(BuildContext context) {
    if (!_theme(context).isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static (Color base, Color highlight) shimmerColors(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return (const Color(0xFF1E293B), const Color(0xFF334155));
    }
    return (Colors.grey.shade300, Colors.grey.shade100);
  }

  static Color loadingOverlay(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.7);
  }

  static Color outOfStockScrim(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.black.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.55);
  }

  static (Color, Color) disabledActionGradient(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return (const Color(0xFF374151), const Color(0xFF4B5563));
    }
    return (Colors.grey.shade300, Colors.grey.shade400);
  }

  static Widget loadingOverlayPill(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: loadingOverlay(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
