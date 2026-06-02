import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/widgets/order_threshold_promo_banner.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact checkout footer: promo progress, order total, and checkout action.
class CartCheckoutBottomBar extends StatelessWidget {
  const CartCheckoutBottomBar({
    super.key,
    required this.subtotal,
    required this.selectedQuantity,
    required this.selectedLineCount,
    required this.totalLineCount,
    required this.checkoutButton,
  });

  final double subtotal;
  final int selectedQuantity;
  final int selectedLineCount;
  final int totalLineCount;
  final Widget checkoutButton;

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _greenBorder = Color(0xFFBBEAD3);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _ink = Color(0xFF1F2937);

  String get _itemsLabel {
    if (totalLineCount != selectedLineCount) {
      return '$selectedLineCount of $totalLineCount selected';
    }
    if (selectedQuantity == 1) return '1 item';
    return '$selectedQuantity items';
  }

  @override
  Widget build(BuildContext context) {
    final amount = subtotal.toStringAsFixed(2);
    final whole = amount.split('.').first;
    final cents = amount.split('.').last;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrderThresholdPromoCartInfo(subtotal: subtotal),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4FAF7),
                      Color(0xFFEEF9F3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _greenBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Order total',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryDark,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Text(
                                        _itemsLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: _muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      'GHS',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      whole,
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                        height: 1,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    Text(
                                      '.$cents',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _muted,
                                        height: 1,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Excludes delivery fees',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: _muted,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 148, child: checkoutButton),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
