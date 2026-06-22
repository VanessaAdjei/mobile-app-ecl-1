import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_theme_colors.dart';
import 'payment_section_style.dart';

/// Delivery or pickup details on the payment screen.
class PaymentDeliveryDetailsCard extends StatelessWidget {
  final String? deliveryAddress;
  final String? contactNumber;
  final String deliveryOption;
  final bool deliveryIsFree;

  const PaymentDeliveryDetailsCard({
    super.key,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption = 'Delivery',
    this.deliveryIsFree = false,
    this.embedded = false,
  });

  final bool embedded;

  bool get _isDelivery => deliveryOption.toLowerCase().trim() == 'delivery';

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final accent = PaymentSectionAccent.delivery(context);
    final address = deliveryAddress?.trim() ?? '';
    final contact = contactNumber?.trim() ?? '';
    final hasAddress = _isDelivery && address.isNotEmpty;
    final hasContact = contact.isNotEmpty;
    final hasDetails = hasAddress || hasContact || !_isDelivery;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaymentSectionHeader(
          eyebrow: _isDelivery ? 'Delivery' : 'Pickup',
          title: _isDelivery ? 'Delivering to' : 'Collecting in store',
          icon: _isDelivery
              ? Icons.local_shipping_rounded
              : Icons.storefront_rounded,
          accent: accent,
          compact: embedded,
          trailing: _isDelivery && deliveryIsFree ? 'Free delivery' : null,
        ),
        SizedBox(height: embedded ? 8 : 10),
        if (hasDetails)
          Container(
            padding: EdgeInsets.all(embedded ? 0 : 10),
            decoration: embedded
                ? null
                : PaymentSectionStyle.innerPanelDecoration(
                    context,
                    accent: accent,
                  ),
            child: Column(
              children: [
                if (hasAddress)
                  _DetailLine(
                    icon: Icons.place_rounded,
                    value: address,
                    accent: accent,
                  ),
                if (hasAddress && hasContact) ...[
                  const SizedBox(height: 8),
                  PaymentSectionStyle.sectionDivider(context),
                  const SizedBox(height: 8),
                ],
                if (hasContact)
                  _DetailLine(
                    icon: Icons.phone_rounded,
                    value: contact,
                    accent: accent,
                  ),
                if (!_isDelivery) ...[
                  if (hasAddress || hasContact) ...[
                    const SizedBox(height: 10),
                    PaymentSectionStyle.sectionDivider(context),
                    const SizedBox(height: 10),
                  ],
                  _DetailLine(
                    icon: Icons.inventory_2_outlined,
                    value:
                        'We will notify you when your order is ready for pickup.',
                    accent: accent,
                  ),
                ],
              ],
            ),
          )
        else
          Text(
            _isDelivery
                ? 'Delivery details not available'
                : 'Pickup details not available',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: t.inputHint,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );

    if (embedded) return content;

    return PaymentSectionCard(
      accent: accent,
      child: content,
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final PaymentSectionAccent accent;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.tint,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: accent.border?.withValues(alpha: 0.5) ?? t.border,
            ),
          ),
          child: Icon(icon, size: 16, color: accent.gradient.last),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: t.ink,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
