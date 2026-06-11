/// Single source of truth for checkout bill math (delivery → payment → ExpressPay).
class CheckoutOrderTotals {
  const CheckoutOrderTotals({
    required this.merchandiseSubtotal,
    required this.discount,
    required this.deliveryFee,
    required this.emergencyOrderFee,
    this.runningSubtotal,
    this.shippingFree = false,
    this.isDelivery = true,
  });

  /// Pre-discount merchandise (save-billing / cart).
  final double merchandiseSubtotal;

  /// Coupon / promo discount.
  final double discount;

  /// Raw fee from calculate-delivery-fee (before free-shipping promo).
  final double deliveryFee;

  /// xPress / urgent order surcharge.
  final double emergencyOrderFee;

  /// Post-discount merchandise from save-billing, when provided.
  final double? runningSubtotal;

  final bool shippingFree;
  final bool isDelivery;

  /// Delivery line item actually charged (0 for pickup or free shipping).
  double get chargedDeliveryFee {
    if (!isDelivery || shippingFree) return 0.0;
    return deliveryFee;
  }

  double get merchandiseAfterDiscount =>
      runningSubtotal ??
      (merchandiseSubtotal - discount).clamp(0.0, double.infinity);

  /// Grand total for UI and ExpressPay `amount`.
  double get total =>
      merchandiseAfterDiscount + chargedDeliveryFee + emergencyOrderFee;

  String get payableAmount => total.toStringAsFixed(2);

  CheckoutOrderTotals copyWith({
    double? merchandiseSubtotal,
    double? discount,
    double? deliveryFee,
    double? emergencyOrderFee,
    double? runningSubtotal,
    bool? shippingFree,
    bool? isDelivery,
  }) {
    return CheckoutOrderTotals(
      merchandiseSubtotal: merchandiseSubtotal ?? this.merchandiseSubtotal,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      emergencyOrderFee: emergencyOrderFee ?? this.emergencyOrderFee,
      runningSubtotal: runningSubtotal ?? this.runningSubtotal,
      shippingFree: shippingFree ?? this.shippingFree,
      isDelivery: isDelivery ?? this.isDelivery,
    );
  }
}
