import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// On-screen notice when the store confirms an order.
class OrderConfirmedOnScreenBanner extends StatelessWidget {
  final String orderReference;
  final VoidCallback? onDismiss;

  const OrderConfirmedOnScreenBanner({
    super.key,
    required this.orderReference,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: PostCheckoutDesign.surface(context),
        borderRadius: BorderRadius.circular(PostCheckoutDesign.radiusMd),
        border: Border.all(
          color: PostCheckoutDesign.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: PostCheckoutDesign.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PostCheckoutDesign.accentLight(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: PostCheckoutDesign.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order confirmed',
                  style: GoogleFonts.poppins(
                    color: PostCheckoutDesign.ink(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orderReference.isEmpty
                      ? 'We\'re preparing your order now.'
                      : 'Order #$orderReference is being prepared.',
                  style: GoogleFonts.poppins(
                    color: PostCheckoutDesign.muted(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: context.appColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
