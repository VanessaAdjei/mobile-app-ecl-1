import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

OrderTrackingModel _baseOrder({
  required double subtotal,
  required double totalAmount,
  double? deliveryFee,
  double discount = 0,
  Map<String, dynamic> paymentParams = const {},
}) {
  return OrderTrackingModel(
    orderId: '1',
    orderNumber: 'ORD-1',
    transactionId: 'TX-1',
    paymentParams: paymentParams,
    items: const [],
    paymentMethod: 'ExpressPay',
    deliveryAddress: 'Tema',
    contactNumber: '0500000000',
    deliveryOption: 'delivery',
    estimatedDeliveryTime: '30 min',
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    discount: discount,
    totalAmount: totalAmount,
    rawStatus: 'paid',
    stage: OrderTrackingStage.paid,
    stageLabel: 'Paid',
    stageMessage: 'Payment received',
    timelineSteps: const [],
    createdAt: DateTime(2026, 6, 8),
  );
}

void main() {
  group('OrderTrackingModel.payableTotal', () {
    test('adds delivery fee when totalAmount is merchandise subtotal only', () {
      final order = _baseOrder(
        subtotal: 36.5,
        totalAmount: 36.5,
        deliveryFee: 20,
        paymentParams: {'amount': '56.50', 'delivery_fee': 20},
      );

      expect(order.payableTotal, 56.5);
    });

    test('uses checkout amount when totalAmount is missing delivery', () {
      final order = _baseOrder(
        subtotal: 100,
        totalAmount: 100,
        paymentParams: {'amount': '120.00', 'delivery_fee': '20.00'},
      );

      expect(order.payableTotal, 120);
    });

    test('uses checkout amount when API total is merchandise only', () {
      final order = _baseOrder(
        subtotal: 36.5,
        totalAmount: 36.5,
        deliveryFee: 20,
        paymentParams: {'amount': '56.50', 'delivery_fee': 20},
      );

      expect(order.checkoutGrandTotal, 56.5);
      expect(order.payableTotal, 56.5);
    });
  });

  group('OrderTrackingService refresh total extraction', () {
    final service = OrderTrackingService();

    test('createInitialOrder uses total_amount when amount is absent', () {
      final order = service.createInitialOrder(
        paymentParams: {
          'total_amount': '76.00',
          'delivery_fee': 20,
        },
        purchasedItems: const [],
        paymentMethod: 'ExpressPay',
        initialTransactionId: 'ORDER-2',
        deliveryAddress: 'Tema',
        contactNumber: '0500000000',
        deliveryOption: 'delivery',
        estimatedDeliveryTime: '30 min',
        deliveryFee: 20,
        discount: 0,
      );

      expect(order.totalAmount, 76);
    });
  });

  group('OrderTrackingService.resolveBillSummary', () {
    final service = OrderTrackingService();

    test('adds delivery fee when API total_price is merchandise subtotal only', () {
      final bill = service.resolveBillSummary(
        items: [
          OrderTrackingItem(
            name: 'Product',
            price: 36.5,
            quantity: 1,
            imageUrl: '',
            batchNo: 'b1',
          ),
        ],
        orderDetails: {
          'total_price': 36.5,
          'delivery_fee': 20,
        },
      );

      expect(bill.subtotal, 36.5);
      expect(bill.deliveryFee, 20);
      expect(bill.total, 56.5);
      expect(bill.showDeliveryFee, isTrue);
    });

    test('uses stored delivery fee and total when order row omits them', () {
      final bill = service.resolveBillSummary(
        items: [
          OrderTrackingItem(
            name: 'Product',
            price: 100,
            quantity: 1,
            imageUrl: '',
            batchNo: 'b1',
          ),
        ],
        orderDetails: {'total_price': 100},
        storedDeliveryFee: 20,
        storedTotal: 120,
      );

      expect(bill.deliveryFee, 20);
      expect(bill.total, 120);
    });

    test('prefers ExpressPay amount over API merchandise subtotal', () {
      final service = OrderTrackingService();
      final bill = service.resolveBillSummary(
        items: [
          OrderTrackingItem(
            name: 'Product',
            price: 36.5,
            quantity: 1,
            imageUrl: '',
            batchNo: 'b1',
          ),
        ],
        orderDetails: {
          'total_price': 36.5,
          'amount': '56.50',
          'delivery_fee': 20,
        },
      );

      expect(bill.total, 56.5);
      expect(bill.deliveryFee, 20);
    });
  });
}
