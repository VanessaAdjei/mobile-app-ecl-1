import 'package:flutter/material.dart';

/// Shared card styling for payment information sections.
abstract final class PaymentSectionStyle {
  static const margin = EdgeInsets.symmetric(horizontal: 12);
  static const padding = EdgeInsets.all(14);
  static const radius = 15.0;
  static const innerRadius = 11.0;
  static const borderColor = Color(0xFFE5E7EB);
  static const shadowColor = Color(0x12000000);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );
}
