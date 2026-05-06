import 'package:flutter/material.dart';

import '../models/order_status_step.dart';

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.steps,
    this.accent,
  });

  final List<OrderStatusStep> steps;
  final Color? accent;

  static String _messageForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return 'We have received your order.';
      case 'paid':
        return 'Payment has been received.';
      case 'pendingConfirmation':
        return 'Awaiting confirmation from the store.';
      case 'orderConfirmed':
        return 'Your order has been confirmed!';
      case 'outForDelivery':
        return 'Your order is on its way.';
      case 'delivered':
        return 'Your order has been delivered!';
      case 'readyForPickup':
        return 'Your order is ready to be pickup.';
      case 'pickedUp':
        return 'Your order has been picked up!';
      default:
        return 'In progress';
    }
  }

  IconData _iconForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return Icons.shopping_bag_rounded;
      case 'paid':
        return Icons.payment_rounded;
      case 'pendingConfirmation':
        return Icons.hourglass_top_rounded;
      case 'orderConfirmed':
        return Icons.check_circle_outline_rounded;
      case 'outForDelivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'readyForPickup':
        return Icons.storefront_rounded;
      case 'pickedUp':
        return Icons.check_circle_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFF0D7A4C);

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isDone = step.isCompleted;
        final isCurrent = step.isCurrent;
        final isPending = !isDone && !isCurrent;
        final activeColor = isPending ? Colors.grey.shade400 : color;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.grey.shade100
                        : activeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border:
                        isCurrent ? Border.all(color: color, width: 2) : null,
                  ),
                  child: Icon(
                    _iconForStep(step.id),
                    size: 14,
                    color: isPending ? Colors.grey.shade400 : color,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isDone ? color : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isPending
                            ? Colors.grey.shade400
                            : const Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _messageForStep(step.id),
                      style: TextStyle(
                        fontSize: 11,
                        color: isPending
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
