import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: isDiscount
                  ? Colors.green[600]
                  : isHighlighted
                      ? Colors.green[700]
                      : Colors.grey[600],
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                fontSize: isHighlighted ? 16 : 14,
                color: isDiscount
                    ? Colors.green[600]
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
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
              fontSize: isHighlighted ? 18 : 14,
              color: isDiscount
                  ? Colors.green[600]
                  : isHighlighted
                      ? Colors.green[700]
                      : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
