import 'package:flutter/material.dart';

/// Shared compact card styling for payment information sections.
abstract final class PaymentSectionStyle {
  static const margin = EdgeInsets.symmetric(horizontal: 14);
  static const padding = EdgeInsets.all(12);
  static const radius = 14.0;
  static const innerRadius = 10.0;
  static const borderColor = Color(0xFFE5E7EB);
  static const shadowColor = Color(0x0A000000);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      );
}
