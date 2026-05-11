import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order_tracking_model.dart';
import '../../services/order_notification_service.dart';

abstract class OrderTrackingLocalDataSource {
  Future<void> storeOrderAmounts({
    required OrderTrackingModel order,
    String? initialTransactionId,
  });

  Future<void> createOrderPlacedNotification(OrderTrackingModel order);
}

class OrderTrackingLocalDataSourceImpl implements OrderTrackingLocalDataSource {
  @override
  Future<void> storeOrderAmounts({
    required OrderTrackingModel order,
    String? initialTransactionId,
  }) async {
    final orderId = order.transactionId;
    if (orderId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('order_total_$orderId', order.totalAmount);

    if (initialTransactionId != null &&
        initialTransactionId.isNotEmpty &&
        initialTransactionId != orderId) {
      await prefs.setDouble(
        'order_total_$initialTransactionId',
        order.totalAmount,
      );
    }
  }

  @override
  Future<void> createOrderPlacedNotification(OrderTrackingModel order) async {
    await OrderNotificationService.createOrderPlacedNotification({
      'id': order.orderId.isNotEmpty ? order.orderId : order.transactionId,
      'transaction_id': order.transactionId,
      'order_number':
          order.orderNumber.isNotEmpty ? order.orderNumber : order.transactionId,
      'total_amount': order.totalAmount.toStringAsFixed(2),
      'status': order.stageLabel,
      'payment_method': order.paymentMethod,
      'items': order.items
          .map((item) => {
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'imageUrl': item.imageUrl,
                'batchNo': item.batchNo,
              })
          .toList(),
      'created_at': order.createdAt.toIso8601String(),
    });
  }
}
