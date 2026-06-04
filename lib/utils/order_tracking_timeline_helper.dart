import 'package:eclapp/models/order_status_step.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/services/order_tracking_service.dart';

/// Builds [OrderStatusStep] list for the legacy track-order page from a raw status string.
abstract final class OrderTrackingTimelineHelper {
  static List<OrderStatusStep> build({
    required OrderTrackingService service,
    required String currentStatus,
    required bool isPickup,
    DateTime? placedAt,
    Map<String, DateTime> stageTimes = const {},
    OrderTrackingStage? displayStage,
  }) {
    final stage = displayStage ?? service.normalizeStage(currentStatus);
    final createdAt = placedAt ?? DateTime.now();
    final times = Map<String, DateTime>.from(stageTimes);
    times.putIfAbsent(
      OrderTrackingStage.orderPlaced.name,
      () => createdAt,
    );
    final steps = service.buildTimeline(
      stage,
      createdAt: createdAt,
      stageTimes: times,
    );
    if (!isPickup) return steps;

    return steps
        .map(
          (step) => OrderStatusStep(
            id: step.id,
            title: _pickupTitle(step),
            isCompleted: step.isCompleted,
            isCurrent: step.isCurrent,
            occurredAt: step.occurredAt,
          ),
        )
        .toList(growable: false);
  }

  static String _pickupTitle(OrderStatusStep step) {
    if (step.id == OrderTrackingStage.outForDelivery.name) {
      return 'Ready for Pickup';
    }
    if (step.id == OrderTrackingStage.arrived.name) {
      return 'Arrived';
    }
    if (step.id == OrderTrackingStage.delivered.name) {
      return 'Picked up';
    }
    return step.title;
  }
}
