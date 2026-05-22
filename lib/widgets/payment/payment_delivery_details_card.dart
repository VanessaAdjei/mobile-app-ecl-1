import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Delivery address and contact on the payment information screen.
class PaymentDeliveryDetailsCard extends StatelessWidget {
  final String? deliveryAddress;
  final String? contactNumber;

  const PaymentDeliveryDetailsCard({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
  });

  static const Color _accent = Color(0xFF1B5E20);
  static const Color _accentMid = Color(0xFF2E7D32);
  static const Color _accentLight = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final address = deliveryAddress?.trim() ?? '';
    final contact = contactNumber?.trim() ?? '';
    final hasAddress = address.isNotEmpty;
    final hasContact = contact.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(hasDetails: hasAddress || hasContact),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
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
                      if (hasAddress && hasContact) const SizedBox(height: 6),
                      if (hasContact)
                        _DetailTile(
                          icon: Icons.call_rounded,
                          iconColor: _accentMid,
                          iconBg: _accentLight,
                          label: 'Contact number',
                          value: contact,
                        ),
                    ],
                  )
                : Text(
                    'Delivery address not available',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
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
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PaymentDeliveryDetailsCard._accent,
            PaymentDeliveryDetailsCard._accentMid,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering to',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hasDetails
                      ? 'Review before you pay'
                      : 'Add details on the previous step',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EDEA)),
      ),
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
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1F1C),
                    height: 1.35,
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
