import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isHighlighted ? 19 : 17,
              color: isDiscount
                  ? AppColors.primary
                  : isHighlighted
                      ? AppColors.primaryDark
                      : Colors.grey[600],
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                fontSize: isHighlighted ? 14 : 12,
                color: isDiscount
                    ? AppColors.primary
                    : isHighlighted
                        ? Colors.grey[800]
                        : Colors.grey[700],
              ),
            ),
          ),
          Text(
            isDiscount
                ? '-GHS ${value.abs().toStringAsFixed(2)}'
                : 'GHS ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
              fontSize: isHighlighted ? 16 : 13,
              color: isDiscount
                  ? AppColors.primary
                  : isHighlighted
                      ? AppColors.primary
                      : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
