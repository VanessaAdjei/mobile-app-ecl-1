import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OrderTrackingStatusCard extends StatelessWidget {
  const OrderTrackingStatusCard({
    super.key,
    required this.stageLabel,
    required this.badgeLabel,
    required this.orderRef,
    required this.isPickup,
    required this.isDelivered,
    required this.isFailed,
    required this.accent,
    this.placedAt,
  });

  final String stageLabel;
  final String badgeLabel;
  final String orderRef;
  final bool isPickup;
  final bool isDelivered;
  final bool isFailed;
  final Color accent;
  final DateTime? placedAt;

  @override
  Widget build(BuildContext context) {
    if (isFailed) {
      return _FailedCard(
        stageLabel: stageLabel,
        badgeLabel: badgeLabel,
        orderRef: orderRef,
        placedAt: placedAt,
      );
    }

    if (isDelivered) {
      return _DeliveredCard(
        stageLabel: stageLabel,
        badgeLabel: badgeLabel,
        orderRef: orderRef,
        isPickup: isPickup,
        accent: accent,
      );
    }

    return Container(
      width: double.infinity,
      decoration: PostCheckoutDesign.compactCard(context),
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
                      Icon(
                        isPickup
                            ? Icons.storefront_outlined
                            : Icons.local_shipping_outlined,
                        size: 14,
                        color: PostCheckoutDesign.muted(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPickup ? 'Pickup order' : 'Delivery order',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: PostCheckoutDesign.muted(context),
                        ),
                      ),
                      const Spacer(),
                      _StatusBadge(label: badgeLabel, accent: accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForLabel(stageLabel, isPickup),
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: PostCheckoutDesign.ink(context),
                                height: 1.2,
                                letterSpacing: -0.25,
                              ),
                            ),
                            if (placedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEE, MMM d · h:mm a')
                                    .format(placedAt!),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: PostCheckoutDesign.muted(context),
                                ),
                              ),
                            ],
                            if (orderRef.isNotEmpty &&
                                orderRef.toUpperCase() != 'N/A') ...[
                              const SizedBox(height: 6),
                              _OrderIdRow(reference: orderRef, accent: accent),
                            ],
                          ],
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

  static IconData _iconForLabel(String label, bool isPickup) {
    final lower = label.toLowerCase();
    if (lower.contains('arrived') || lower.contains('at store')) {
      return Icons.place_rounded;
    }
    if (lower.contains('deliver') || lower.contains('picked')) {
      return Icons.check_circle_rounded;
    }
    if (lower.contains('pickup') || lower.contains('ready')) {
      return Icons.store_mall_directory_rounded;
    }
    if (lower.contains('dispatch')) {
      return Icons.inventory_2_outlined;
    }
    if (lower.contains('delivery') || lower.contains('out for')) {
      return Icons.delivery_dining_rounded;
    }
    if (lower.contains('confirm') || lower.contains('paid')) {
      return Icons.verified_rounded;
    }
    return isPickup
        ? Icons.storefront_outlined
        : Icons.local_pharmacy_rounded;
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({
    required this.stageLabel,
    required this.badgeLabel,
    required this.orderRef,
    this.placedAt,
  });

  final String stageLabel;
  final String badgeLabel;
  final String orderRef;
  final DateTime? placedAt;

  static const Color _failedAccent = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.red.shade900.withValues(alpha: 0.22)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.red.shade700
              : Colors.red.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: _failedAccent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _failedAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payment_rounded,
                      size: 22,
                      color: _failedAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Payment not completed',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: PostCheckoutDesign.ink(context),
                                  letterSpacing: -0.25,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _failedAccent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                badgeLabel.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stageLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: PostCheckoutDesign.muted(context),
                            height: 1.35,
                          ),
                        ),
                        if (placedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d · h:mm a').format(placedAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: PostCheckoutDesign.muted(context),
                            ),
                          ),
                        ],
                        if (orderRef.isNotEmpty &&
                            orderRef.toUpperCase() != 'N/A') ...[
                          const SizedBox(height: 6),
                          _OrderIdRow(
                            reference: orderRef,
                            accent: _failedAccent,
                          ),
                        ],
                      ],
                    ),
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

class _DeliveredCard extends StatelessWidget {
  const _DeliveredCard({
    required this.stageLabel,
    required this.badgeLabel,
    required this.orderRef,
    required this.isPickup,
    required this.accent,
  });

  final String stageLabel;
  final String badgeLabel;
  final String orderRef;
  final bool isPickup;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final headline =
        isPickup ? 'Order collected' : 'Your order has arrived';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PostCheckoutDesign.accentLight(context).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCheckoutDesign.logoMark(
                    context,
                    size: 44,
                    borderColor: accent.withValues(alpha: 0.2),
                    overlay: PostCheckoutDesign.successCheckOverlay(size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                headline,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: PostCheckoutDesign.ink(context),
                                  letterSpacing: -0.25,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                badgeLabel.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stageLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: PostCheckoutDesign.muted(context),
                            height: 1.35,
                          ),
                        ),
                        if (orderRef.isNotEmpty &&
                            orderRef.toUpperCase() != 'N/A') ...[
                          const SizedBox(height: 6),
                          _OrderIdRow(reference: orderRef, accent: accent),
                        ],
                      ],
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OrderIdRow extends StatelessWidget {
  const _OrderIdRow({required this.reference, required this.accent});

  final String reference;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final display = reference.startsWith('#') ? reference : '#$reference';

    return Row(
      children: [
        Icon(Icons.tag_rounded, size: 12, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PostCheckoutDesign.muted(context),
            ),
          ),
        ),
      ],
    );
  }
}
