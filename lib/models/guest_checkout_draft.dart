/// Local guest checkout details kept until payment succeeds and the cart clears.
class GuestCheckoutDraft {
  const GuestCheckoutDraft({
    required this.guestId,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.deliveryOption = 'delivery',
    this.region = '',
    this.city = '',
    this.address = '',
    this.notes = '',
    this.pickupRegionLabel = '',
    this.pickupCityLabel = '',
    this.pickupSiteLabel = '',
    this.lat,
    this.lng,
    this.deliveryFee = 0,
    this.isOrderUrgent = false,
    this.emergencyOrderFee,
    this.estimatedDeliveryTime,
    this.distanceKm,
    this.apiSubtotal,
    this.apiDiscountAmount,
    this.apiShippingFree,
    this.promoCode,
    this.discountAmount = 0,
    this.updatedAtMs,
  });

  final String guestId;
  final String name;
  final String email;
  final String phone;
  final String deliveryOption;
  final String region;
  final String city;
  final String address;
  final String notes;
  final String pickupRegionLabel;
  final String pickupCityLabel;
  final String pickupSiteLabel;
  final double? lat;
  final double? lng;
  final double deliveryFee;
  final bool isOrderUrgent;
  final double? emergencyOrderFee;
  final String? estimatedDeliveryTime;
  final double? distanceKm;
  final double? apiSubtotal;
  final double? apiDiscountAmount;
  final bool? apiShippingFree;
  final String? promoCode;
  final double discountAmount;
  final int? updatedAtMs;

  bool get hasContactInfo =>
      name.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phone.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'guest_id': guestId,
        'name': name,
        'email': email,
        'phone': phone,
        'delivery_option': deliveryOption,
        'region': region,
        'city': city,
        'address': address,
        'notes': notes,
        'pickup_region': pickupRegionLabel,
        'pickup_city': pickupCityLabel,
        'pickup_site': pickupSiteLabel,
        'lat': lat,
        'lng': lng,
        'delivery_fee': deliveryFee,
        'is_order_urgent': isOrderUrgent,
        'emergency_order_fee': emergencyOrderFee,
        'estimated_delivery_time': estimatedDeliveryTime,
        'distance_km': distanceKm,
        'api_subtotal': apiSubtotal,
        'api_discount_amount': apiDiscountAmount,
        'api_shipping_free': apiShippingFree,
        'promo_code': promoCode,
        'discount_amount': discountAmount,
        'updated_at_ms': updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      };

  factory GuestCheckoutDraft.fromJson(Map<String, dynamic> json) {
    double? readDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return GuestCheckoutDraft(
      guestId: json['guest_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      deliveryOption:
          (json['delivery_option']?.toString() ?? 'delivery').toLowerCase(),
      region: json['region']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      pickupRegionLabel: json['pickup_region']?.toString() ?? '',
      pickupCityLabel: json['pickup_city']?.toString() ?? '',
      pickupSiteLabel: json['pickup_site']?.toString() ?? '',
      lat: readDouble(json['lat']),
      lng: readDouble(json['lng']),
      deliveryFee: readDouble(json['delivery_fee']) ?? 0,
      isOrderUrgent: json['is_order_urgent'] == true,
      emergencyOrderFee: readDouble(json['emergency_order_fee']),
      estimatedDeliveryTime: json['estimated_delivery_time']?.toString(),
      distanceKm: readDouble(json['distance_km']),
      apiSubtotal: readDouble(json['api_subtotal']),
      apiDiscountAmount: readDouble(json['api_discount_amount']),
      apiShippingFree: json['api_shipping_free'] as bool?,
      promoCode: json['promo_code']?.toString(),
      discountAmount: readDouble(json['discount_amount']) ?? 0,
      updatedAtMs: json['updated_at_ms'] as int?,
    );
  }
}
