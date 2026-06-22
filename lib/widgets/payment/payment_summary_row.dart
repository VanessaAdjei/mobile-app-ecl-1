import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';

/// Single line in the payment bill breakdown.
class PaymentSummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isHighlighted;
  final bool isDiscount;
  final bool isFree;
  final IconData? icon;

  const PaymentSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.isDiscount = false,
    this.isFree = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final dotColor = isDiscount || isFree
        ? AppColors.primary
        : isHighlighted
            ? AppColors.primary
            : t.muted;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isHighlighted ? 1 : 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isHighlighted ? 18 : 15,
              color: dotColor,
            ),
            const SizedBox(width: 8),
          ] else if (!isHighlighted) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                fontSize: isHighlighted ? 14 : 13,
                color: isDiscount
                    ? AppColors.primary
                    : isHighlighted
                        ? t.ink
                        : t.muted,
              ),
            ),
          ),
          if (isFree)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    AppColors.primary.withValues(alpha: t.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'FREE',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            Text(
              isDiscount
                  ? '− GHS ${value.abs().toStringAsFixed(2)}'
                  : 'GHS ${value.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                fontSize: isHighlighted ? 20 : 13,
                color: isDiscount
                    ? AppColors.primary
                    : isHighlighted
                        ? AppColors.primary
                        : t.ink,
                letterSpacing: isHighlighted ? -0.4 : 0,
              ),
            ),
        ],
      ),
    );
  }
}
