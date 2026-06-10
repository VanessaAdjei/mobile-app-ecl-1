/// Rules for order notification deduplication and system push eligibility.
class OrderNotificationPolicy {
  OrderNotificationPolicy._();

  /// Stable key for grouping/deduping notifications for one order.
  static String orderKey(Map<String, dynamic> notification) {
    final orderNumber = notification['order_number']?.toString().trim() ?? '';
    if (orderNumber.isNotEmpty) return 'order:$orderNumber';

    final orderId = notification['order_id']?.toString().trim() ?? '';
    if (orderId.isNotEmpty) return 'id:$orderId';

    return 'misc:${notification['id'] ?? notification['timestamp']}';
  }

  /// Coarse status bucket so similar API strings dedupe together.
  static String statusKey(String status, {String type = ''}) {
    if (type == 'order_placed') return 'placed';

    final s = status.toLowerCase().trim();
    if (s.isEmpty) return 'update';

    if (s.contains('cancel')) return 'cancelled';
    if (s.contains('delivered') || s == 'completed') return 'delivered';
    if (s.contains('arrived')) return 'arrived';
    if (s.contains('out for delivery') ||
        s.contains('out_for_delivery') ||
        (s.contains('out for') && !s.contains('dispatch'))) {
      return 'out_for_delivery';
    }
    if (s.contains('ready for pickup') || s.contains('ready_for_pickup')) {
      return 'ready_for_pickup';
    }
    if (s.contains('ready for dispatch') ||
        s.contains('ready_for_dispatch') ||
        s.contains('dispatched') ||
        (s.contains('dispatch') && !s.contains('confirmation'))) {
      return 'dispatched';
    }
    if (s.contains('ship') && !s.contains('out for')) return 'shipped';
    if (s.contains('confirm') ||
        s.contains('preparing') ||
        s.contains('packing') ||
        s == 'processing') {
      return 'confirmed';
    }
    if (s.contains('paid') || s.contains('payment received')) return 'paid';
    if (s.contains('pending confirmation') || s == 'confirming') {
      return 'pending_confirmation';
    }
    if (s.contains('order placed') || s == 'placed' || s == 'pending') {
      return 'placed';
    }

    return s.replaceAll(RegExp(r'\s+'), '_');
  }

  /// System push only for high-signal order milestones.
  static bool shouldShowSystemPush({
    required String type,
    required String status,
  }) {
    if (type == 'order_placed') return true;

    final key = statusKey(status, type: type);
    return key == 'placed' ||
        key == 'out_for_delivery' ||
        key == 'arrived' ||
        key == 'delivered' ||
        key == 'cancelled';
  }

  static String dedupeKey(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? '';
    final status = notification['status']?.toString() ?? '';
    return '${orderKey(notification)}|${statusKey(status, type: type)}';
  }
}
