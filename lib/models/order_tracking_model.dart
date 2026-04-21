import 'cart_item.dart';
import 'order_status_step.dart';

enum OrderTrackingStage {
  pendingPayment,
  orderPlaced,
  paid,
  pendingConfirmation,
  orderConfirmed,
  outForDelivery,
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

    return OrderTrackingItem(
      name:
          map['product_name']?.toString() ?? map['name']?.toString() ?? 'Item',
      price: parseDouble(map['price']),
      quantity: parseInt(map['qty'] ?? map['quantity']),
      imageUrl:
          map['product_img']?.toString() ?? map['image']?.toString() ?? '',
      batchNo: map['batch_no']?.toString() ?? '',
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
    required this.deliveryFee,
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
  final double deliveryFee;
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
