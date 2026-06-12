import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';

/// Visual tokens for category browse pages (rail, headers, product grid).
abstract final class SubcategoryDesign {
  static AppThemeColors _theme(BuildContext context) => context.appColors;

  static Color pageBg(BuildContext context) => _theme(context).pageBg;

  static Color canvasBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF0C1118) : const Color(0xFFF4F7F5);
  }

  static Color contentBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF111827) : Colors.white;
  }

  static Color railBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF0F1623) : const Color(0xFFFAFCFB);
  }

  static Color railHeaderBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF151D2B) : const Color(0xFFF6FAF7);
  }

  static Color railBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4EBE6);
  }

  static Color ink(BuildContext context) => _theme(context).ink;

  static Color muted(BuildContext context) => _theme(context).muted;

  static Color accent(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primary;

  static Color accentDark(BuildContext context) =>
      _theme(context).isDark ? AppColors.primaryLight : AppColors.primaryDark;

  static Color selectedTint(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.08);
  }

  static Color selectedBorder(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primaryLight.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.28);
  }

  static Color unselectedItemBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF151D2B) : Colors.white;
  }

  static Color selectedInk(BuildContext context) => accentDark(context);

  static Color unselectedInk(BuildContext context) => muted(context);

  static Color railActionBg(BuildContext context) => selectedTint(context);

  static List<Color> headerBandGradient(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return const [Color(0xFF151D2B), Color(0xFF111827)];
    }
    return const [Color(0xFFFAFCFB), Color(0xFFFFFFFF)];
  }

  static Color iconWell(BuildContext context) => selectedTint(context);

  /// Category grid page — search field on dark [pageBg] below the green header.
  static List<Color> categorySearchFieldGradient(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return const [Color(0xFF151D2B), Color(0xFF0F1623)];
    }
    return const [Color(0xFFFFFFFF), Color(0xFFFAFCFB)];
  }

  static Color categorySearchBorder(BuildContext context, {bool focused = false}) {
    final t = _theme(context);
    if (t.isDark) {
      return focused
          ? AppColors.primaryLight.withValues(alpha: 0.55)
          : AppColors.primary.withValues(alpha: 0.26);
    }
    return focused
        ? AppColors.primary.withValues(alpha: 0.45)
        : const Color(0xFFE2E8F0);
  }

  static List<BoxShadow> categorySearchShadow(
    BuildContext context, {
    bool focused = false,
  }) {
    final t = _theme(context);
    if (t.isDark) {
      return [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: focused ? 0.16 : 0.07),
          blurRadius: focused ? 18 : 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static Color categorySearchIconWellBg(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? AppColors.primary.withValues(alpha: 0.2)
        : const Color(0xFFE8F5E9);
  }

  static Color categorySearchIconColor(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? AppColors.primaryLight : AppColors.primary;
  }

  static Color categorySearchText(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? Colors.white : const Color(0xFF1F2937);
  }

  static Color categorySearchHint(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? Colors.white54 : const Color(0xFF9CA3AF);
  }

  static Color categorySearchClearIcon(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? Colors.white60 : const Color(0xFF9CA3AF);
  }

  static List<Color> categorySearchDropdownHeaderGradient(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return [
        AppColors.primary.withValues(alpha: 0.14),
        const Color(0xFF111827),
      ];
    }
    return [
      AppColors.primary.withValues(alpha: 0.08),
      AppColors.primary.withValues(alpha: 0.03),
    ];
  }

  static Color countChipBg(BuildContext context) => selectedTint(context);

  static Color countChipBorder(BuildContext context) => selectedBorder(context);

  static Color imageWellTop(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF1A2332) : const Color(0xFFF8FBF9);
  }

  static Color imageWellBottom(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? const Color(0xFF141C28) : const Color(0xFFEEF5F0);
  }

  static Color placeholderIcon(BuildContext context) {
    final t = _theme(context);
    return t.isDark ? Colors.white38 : const Color(0xFFB8C4BC);
  }

  static Color brandChipBg(BuildContext context) => selectedTint(context);

  static Color brandChipBorder(BuildContext context) => selectedBorder(context);

  static List<BoxShadow>? cardShadow(BuildContext context) {
    final t = _theme(context);
    if (!t.isDark) {
      return [
        BoxShadow(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ];
  }

  static (Color base, Color highlight) shimmerColors(BuildContext context) {
    final t = _theme(context);
    if (t.isDark) {
      return (const Color(0xFF1E293B), const Color(0xFF334155));
    }
    return (const Color(0xFFE8EEEA), const Color(0xFFF6FAF8));
  }

  static Color loadingOverlay(BuildContext context) {
    final t = _theme(context);
    return t.isDark
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.68);
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
    return (const Color(0xFFE5EAE7), const Color(0xFFD1D9D4));
  }

  static Widget loadingOverlayPill(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: loadingOverlay(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
