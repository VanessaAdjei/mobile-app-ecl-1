import '../utils/product_image_url.dart';
import 'cart_item.dart';
import 'order_status_step.dart';

enum OrderTrackingStage {
  pendingPayment,
  orderPlaced,
  paid,
  pendingConfirmation,
  orderConfirmed,
  orderDispatched,
  outForDelivery,
  arrived,
  delivered,
  failed,
}

class OrderTrackingItem {
  const OrderTrackingItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.batchNo,
  });

  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String batchNo;

  double get lineTotal => price * quantity;

  factory OrderTrackingItem.fromCartItem(CartItem item) {
    return OrderTrackingItem(
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      imageUrl: item.image,
      batchNo: item.batchNo,
    );
  }

  factory OrderTrackingItem.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseQuantity(Map<String, dynamic> m) {
      for (final key in [
        'qty',
        'quantity',
        'product_qty',
        'order_qty',
        'purchased_qty',
        'item_qty',
      ]) {
        final v = m[key];
        if (v == null) continue;
        final parsed = parseInt(v);
        if (parsed > 0) return parsed;
      }
      return 1;
    }

    return OrderTrackingItem(
      name:
          map['product_name']?.toString() ?? map['name']?.toString() ?? 'Item',
      price: parseDouble(map['price']),
      quantity: parseQuantity(map),
      imageUrl: coerceProductImageSource(
        map['product_img'] ?? map['image'] ?? map['imageUrl'],
      ),
      batchNo: map['batch_no']?.toString() ?? map['batchNo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_name': name,
      'price': price,
      'qty': quantity,
      'product_img': imageUrl,
      'batch_no': batchNo,
    };
  }
}

class PaymentStatusResult {
  const PaymentStatusResult({
    required this.status,
    required this.message,
    this.transactionId,
    this.rawStatus,
    this.isEmptyResponse = false,
  });

  final String status;
  final String message;
  final String? transactionId;
  final String? rawStatus;
  final bool isEmptyResponse;
}

class OrderTrackingModel {
  const OrderTrackingModel({
    required this.orderId,
    required this.orderNumber,
    required this.transactionId,
    required this.paymentParams,
    required this.items,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.contactNumber,
    required this.deliveryOption,
    required this.estimatedDeliveryTime,
    required this.subtotal,
    this.deliveryFee,
    required this.discount,
    required this.totalAmount,
    required this.rawStatus,
    required this.stage,
    required this.stageLabel,
    required this.stageMessage,
    required this.timelineSteps,
    required this.createdAt,
    this.courierName,
    this.courierPhone,
    this.courierVehicle,
    this.liveTrackingNote,
    this.deliveryOtp,
  });

  final String orderId;
  final String orderNumber;
  final String transactionId;
  final Map<String, dynamic> paymentParams;
  final List<OrderTrackingItem> items;
  final String paymentMethod;
  final String deliveryAddress;
  final String contactNumber;
  final String deliveryOption;
  final String estimatedDeliveryTime;
  final double subtotal;
  final double? deliveryFee;
  final double discount;
  final double totalAmount;
  final String rawStatus;
  final OrderTrackingStage stage;
  final String stageLabel;
  final String stageMessage;
  final List<OrderStatusStep> timelineSteps;
  final DateTime createdAt;
  final String? courierName;
  final String? courierPhone;
  final String? courierVehicle;
  final String? liveTrackingNote;

  /// OTP the user gives to the delivery rider to complete delivery. Shown when out for delivery.
  final String? deliveryOtp;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  /// ExpressPay `amount` sent at checkout — authoritative when present.
  double get checkoutGrandTotal {
    for (final key in ['amount', 'total_amount', 'total']) {
      final parsed = _parseParamAmount(paymentParams[key]);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  /// Grand total charged at checkout (subtotal + delivery − discount).
  ///
  /// Prefers the ExpressPay amount in [paymentParams] over API merchandise totals.
  double get payableTotal {
    final checkout = checkoutGrandTotal;
    if (checkout > subtotal + 0.01) return checkout;

    var fee = deliveryFee ?? 0;
    if (fee <= 0.01) {
      for (final key in ['delivery_fee', 'deliveryFee']) {
        final parsed = _parseParamAmount(paymentParams[key]);
        if (parsed > 0) {
          fee = parsed;
          break;
        }
      }
    }

    final computed =
        (subtotal + fee - discount).clamp(0.0, double.infinity);

    if (totalAmount > subtotal + 0.01) return totalAmount;

    if (fee > 0.01 && (totalAmount - subtotal).abs() < 0.01) {
      return computed;
    }

    for (final key in ['amount', 'total_amount', 'total']) {
      final parsed = _parseParamAmount(paymentParams[key]);
      if (parsed > subtotal + 0.01) return parsed;
    }

    final merchandise = _parseParamAmount(paymentParams['merchandise_subtotal']);
    if (merchandise > 0 && fee > 0.01) {
      final fromParts =
          (merchandise + fee - discount).clamp(0.0, double.infinity);
      if (fromParts > subtotal + 0.01) return fromParts;
    }

    if (computed > 0) return computed;
    return totalAmount > 0 ? totalAmount : subtotal;
  }

  static double _parseParamAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Delivery fee from model field, checkout params, or inferred from totals.
  double get resolvedDeliveryFee {
    var fee = deliveryFee ?? 0;
    if (fee <= 0.01) {
      for (final key in ['delivery_fee', 'deliveryFee']) {
        final parsed = _parseParamAmount(paymentParams[key]);
        if (parsed > 0) return parsed;
      }
    } else {
      return fee;
    }

    if (totalAmount > subtotal + discount + 0.01) {
      return totalAmount - subtotal + discount;
    }

    final payable = payableTotal;
    if (payable > subtotal + discount + 0.01) {
      return payable - subtotal + discount;
    }

    return 0;
  }

  bool get supportsCourierDetails =>
      (courierName?.isNotEmpty ?? false) ||
      (courierPhone?.isNotEmpty ?? false) ||
      (courierVehicle?.isNotEmpty ?? false);

  OrderTrackingModel copyWith({
    String? orderId,
    String? orderNumber,
    String? transactionId,
    Map<String, dynamic>? paymentParams,
    List<OrderTrackingItem>? items,
    String? paymentMethod,
    String? deliveryAddress,
    String? contactNumber,
    String? deliveryOption,
    String? estimatedDeliveryTime,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? totalAmount,
    String? rawStatus,
    OrderTrackingStage? stage,
    String? stageLabel,
    String? stageMessage,
    List<OrderStatusStep>? timelineSteps,
    DateTime? createdAt,
    String? courierName,
    String? courierPhone,
    String? courierVehicle,
    String? liveTrackingNote,
    String? deliveryOtp,
  }) {
    return OrderTrackingModel(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      transactionId: transactionId ?? this.transactionId,
      paymentParams: paymentParams ?? this.paymentParams,
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      contactNumber: contactNumber ?? this.contactNumber,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      rawStatus: rawStatus ?? this.rawStatus,
      stage: stage ?? this.stage,
      stageLabel: stageLabel ?? this.stageLabel,
      stageMessage: stageMessage ?? this.stageMessage,
      timelineSteps: timelineSteps ?? this.timelineSteps,
      createdAt: createdAt ?? this.createdAt,
      courierName: courierName ?? this.courierName,
      courierPhone: courierPhone ?? this.courierPhone,
      courierVehicle: courierVehicle ?? this.courierVehicle,
      liveTrackingNote: liveTrackingNote ?? this.liveTrackingNote,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
    );
  }
}
