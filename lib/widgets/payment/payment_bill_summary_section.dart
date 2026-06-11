import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/checkout_order_totals.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_extension.dart';
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
  final bool compact;

  const PaymentBillSummarySection({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.showDeliveryFee,
    required this.emergencyOrderFee,
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
    this.compact = false,
  });

  double get _displayDeliveryFee {
    if (forceFreeDelivery) return 0.0;
    if (useRawDeliveryFee) return deliveryFee;
    return OrderThresholdPromoBanner.displayDeliveryFee(subtotal, deliveryFee);
  }

  double get _total => CheckoutOrderTotals(
        merchandiseSubtotal: subtotal,
        discount: discountAmount,
        deliveryFee: deliveryFee,
        emergencyOrderFee: emergencyOrderFee,
        runningSubtotal: runningSubtotal,
        shippingFree: forceFreeDelivery,
        isDelivery: showDeliveryFee,
      ).total;

  @override
  Widget build(BuildContext context) {
    final blockGap = compact ? context.rs(8) : context.rs(10);
    final innerPanelPadding = compact ? context.rs(10) : context.rs(12);
    final rowGap = compact ? 5.0 : 8.0;

    return PaymentSectionCard(
      accentStripe: const Color(0xFF2E7D32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PaymentSectionHeader(
            icon: Icons.payments_outlined,
            title: 'Bill summary',
            subtitle: 'Promo & fees',
            accentColors: [Color(0xFF66BB6A), AppColors.primaryDark],
          ),
          SizedBox(height: compact ? 8 : 11),
          OrderThresholdPromoBanner(compact: true, subtotal: subtotal),
          SizedBox(height: blockGap),
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
          SizedBox(height: blockGap),
          Container(
            padding: EdgeInsets.all(innerPanelPadding),
            decoration: PaymentSectionStyle.innerPanelDecoration(context),
            child: Column(
              children: [
                PaymentSummaryRow(
                  label: 'Subtotal',
                  value: subtotal,
                  icon: Icons.shopping_cart_outlined,
                ),
                if (discountAmount > 0) ...[
                  SizedBox(height: rowGap),
                  PaymentSummaryRow(
                    label: 'Discount',
                    value: -discountAmount,
                    icon: Icons.local_offer,
                    isDiscount: true,
                  ),
                ],
                if (showDeliveryFee && _displayDeliveryFee > 0) ...[
                  SizedBox(height: rowGap),
                  PaymentSummaryRow(
                    label: 'Delivery fee',
                    value: _displayDeliveryFee,
                    icon: Icons.local_shipping_outlined,
                  ),
                ],
                if (emergencyOrderFee > 0) ...[
                  SizedBox(height: rowGap),
                  PaymentSummaryRow(
                    label: 'xPress order fee',
                    value: emergencyOrderFee,
                    icon: Icons.flash_on,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: PaymentSectionStyle.totalPanelDecoration(context),
            child: PaymentSummaryRow(
              label: 'Total due',
              value: _total,
              isHighlighted: true,
              icon: Icons.account_balance_wallet_outlined,
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
    final t = context.appColors;
    final hasApplied =
        appliedPromoCode != null || (lockPromoEditing && discountAmount > 0);
    final lockedLabel = appliedPromoCode ?? 'Server pricing';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: PaymentSectionStyle.accentPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.local_offer_outlined,
                color:
                    t.isDark ? AppColors.primaryLight : AppColors.primaryDark,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: hasApplied
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              lockPromoEditing
                                  ? lockedLabel
                                  : appliedPromoCode!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      )
                    : TextField(
                        enabled: !lockPromoEditing,
                        controller: promoCodeController,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: t.inputText,
                        ),
                        cursorColor: t.inputText,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Promo code',
                          hintStyle: TextStyle(
                            color: t.inputHint,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: t.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: t.accentBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: t.accentBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
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
                                ? Colors.red.withValues(alpha: 0.18)
                                : Colors.red.shade50)
                            : AppColors.primary,
                    foregroundColor: lockPromoEditing
                        ? t.muted
                        : hasApplied
                            ? (t.isDark
                                ? Colors.red.shade300
                                : Colors.red.shade700)
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
                            fontSize: 11,
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
                color: t.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (promoError != null) ...[
            const SizedBox(height: 4),
            Text(
              promoError!,
              style: TextStyle(
                color: t.isDark ? Colors.red.shade300 : Colors.red.shade600,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ] else if (hasApplied && discountAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Saved GHS ${discountAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color:
                    t.isDark ? AppColors.primaryLight : AppColors.primaryDark,
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
