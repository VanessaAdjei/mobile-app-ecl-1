import 'package:flutter/material.dart';

import 'payment_summary_row.dart';

/// Bill breakdown + promo code on the payment information screen.
class PaymentBillSummarySection extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final bool showDeliveryFee;
  final double emergencyOrderFee;
  final double discountAmount;
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
    required this.appliedPromoCode,
    required this.promoError,
    required this.isApplyingPromo,
    required this.promoCodeController,
    required this.onApplyPromo,
    required this.onRemovePromo,
  });

  double get _total =>
      subtotal + deliveryFee + emergencyOrderFee - discountAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.green[700],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BILL',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _PromoCodeBlock(
              appliedPromoCode: appliedPromoCode,
              promoError: promoError,
              isApplyingPromo: isApplyingPromo,
              promoCodeController: promoCodeController,
              discountAmount: discountAmount,
              onApplyPromo: onApplyPromo,
              onRemovePromo: onRemovePromo,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[200]!),
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
                      icon: Icons.local_offer,
                      isDiscount: true,
                    ),
                  ],
                  if (showDeliveryFee) ...[
                    const SizedBox(height: 6),
                    PaymentSummaryRow(
                      label: 'Delivery fee',
                      value: deliveryFee,
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                  if (emergencyOrderFee > 0) ...[
                    const SizedBox(height: 6),
                    PaymentSummaryRow(
                      label: 'Urgent Order Fee',
                      value: emergencyOrderFee,
                      icon: Icons.flash_on,
                    ),
                  ],
                  Divider(height: 12, thickness: 1, color: Colors.grey[300]),
                  PaymentSummaryRow(
                    label: 'TOTAL',
                    value: _total,
                    isHighlighted: true,
                    icon: Icons.payment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCodeBlock extends StatelessWidget {
  final String? appliedPromoCode;
  final String? promoError;
  final bool isApplyingPromo;
  final TextEditingController promoCodeController;
  final double discountAmount;
  final VoidCallback onApplyPromo;
  final VoidCallback onRemovePromo;

  const _PromoCodeBlock({
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
    final hasApplied = appliedPromoCode != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.local_offer_outlined, color: Colors.blue[700], size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: hasApplied
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              appliedPromoCode!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 14,
                          ),
                        ],
                      )
                    : TextField(
                        controller: promoCodeController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Promo code',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade100),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade100),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        style: const TextStyle(fontSize: 11, height: 1.2),
                      ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
                child: TextButton(
                  onPressed: hasApplied
                      ? onRemovePromo
                      : (isApplyingPromo ? null : onApplyPromo),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        hasApplied ? Colors.red[50] : Colors.blue[600],
                    foregroundColor:
                        hasApplied ? Colors.red[700] : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isApplyingPromo
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          hasApplied ? 'Remove' : 'Apply',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (promoError != null) ...[
            const SizedBox(height: 4),
            Text(
              promoError!,
              style: TextStyle(color: Colors.red[600], fontSize: 9, height: 1.2),
            ),
          ] else if (hasApplied && discountAmount > 0) ...[
            const SizedBox(height: 3),
            Text(
              'Saved GHS ${discountAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.green[700],
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
