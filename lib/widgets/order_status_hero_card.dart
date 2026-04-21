import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/order_tracking_model.dart';

class OrderStatusHeroCard extends StatelessWidget {
  const OrderStatusHeroCard({
    super.key,
    required this.order,
  });

  final OrderTrackingModel order;

  Color _accent(OrderTrackingStage stage) {
    switch (stage) {
      case OrderTrackingStage.pendingPayment:
        return Colors.orange.shade600;
      case OrderTrackingStage.orderPlaced:
        return Colors.green.shade700;
      case OrderTrackingStage.paid:
        return Colors.teal.shade700;
      case OrderTrackingStage.pendingConfirmation:
        return Colors.blue.shade700;
      case OrderTrackingStage.orderConfirmed:
        return Colors.blue.shade600;
      case OrderTrackingStage.outForDelivery:
        return Colors.deepPurple.shade600;
      case OrderTrackingStage.delivered:
        return Colors.green.shade800;
      case OrderTrackingStage.failed:
        return Colors.red.shade600;
    }
  }

  String _statusPillLabel(OrderTrackingStage stage) {
    switch (stage) {
      case OrderTrackingStage.pendingPayment:
        return 'PAYMENT';
      case OrderTrackingStage.failed:
        return 'ISSUE';
      default:
        return 'LIVE ORDER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(order.stage);
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order summary',
                style: TextStyle(
                  color: Colors.grey.shade900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _StatusBadge(
                  label: _statusPillLabel(order.stage), accent: accent),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Order #${order.orderNumber}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (firstItem != null) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: firstItem.imageUrl.isEmpty
                      ? Icon(Icons.image_outlined, color: Colors.grey.shade500)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            firstItem.imageUrl.startsWith('http')
                                ? firstItem.imageUrl
                                : ApiConfig.getProductImageUrl(
                                    firstItem.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.name,
                        style: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Qty ${firstItem.quantity}${order.items.length > 1 ? '  •  +${order.items.length - 1} more item${order.items.length - 1 == 1 ? '' : 's'}' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'GHS ${order.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 18),
          _SummaryLine(
              label: 'Subtotal',
              value: 'GHS ${order.subtotal.toStringAsFixed(2)}'),
          if (order.deliveryFee > 0)
            _SummaryLine(
              label: 'Delivery fee',
              value: 'GHS ${order.deliveryFee.toStringAsFixed(2)}',
            ),
          _SummaryLine(label: 'ETA', value: order.estimatedDeliveryTime),
          _SummaryLine(label: 'Address', value: order.deliveryAddress),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
