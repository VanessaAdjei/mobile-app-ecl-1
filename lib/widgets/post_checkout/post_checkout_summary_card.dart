import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Order reference, total, and optional line items section.
class PostCheckoutSummaryCard extends StatelessWidget {
  const PostCheckoutSummaryCard({
    super.key,
    required this.orderReference,
    required this.totalAmount,
    required this.itemCount,
    this.itemsSection,
    this.accent = PostCheckoutDesign.accent,
  });

  final String orderReference;
  final double totalAmount;
  final int itemCount;
  final Widget? itemsSection;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PostCheckoutDesign.surfaceCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PostCheckoutDesign.accentLight(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order summary',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PostCheckoutDesign.ink(context),
                      ),
                    ),
                    Text(
                      itemCount > 0
                          ? '$itemCount item${itemCount == 1 ? '' : 's'}'
                          : 'Items from your cart',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: PostCheckoutDesign.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GHS ${totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Text(
                    orderReference.isNotEmpty
                        ? '#$orderReference'
                        : 'Ref pending',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: PostCheckoutDesign.muted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (itemsSection != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: PostCheckoutDesign.border(context)),
            const SizedBox(height: 8),
            itemsSection!,
          ],
        ],
      ),
    );
  }
}
