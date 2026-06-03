import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Subtotal, delivery fee, discount, and order total for track-order.
class OrderTrackingBillCard extends StatelessWidget {
  const OrderTrackingBillCard({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.accent,
    this.showDeliveryFee = true,
  });

  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final Color accent;
  final bool showDeliveryFee;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: PostCheckoutDesign.compactCard(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payment summary',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PostCheckoutDesign.ink,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _BillRow(label: 'Subtotal', value: subtotal),
                  if (showDeliveryFee && deliveryFee > 0.01) ...[
                    const SizedBox(height: 6),
                    _BillRow(label: 'Delivery fee', value: deliveryFee),
                  ],
                  if (discount > 0) ...[
                    const SizedBox(height: 6),
                    _BillRow(
                      label: 'Discount',
                      value: -discount,
                      valueColor: accent,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      color: PostCheckoutDesign.border,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Total paid',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PostCheckoutDesign.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'GHS ${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
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

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final double value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final display = value < 0
        ? '-GHS ${(-value).toStringAsFixed(2)}'
        : 'GHS ${value.toStringAsFixed(2)}';

    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: PostCheckoutDesign.muted,
          ),
        ),
        const Spacer(),
        Text(
          display,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? PostCheckoutDesign.ink,
          ),
        ),
      ],
    );
  }
}
