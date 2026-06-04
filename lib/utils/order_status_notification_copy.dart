bool _isPaidStatus(String status) {
  if (status.contains('unpaid') ||
      status.contains('not paid') ||
      status.contains('not_paid')) {
    return false;
  }
  if (status == 'paid' ||
      status == 'payment received' ||
      status == 'payment verified' ||
      status.startsWith('paid ') ||
      status.endsWith(' paid') ||
      status.contains(' paid ')) {
    return true;
  }
  return RegExp(r'(^|[^a-z])paid([^a-z]|$)').hasMatch(status);
}

/// User-facing title/body for order status local notifications.
/// Matches [OrderTrackingService.normalizeStage] — specific phrases first.
(String title, String message) orderStatusNotificationContent(
  String orderNumber,
  String status,
) {
  final s = status.toLowerCase();

  if (s.contains('cancel')) {
    return (
      'Order Cancelled',
      'Your order #$orderNumber has been cancelled.',
    );
  }
  if (s == 'arrived' || s.contains('arrived')) {
    return (
      'Order Arrived',
      'Your order #$orderNumber has arrived at your delivery location.',
    );
  }
  if (s.contains('delivered') || s == 'completed') {
    return (
      'Order Delivered',
      'Your order #$orderNumber has been delivered. Thank you for shopping with us!',
    );
  }
  if (s.contains('ready for pickup') ||
      s.contains('ready_for_pickup') ||
      s.contains('ready to be picked')) {
    return (
      'Ready for Pickup',
      'Your order #$orderNumber is ready for pickup.',
    );
  }
  if (s.contains('out for delivery') ||
      s.contains('out_for_delivery') ||
      s.contains('out for')) {
    return (
      'Out for Delivery',
      'Your order #$orderNumber is out for delivery. It will arrive soon!',
    );
  }
  if (s.contains('ready for dispatch') ||
      s.contains('ready_for_dispatch') ||
      s.contains('ready to dispatch')) {
    return (
      'Ready for Dispatch',
      'Your order #$orderNumber is packed and ready for dispatch.',
    );
  }
  if (s.contains('dispatched') ||
      (s.contains('dispatch') && !s.contains('confirmation'))) {
    return (
      'Ready for Dispatch',
      'Your order #$orderNumber is packed and ready for dispatch.',
    );
  }
  if (s.contains('ship') && !s.contains('out for')) {
    return (
      'Out for Delivery',
      'Your order #$orderNumber has been shipped and is on its way!',
    );
  }
  if (s.contains('pending confirmation') ||
      s.contains('pending_confirmation') ||
      s == 'confirming') {
    return (
      'Pending Confirmation',
      'Your order #$orderNumber is awaiting confirmation from the store.',
    );
  }
  if (s.contains('confirm') ||
      s == 'processing' ||
      s.contains('preparing') ||
      s.contains('packing')) {
    return (
      'Order Confirmed',
      'Your order #$orderNumber has been confirmed and is being prepared.',
    );
  }
  if (_isPaidStatus(s)) {
    return (
      'Payment Received',
      'Payment for order #$orderNumber has been received. Your order is being confirmed.',
    );
  }
  if (s.contains('order placed') || s == 'placed' || s == 'success') {
    return (
      'Order Placed',
      'Your order #$orderNumber has been placed and is being processed.',
    );
  }
  if (s == 'pending') {
    return (
      'Order Placed',
      'Your order #$orderNumber has been placed and is being processed.',
    );
  }

  return (
    'Order Update',
    'Your order #$orderNumber status: $status',
  );
}
