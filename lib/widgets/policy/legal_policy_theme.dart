import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';

/// Shared light/dark tokens for legal & policy document pages.
class LegalPolicyTheme {
  LegalPolicyTheme._(this._colors);

  final AppThemeColors _colors;

  factory LegalPolicyTheme.of(BuildContext context) =>
      LegalPolicyTheme._(context.appColors);

  bool get isDark => _colors.isDark;

  Color get pageBg => _colors.pageBg;

  Color get cardBg => isDark ? const Color(0xFF141C2B) : _colors.surface;

  Color get titleInk => _colors.ink;

  Color get bodyText =>
      isDark ? Colors.white.withValues(alpha: 0.84) : const Color(0xFF374151);

  Color get subtitleInk => _colors.muted;

  Color get border => _colors.border;

  Color get bulletPanelBg => isDark
      ? AppColors.primary.withValues(alpha: 0.1)
      : const Color(0xFFF4FAF7);

  Color get bulletPanelBorder => isDark
      ? AppColors.primary.withValues(alpha: 0.24)
      : const Color(0xFFDCEEE4);

  Color get cardShadow => isDark
      ? Colors.black.withValues(alpha: 0.32)
      : AppColors.accent.withValues(alpha: 0.06);

  Color get introShadow => isDark
      ? Colors.black.withValues(alpha: 0.28)
      : AppColors.accent.withValues(alpha: 0.07);

  Color get footerMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  Color get badgeTintBg => isDark
      ? AppColors.primary.withValues(alpha: 0.18)
      : AppColors.primary.withValues(alpha: 0.12);

  Color get badgeTintInk =>
      isDark ? AppColors.primaryLight : AppColors.accent;
}
