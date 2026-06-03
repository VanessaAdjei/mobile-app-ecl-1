import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTrackingDeliveryCard extends StatelessWidget {
  const OrderTrackingDeliveryCard({
    super.key,
    required this.isPickup,
    required this.address,
    required this.contact,
    required this.method,
    required this.accent,
  });

  final bool isPickup;
  final String address;
  final String contact;
  final String method;
  final Color accent;

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
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPickup
                              ? Icons.storefront_outlined
                              : Icons.local_shipping_outlined,
                          size: 18,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPickup ? 'Pickup details' : 'Delivery details',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PostCheckoutDesign.ink,
                                letterSpacing: -0.25,
                              ),
                            ),
                            Text(
                              isPickup
                                  ? 'Where to collect your order'
                                  : 'Where we are bringing your order',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PostCheckoutDesign.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: isPickup ? 'Pickup location' : 'Address',
                    value: address,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Contact',
                    value: contact,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: isPickup
                        ? Icons.store_mall_directory_outlined
                        : Icons.schedule_send_outlined,
                    label: 'Method',
                    value: method,
                    accent: accent,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accent.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: PostCheckoutDesign.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PostCheckoutDesign.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
