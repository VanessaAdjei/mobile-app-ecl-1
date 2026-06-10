import 'package:eclapp/widgets/checkout_progress_stepper.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top bar for post-checkout order tracking.
class PostCheckoutHeader extends StatelessWidget {
  const PostCheckoutHeader({
    super.key,
    required this.onBack,
    this.orderReference,
    this.title = 'Your order',
  });

  final VoidCallback onBack;
  final String? orderReference;
  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final ref = orderReference?.trim();
    final hasRef = ref != null && ref.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: PostCheckoutDesign.surface(context),
        border: Border(bottom: BorderSide(color: PostCheckoutDesign.border(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: PostCheckoutDesign.ink(context),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: PostCheckoutDesign.ink(context),
                          height: 1.2,
                        ),
                      ),
                      if (hasRef)
                        Text(
                          'Order #$ref',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: PostCheckoutDesign.muted(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasRef)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: PostCheckoutDesign.accentLight(context),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: PostCheckoutDesign.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                          color: PostCheckoutDesign.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PostCheckoutDesign.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: const CheckoutProgressStepper(
              compact: true,
              lightSurface: true,
              steps: ['Cart', 'Delivery', 'Payment', 'Confirmation'],
              activeStep: 4,
              completedSteps: {1, 2, 3},
            ),
          ),
        ],
      ),
    );
  }
}
