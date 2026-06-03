import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/order_tracking_model.dart';
import 'post_checkout/post_checkout_design.dart';

/// Order placed time + destination quick tiles.
class OrderTrackingEtaTiles extends StatelessWidget {
  const OrderTrackingEtaTiles({
    super.key,
    required this.order,
    this.accent,
  });

  final OrderTrackingModel order;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFF0D7A4C);
    final address = order.deliveryAddress.trim();
    final shortAddress = address.length > 48
        ? '${address.substring(0, 48)}…'
        : address;
    final isPickup =
        order.deliveryOption.toLowerCase().replaceAll('-', '').contains('pickup');
    final placedAt = DateFormat('MMM d, y · h:mm a').format(order.createdAt);

    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.event_rounded,
            iconColor: color,
            label: 'Order placed',
            value: placedAt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            icon: Icons.place_rounded,
            iconColor: Colors.orange.shade700,
            label: isPickup ? 'Pickup at' : 'Deliver to',
            value: shortAddress.isNotEmpty ? shortAddress : '—',
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: PostCheckoutDesign.surfaceCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
