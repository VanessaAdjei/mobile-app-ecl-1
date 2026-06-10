import 'cart_item.dart';
import 'order_tracking_model.dart';

/// Snapshot of a guest checkout so the user can reopen tracking from Profile.
class GuestRecentOrder {
  const GuestRecentOrder({
    required this.guestId,
    required this.initialTransactionId,
    required this.paymentParams,
    required this.purchasedItems,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.contactNumber,
    required this.deliveryOption,
    required this.estimatedDeliveryTime,
    this.deliveryFee,
    required this.discount,
    required this.initialStatus,
    required this.savedAtMs,
  });

  final String guestId;
  final String initialTransactionId;
  final Map<String, dynamic> paymentParams;
  final List<Map<String, dynamic>> purchasedItems;
  final String paymentMethod;
  final String deliveryAddress;
  final String contactNumber;
  final String deliveryOption;
  final String estimatedDeliveryTime;
  final double? deliveryFee;
  final double discount;
  final String initialStatus;
  final int savedAtMs;

  List<CartItem> toCartItems() {
    return purchasedItems
        .map((json) => CartItem.fromJson(Map<String, dynamic>.from(json)))
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
        'guest_id': guestId,
        'initial_transaction_id': initialTransactionId,
        'payment_params': paymentParams,
        'purchased_items': purchasedItems,
        'payment_method': paymentMethod,
        'delivery_address': deliveryAddress,
        'contact_number': contactNumber,
        'delivery_option': deliveryOption,
        'estimated_delivery_time': estimatedDeliveryTime,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'initial_status': initialStatus,
        'saved_at_ms': savedAtMs,
      };

  factory GuestRecentOrder.fromJson(Map<String, dynamic> json) {
    double? readDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final itemsRaw = json['purchased_items'];
    final items = <Map<String, dynamic>>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final paramsRaw = json['payment_params'];
    final paymentParams = paramsRaw is Map
        ? Map<String, dynamic>.from(paramsRaw)
        : <String, dynamic>{};

    return GuestRecentOrder(
      guestId: json['guest_id']?.toString() ?? '',
      initialTransactionId:
          json['initial_transaction_id']?.toString() ?? '',
      paymentParams: paymentParams,
      purchasedItems: items,
      paymentMethod: json['payment_method']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      deliveryOption: json['delivery_option']?.toString() ?? 'delivery',
      estimatedDeliveryTime:
          json['estimated_delivery_time']?.toString() ?? '',
      deliveryFee: readDouble(json['delivery_fee']),
      discount: readDouble(json['discount']) ?? 0,
      initialStatus: json['initial_status']?.toString() ?? 'pending',
      savedAtMs: json['saved_at_ms'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory GuestRecentOrder.fromOrderTracking({
    required OrderTrackingModel order,
    required String guestId,
    String? initialTransactionId,
  }) {
    final txId = initialTransactionId?.trim().isNotEmpty == true
        ? initialTransactionId!.trim()
        : order.transactionId;

    return GuestRecentOrder(
      guestId: guestId,
      initialTransactionId: txId,
      paymentParams: Map<String, dynamic>.from(order.paymentParams),
      purchasedItems: order.items
          .map(
            (item) => {
              'id': '',
              'product_id': '',
              'product_name': item.name,
              'price': item.price,
              'qty': item.quantity,
              'product_img': item.imageUrl,
              'batch_no': item.batchNo,
              'url_name': '',
            },
          )
          .toList(growable: false),
      paymentMethod: order.paymentMethod,
      deliveryAddress: order.deliveryAddress,
      contactNumber: order.contactNumber,
      deliveryOption: order.deliveryOption,
      estimatedDeliveryTime: order.estimatedDeliveryTime,
      deliveryFee: order.deliveryFee,
      discount: order.discount,
      initialStatus: order.rawStatus,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
