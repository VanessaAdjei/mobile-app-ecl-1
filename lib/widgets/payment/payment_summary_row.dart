import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';

/// Single line in the payment bill breakdown.
class PaymentSummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isHighlighted;
  final IconData? icon;
  final bool isDiscount;

  const PaymentSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.icon,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isHighlighted ? 5 : 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isHighlighted ? 22 : 20,
              color: isDiscount
                  ? AppColors.primary
                  : isHighlighted
                      ? (t.isDark ? AppColors.primaryLight : AppColors.primaryDark)
                      : t.muted,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                fontSize: isHighlighted ? 15 : 13,
                color: isDiscount
                    ? AppColors.primary
                    : isHighlighted
                        ? t.ink
                        : t.muted,
              ),
            ),
          ),
          Text(
            isDiscount
                ? '-GHS ${value.abs().toStringAsFixed(2)}'
                : 'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
              fontSize: isHighlighted ? 18 : 14,
              color: isDiscount
                  ? AppColors.primary
                  : isHighlighted
                      ? AppColors.primary
                      : t.ink,
            ),
          ),
        ],
      ),
    );
  }
}
