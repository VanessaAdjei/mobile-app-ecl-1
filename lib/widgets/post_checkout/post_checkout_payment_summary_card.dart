import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/widgets/order_tracking/order_tracking_bill_card.dart';
import 'package:flutter/material.dart';

/// Payment breakdown (subtotal, delivery fee, discount, total) for post-checkout screens.
class PostCheckoutPaymentSummaryCard extends StatelessWidget {
  const PostCheckoutPaymentSummaryCard({
    super.key,
    required this.order,
    required this.accent,
    this.isPickup = false,
  });

  final OrderTrackingModel order;
  final Color accent;
  final bool isPickup;

  static bool isPickupOrder(OrderTrackingModel order) {
    return order.deliveryOption
        .toLowerCase()
        .replaceAll('-', '')
        .contains('pickup');
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = order.resolvedDeliveryFee;
    final showDelivery = !isPickup && deliveryFee > 0.01;

    return OrderTrackingBillCard(
      subtotal: order.subtotal,
      deliveryFee: deliveryFee,
      discount: order.discount,
      total: order.payableTotal,
      accent: accent,
      showDeliveryFee: showDelivery,
    );
  }
}
