import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Semantic colors that follow [ThemeProvider] / [ThemeData] brightness.
class AppThemeColors {
  AppThemeColors._(this._context);

  final BuildContext _context;

  bool get isDark => Theme.of(_context).brightness == Brightness.dark;

  Color get pageBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7F5);

  Color get surface => Theme.of(_context).cardColor;

  Color get ink => isDark ? Colors.white : const Color(0xFF1F2937);

  Color get muted => isDark ? Colors.white70 : const Color(0xFF6B7280);

  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE5EBE8);

  Color get fieldBg => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF3F4F6);

  /// Product search fields — white in both themes for contrast on the green header.
  Color get searchBarBg => Colors.white;

  Color get searchBarText => const Color(0xFF1F2937);

  Color get searchBarHint => const Color(0xFF9CA3AF);

  Color get searchBorder =>
      isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

  Color get accentTint => isDark
      ? AppColors.primary.withValues(alpha: 0.14)
      : const Color(0xFFEEF9F3);

  Color get accentBorder => isDark
      ? AppColors.primary.withValues(alpha: 0.28)
      : const Color(0xFFBBEAD3);

  Color get skeleton => isDark ? Colors.white12 : Colors.grey.shade200;

  Color get sheetBg => isDark ? const Color(0xFF1E293B) : Colors.white;

  Color get handleBar =>
      isDark ? Colors.white24 : Colors.grey.shade300;

  /// Input / search field text (always readable on [fieldBg] / [surface]).
  Color get inputText => isDark ? Colors.white : const Color(0xFF1F2937);

  Color get inputHint =>
      isDark ? Colors.white54 : const Color(0xFF9CA3AF);

  /// App headers — matches bottom nav green.
  static const Color headerBackground = AppColors.navBar;
}

extension AppThemeColorsX on BuildContext {
  AppThemeColors get appColors => AppThemeColors._(this);
}
