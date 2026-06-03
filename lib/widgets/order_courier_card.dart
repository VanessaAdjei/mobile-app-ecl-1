import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_tracking_model.dart';

/// Rider / courier block for post-checkout when the API returns assigned rider
/// details (name, phone, vehicle). Live-tracking placeholders are not shown.
class OrderCourierCard extends StatelessWidget {
  const OrderCourierCard({
    super.key,
    required this.order,
    this.accent,
  });

  final OrderTrackingModel order;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (!order.supportsCourierDetails) {
      return const SizedBox.shrink();
    }

    final color = accent ?? const Color(0xFF0D7A4C);
    return _AssignedCourierCard(order: order, accent: color);
  }
}

class _AssignedCourierCard extends StatelessWidget {
  const _AssignedCourierCard({
    required this.order,
    required this.accent,
  });

  final OrderTrackingModel order;
  final Color accent;

  Future<void> _callRider(BuildContext context) async {
    final phone = order.courierPhone?.trim() ?? '';
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = order.courierName?.trim().isNotEmpty == true
        ? order.courierName!
        : 'Your rider';
    final vehicle = order.courierVehicle?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delivery_dining_rounded, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rider',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                if (vehicle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    vehicle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (order.courierPhone?.trim().isNotEmpty == true)
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _callRider(context),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
