/// Resolved order data for [OrderTrackingPage] (delivery info, status, line items).
class OrderTrackingPageDetails {
  const OrderTrackingPageDetails({
    this.orderStatus,
    this.deliveryAddress,
    this.contactNumber,
    this.deliveryOption,
    this.actualDeliveryFee,
    this.actualTotalAmount,
    this.orderItems = const [],
    this.foundInOrdersList = false,
  });

  final String? orderStatus;
  final String? deliveryAddress;
  final String? contactNumber;
  final String? deliveryOption;
  final double? actualDeliveryFee;
  final double? actualTotalAmount;
  final List<Map<String, dynamic>> orderItems;
  final bool foundInOrdersList;
}
