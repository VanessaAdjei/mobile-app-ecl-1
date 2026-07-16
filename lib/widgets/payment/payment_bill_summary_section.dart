import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';
import 'payment_section_style.dart';
import 'payment_summary_row.dart';
import '../order_threshold_promo_banner.dart';

/// Bill breakdown + promo code on the payment screen.
class PaymentBillSummarySection extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final bool showDeliveryFee;
  final double emergencyOrderFee;
  /// When true, show the xPress row even if [emergencyOrderFee] is 0.
  final bool showEmergencyOrderFee;
  final double discountAmount;
  final double? runningSubtotal;
  final bool useRawDeliveryFee;
  final bool forceFreeDelivery;
  final bool lockPromoEditing;
  final String? appliedPromoCode;
  final String? promoError;
  final bool isApplyingPromo;
  final TextEditingController promoCodeController;
  final VoidCallback onApplyPromo;
  final VoidCallback onRemovePromo;
  final bool embedded;

  const PaymentBillSummarySection({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.showDeliveryFee,
    required this.emergencyOrderFee,
    this.showEmergencyOrderFee = false,
    required this.discountAmount,
    this.runningSubtotal,
    this.useRawDeliveryFee = false,
    this.forceFreeDelivery = false,
    this.lockPromoEditing = false,
    required this.appliedPromoCode,
    required this.promoError,
    required this.isApplyingPromo,
    required this.promoCodeController,
    required this.onApplyPromo,
    required this.onRemovePromo,
    this.embedded = false,
  });

  double get _displayDeliveryFee {
    if (forceFreeDelivery) return 0.0;
    if (useRawDeliveryFee) return deliveryFee;
    return OrderThresholdPromoBanner.displayDeliveryFee(subtotal, deliveryFee);
  }

  bool get _isDeliveryFree =>
      showDeliveryFee && (forceFreeDelivery || _displayDeliveryFee <= 0);

  @override
  Widget build(BuildContext context) {
    final accent = PaymentSectionAccent.bill(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PaymentSectionHeader(
          eyebrow: 'Payment',
          title: 'Bill summary',
          icon: Icons.receipt_long_rounded,
          accent: accent,
          compact: embedded,
        ),
        SizedBox(height: embedded ? 8 : 10),
        OrderThresholdPromoBanner(compact: true, subtotal: subtotal),
        const SizedBox(height: 8),
        _PromoCodeBlock(
          lockPromoEditing: lockPromoEditing,
          appliedPromoCode: appliedPromoCode,
          promoError: promoError,
          isApplyingPromo: isApplyingPromo,
          promoCodeController: promoCodeController,
          discountAmount: discountAmount,
          onApplyPromo: onApplyPromo,
          onRemovePromo: onRemovePromo,
        ),
        SizedBox(height: embedded ? 10 : 12),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: embedded ? 0 : 10,
            vertical: embedded ? 4 : 8,
          ),
          decoration: embedded
              ? null
              : PaymentSectionStyle.innerPanelDecoration(
                  context,
                  accent: accent,
                ),
          child: Column(
            children: [
              PaymentSummaryRow(
                label: 'Subtotal',
                value: subtotal,
                icon: Icons.shopping_cart_outlined,
              ),
              if (discountAmount > 0) ...[
                const SizedBox(height: 6),
                PaymentSummaryRow(
                  label: 'Discount',
                  value: -discountAmount,
                  isDiscount: true,
                  icon: Icons.local_offer_outlined,
                ),
              ],
              if (showDeliveryFee) ...[
                const SizedBox(height: 6),
                PaymentSummaryRow(
                  label: _isDeliveryFree ? 'Delivery' : 'Delivery fee',
                  value: _displayDeliveryFee,
                  isFree: _isDeliveryFree,
                  icon: Icons.local_shipping_outlined,
                ),
              ],
              if (showEmergencyOrderFee || emergencyOrderFee > 0) ...[
                const SizedBox(height: 6),
                PaymentSummaryRow(
                  label: 'xPress order fee',
                  value: emergencyOrderFee,
                  isFree: emergencyOrderFee <= 0,
                  icon: Icons.bolt_rounded,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (embedded) return content;

    return PaymentSectionCard(
      accent: accent,
      child: content,
    );
  }
}

class _PromoCodeBlock extends StatelessWidget {
  final bool lockPromoEditing;
  final String? appliedPromoCode;
  final String? promoError;
  final bool isApplyingPromo;
  final TextEditingController promoCodeController;
  final double discountAmount;
  final VoidCallback onApplyPromo;
  final VoidCallback onRemovePromo;

  const _PromoCodeBlock({
    required this.lockPromoEditing,
    required this.appliedPromoCode,
    required this.promoError,
    required this.isApplyingPromo,
    required this.promoCodeController,
    required this.discountAmount,
    required this.onApplyPromo,
    required this.onRemovePromo,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final hasApplied =
        appliedPromoCode != null || (lockPromoEditing && discountAmount > 0);
    final lockedLabel = appliedPromoCode ?? 'Server pricing';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: PaymentSectionStyle.innerPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: hasApplied
                    ? Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lockPromoEditing
                                  ? lockedLabel
                                  : appliedPromoCode!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : TextField(
                        enabled: !lockPromoEditing,
                        controller: promoCodeController,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: t.inputText,
                        ),
                        cursorColor: AppColors.primary,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Promo code',
                          hintStyle: GoogleFonts.poppins(
                            color: t.inputHint,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: lockPromoEditing
                      ? null
                      : hasApplied
                          ? onRemovePromo
                          : (isApplyingPromo ? null : onApplyPromo),
                  style: TextButton.styleFrom(
                    backgroundColor: lockPromoEditing
                        ? t.fieldBg
                        : hasApplied
                            ? (t.isDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.red.shade50)
                            : AppColors.primary,
                    foregroundColor: lockPromoEditing
                        ? t.muted
                        : hasApplied
                            ? (t.isDark
                                ? Colors.red.shade300
                                : Colors.red.shade700)
                            : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isApplyingPromo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          lockPromoEditing
                              ? 'Locked'
                              : hasApplied
                                  ? 'Remove'
                                  : 'Apply',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (lockPromoEditing) ...[
            const SizedBox(height: 6),
            Text(
              'Pricing is set from your delivery quote.',
              style: GoogleFonts.poppins(
                color: t.muted,
                fontSize: 11,
              ),
            ),
          ] else if (promoError != null) ...[
            const SizedBox(height: 6),
            Text(
              promoError!,
              style: GoogleFonts.poppins(
                color: t.isDark ? Colors.red.shade300 : Colors.red.shade600,
                fontSize: 11,
              ),
            ),
          ] else if (hasApplied && discountAmount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'You save GHS ${discountAmount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
