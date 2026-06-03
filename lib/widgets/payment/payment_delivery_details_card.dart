import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
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
    final address = deliveryAddress?.trim() ?? '';
    final contact = contactNumber?.trim() ?? '';
    final hasAddress = address.isNotEmpty;
    final hasContact = contact.isNotEmpty;

    return Container(
      margin: PaymentSectionStyle.margin,
      decoration: PaymentSectionStyle.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(hasDetails: hasAddress || hasContact),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: hasAddress || hasContact
                ? Column(
                    children: [
                      if (hasAddress)
                        _DetailTile(
                          icon: Icons.place_rounded,
                          iconColor: const Color(0xFF1565C0),
                          iconBg: const Color(0xFFE3F2FD),
                          label: 'Delivery address',
                          value: address,
                        ),
                      if (hasAddress && hasContact) const SizedBox(height: 10),
                      if (hasContact)
                        _DetailTile(
                          icon: Icons.call_rounded,
                          iconColor: AppColors.primaryDark,
                          iconBg: const Color(0xFFEEF9F3),
                          label: 'Contact number',
                          value: contact,
                        ),
                    ],
                  )
                : Text(
                    'Delivery address not available',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasDetails;

  const _Header({required this.hasDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering to',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                Text(
                  hasDetails
                      ? 'Review before you pay'
                      : 'Add details on the previous step',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF7),
        borderRadius: BorderRadius.circular(PaymentSectionStyle.innerRadius),
        border: Border.all(color: PaymentSectionStyle.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1F1C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
