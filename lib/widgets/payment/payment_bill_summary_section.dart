import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import 'payment_section_style.dart';
import 'payment_summary_row.dart';
import '../order_threshold_promo_banner.dart';

/// Bill breakdown + promo code on the payment information screen.
class PaymentBillSummarySection extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final bool showDeliveryFee;
  final double emergencyOrderFee;
  final double discountAmount;
  final bool useRawDeliveryFee;
  final bool forceFreeDelivery;
  final bool lockPromoEditing;
  final String? appliedPromoCode;
  final String? promoError;
  final bool isApplyingPromo;
  final TextEditingController promoCodeController;
  final VoidCallback onApplyPromo;
  final VoidCallback onRemovePromo;

  const PaymentBillSummarySection({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.showDeliveryFee,
    required this.emergencyOrderFee,
    required this.discountAmount,
    this.useRawDeliveryFee = false,
    this.forceFreeDelivery = false,
    this.lockPromoEditing = false,
    required this.appliedPromoCode,
    required this.promoError,
    required this.isApplyingPromo,
    required this.promoCodeController,
    required this.onApplyPromo,
    required this.onRemovePromo,
  });

  double get _displayDeliveryFee {
    if (forceFreeDelivery) return 0.0;
    if (useRawDeliveryFee) return deliveryFee;
    return OrderThresholdPromoBanner.displayDeliveryFee(subtotal, deliveryFee);
  }

  double get _total =>
      subtotal + _displayDeliveryFee + emergencyOrderFee - discountAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: PaymentSectionStyle.margin,
      padding: PaymentSectionStyle.padding,
      decoration: PaymentSectionStyle.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bill',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OrderThresholdPromoBanner(compact: true, subtotal: subtotal),
          const SizedBox(height: 6),
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
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF7),
              borderRadius:
                  BorderRadius.circular(PaymentSectionStyle.innerRadius),
              border: Border.all(color: PaymentSectionStyle.borderColor),
            ),
            child: Column(
              children: [
                PaymentSummaryRow(
                  label: 'Subtotal',
                  value: subtotal,
                  icon: Icons.shopping_cart_outlined,
                ),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  PaymentSummaryRow(
                    label: 'Discount',
                    value: -discountAmount,
                    icon: Icons.local_offer,
                    isDiscount: true,
                  ),
                ],
                if (showDeliveryFee && _displayDeliveryFee > 0) ...[
                  const SizedBox(height: 4),
                  PaymentSummaryRow(
                    label: 'Delivery fee',
                    value: _displayDeliveryFee,
                    icon: Icons.local_shipping_outlined,
                  ),
                ],
                if (emergencyOrderFee > 0) ...[
                  const SizedBox(height: 4),
                  PaymentSummaryRow(
                    label: 'Urgent order fee',
                    value: emergencyOrderFee,
                    icon: Icons.flash_on,
                  ),
                ],
                Divider(height: 16, thickness: 1, color: Colors.grey[300]),
                PaymentSummaryRow(
                  label: 'Total',
                  value: _total,
                  isHighlighted: true,
                  icon: Icons.payment,
                ),
              ],
            ),
          ),
        ],
      ),
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
    final hasApplied = appliedPromoCode != null || (lockPromoEditing && discountAmount > 0);
    final lockedLabel = appliedPromoCode ?? 'Server pricing';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF9F3),
        borderRadius: BorderRadius.circular(PaymentSectionStyle.innerRadius),
        border: Border.all(color: const Color(0xFFBBEAD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.local_offer_outlined,
                  color: AppColors.primaryDark, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: hasApplied
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              lockPromoEditing ? lockedLabel : appliedPromoCode!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 13,
                          ),
                        ],
                      )
                    : TextField(
                        enabled: !lockPromoEditing,
                        controller: promoCodeController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Promo code',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFBBEAD3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFBBEAD3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                        ),
                        style: const TextStyle(fontSize: 10, height: 1.2),
                      ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 26,
                child: TextButton(
                  onPressed: lockPromoEditing
                      ? null
                      : hasApplied
                          ? onRemovePromo
                          : (isApplyingPromo ? null : onApplyPromo),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        lockPromoEditing
                            ? Colors.grey.shade200
                            : hasApplied
                                ? Colors.red[50]
                                : AppColors.primary,
                    foregroundColor:
                        lockPromoEditing
                            ? Colors.grey.shade700
                            : hasApplied
                                ? Colors.red[700]
                                : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isApplyingPromo
                      ? const SizedBox(
                          width: 11,
                          height: 11,
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
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (lockPromoEditing) ...[
            const SizedBox(height: 2),
            Text(
              'Pricing is set from delivery quote.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (promoError != null) ...[
            const SizedBox(height: 3),
            Text(
              promoError!,
              style: TextStyle(color: Colors.red[600], fontSize: 9, height: 1.2),
            ),
          ] else if (hasApplied && discountAmount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Saved GHS ${discountAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
