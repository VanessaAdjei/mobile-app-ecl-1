import 'package:flutter/material.dart';

/// Central app colors. Use these instead of scattered hex codes.
class AppColors {
  AppColors._();

  /// Primary brand green - main buttons, links, accents
  static const Color primary = Color(0xFF20AF67);

  /// Darker green - secondary accents
  static const Color primaryDark = Color(0xFF1A8F55);

  /// Bottom nav + homepage header (Material green 700).
  static const Color navBar = Color(0xFF388E3C);

  /// Lighter green - highlights
  static const Color primaryLight = Color(0xFF4BCF8F);

  /// WhatsApp-style green (chat, messaging)
  static const Color whatsapp = Color(0xFF25D366);

  /// Material green accent (some legacy screens)
  static const Color accent = Color(0xFF2E7D32);

  /// Cart item-count badge (vivid red for green nav bar / headers).
  static const Color cartBadge = Color(0xFFFF5252);
}
