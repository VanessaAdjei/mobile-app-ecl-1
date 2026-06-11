import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../utils/app_theme_colors.dart';
import 'payment_section_style.dart';

/// Delivery address and contact on the payment information screen.
class PaymentDeliveryDetailsCard extends StatelessWidget {
  final String? deliveryAddress;
  final String? contactNumber;

  const PaymentDeliveryDetailsCard({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final address = deliveryAddress?.trim() ?? '';
    final contact = contactNumber?.trim() ?? '';
    final hasAddress = address.isNotEmpty;
    final hasContact = contact.isNotEmpty;

    final hasDetails = hasAddress || hasContact;

    return PaymentSectionCard(
      accentStripe: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentSectionHeader(
            icon: Icons.local_shipping_rounded,
            title: 'Delivering to',
            subtitle: hasDetails ? null : 'Add on delivery step',
            accentColors: const [Color(0xFF42A5F5), Color(0xFF1565C0)],
          ),
          const SizedBox(height: 8),
          hasDetails
              ? Column(
                  children: [
                    if (hasAddress)
                      _DetailTile(
                        icon: Icons.place_rounded,
                        iconColor: t.isDark
                            ? Colors.blue.shade300
                            : const Color(0xFF1565C0),
                        iconBg: t.isDark
                            ? Colors.blue.withValues(alpha: 0.18)
                            : const Color(0xFFE3F2FD),
                        label: 'Delivery address',
                        value: address,
                      ),
                    if (hasAddress && hasContact) const SizedBox(height: 5),
                    if (hasContact)
                      _DetailTile(
                        icon: Icons.call_rounded,
                        iconColor: t.isDark
                            ? AppColors.primaryLight
                            : AppColors.primaryDark,
                        iconBg: t.accentTint,
                        label: 'Contact number',
                        value: contact,
                      ),
                  ],
                )
              : Text(
                  'Delivery address not available',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: t.inputHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: PaymentSectionStyle.innerPanelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: t.muted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: t.ink,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
