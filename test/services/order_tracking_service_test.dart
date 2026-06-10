import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/services/order_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderTrackingService.buildTimeline', () {
    final service = OrderTrackingService();
    final placedAt = DateTime(2026, 6, 8, 11, 44, 2);

    test('marks all prior steps completed when stage is outForDelivery', () {
      final steps = service.buildTimeline(
        OrderTrackingStage.outForDelivery,
        createdAt: placedAt,
        stageTimes: {
          OrderTrackingStage.orderPlaced.name: placedAt,
          OrderTrackingStage.paid.name: placedAt.add(const Duration(minutes: 1)),
          OrderTrackingStage.orderConfirmed.name:
              placedAt.add(const Duration(minutes: 4)),
        },
      );

      final dispatched = steps.firstWhere(
        (step) => step.id == OrderTrackingStage.orderDispatched.name,
      );
      final outForDelivery = steps.firstWhere(
        (step) => step.id == OrderTrackingStage.outForDelivery.name,
      );

      expect(dispatched.isCompleted, isTrue);
      expect(dispatched.isCurrent, isFalse);
      expect(outForDelivery.isCurrent, isTrue);
      expect(outForDelivery.isCompleted, isFalse);
    });
  });

  group('OrderTrackingService.normalizeStage', () {
    final service = OrderTrackingService();

    test('maps in-transit style statuses to outForDelivery', () {
      expect(
        service.normalizeStage('In Transit'),
        OrderTrackingStage.outForDelivery,
      );
      expect(
        service.normalizeStage('On the way'),
        OrderTrackingStage.outForDelivery,
      );
    });
  });

  group('OrderTrackingService.resolveAuthoritativeRawStatus', () {
    final service = OrderTrackingService();

    test('prefers furthest of status and order_status fields', () {
      final resolved = service.resolveAuthoritativeRawStatus({
        'status': 'Ready to Dispatch',
        'order_status': 'Out for Delivery',
      });

      expect(resolved, 'Out for Delivery');
    });
  });

  group('OrderTrackingService.pickFurthestRawStatus', () {
    final service = OrderTrackingService();

    test('prefers the furthest status across order rows', () {
      final status = service.pickFurthestRawStatus(
        [
          {'status': 'Ready to Dispatch'},
          {'status': 'Out for Delivery'},
        ],
        fallback: 'Ready to Dispatch',
      );

      expect(status, 'Out for Delivery');
    });
  });
}
