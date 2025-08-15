// models/promotional_event.dart
class PromotionalEvent {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String eventType; // 'black_friday', 'holiday', 'seasonal', etc.
  final Map<String, dynamic> rules;
  final List<PromotionalOffer> offers;
  final String bannerImage;
  final String? themeColor;
  final bool requiresPromoCode;

  PromotionalEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.eventType,
    required this.rules,
    required this.offers,
    required this.bannerImage,
    this.themeColor,
    this.requiresPromoCode = false,
  });

  factory PromotionalEvent.fromJson(Map<String, dynamic> json) {
    return PromotionalEvent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      isActive: json['is_active'] ?? false,
      eventType: json['event_type'] ?? 'black_friday',
      rules: Map<String, dynamic>.from(json['rules'] ?? {}),
      offers: (json['offers'] as List<dynamic>?)
              ?.map((o) => PromotionalOffer.fromJson(o))
              .toList() ??
          [],
      bannerImage: json['banner_image'] ?? '',
      themeColor: json['theme_color'],
      requiresPromoCode: json['requires_promo_code'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'event_type': eventType,
      'rules': rules,
      'offers': offers.map((o) => o.toJson()).toList(),
      'banner_image': bannerImage,
      'theme_color': themeColor,
      'requires_promo_code': requiresPromoCode,
    };
  }

  // Check if event is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  // Get time remaining until event starts
  Duration? get timeUntilStart {
    final now = DateTime.now();
    if (now.isBefore(startDate)) {
      return startDate.difference(now);
    }
    return null;
  }

  // Get time remaining until event ends
  Duration? get timeUntilEnd {
    final now = DateTime.now();
    if (now.isBefore(endDate)) {
      return endDate.difference(now);
    }
    return null;
  }

  // Get formatted countdown string
  String get countdownString {
    final timeLeft = timeUntilEnd;
    if (timeLeft == null) return 'Event Ended';

    final days = timeLeft.inDays;
    final hours = timeLeft.inHours % 24;
    final minutes = timeLeft.inMinutes % 60;

    if (days > 0) {
      return '$days days, $hours hours left';
    } else if (hours > 0) {
      return '$hours hours, $minutes minutes left';
    } else {
      return '$minutes minutes left';
    }
  }

  // Check if event is coming soon
  bool get isComingSoon {
    final now = DateTime.now();
    return isActive && now.isBefore(startDate);
  }

  // Check if event has ended
  bool get hasEnded {
    final now = DateTime.now();
    return now.isAfter(endDate);
  }
}

class PromotionalOffer {
  final String id;
  final String eventId;
  final String name;
  final String description;
  final String type; // 'discount', 'cashback', 'bonus', 'free_shipping'
  final double value; // Percentage or fixed amount
  final String valueType; // 'percentage', 'fixed', 'cashback'
  final double minimumOrderAmount;
  final double maximumDiscount;
  final List<String> applicableCategories;
  final List<String> excludedProducts;
  final String? promoCode;
  final bool isActive;
  final DateTime validFrom;
  final DateTime validUntil;

  PromotionalOffer({
    required this.id,
    required this.eventId,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.valueType,
    required this.minimumOrderAmount,
    required this.maximumDiscount,
    required this.applicableCategories,
    required this.excludedProducts,
    this.promoCode,
    required this.isActive,
    required this.validFrom,
    required this.validUntil,
  });

  factory PromotionalOffer.fromJson(Map<String, dynamic> json) {
    return PromotionalOffer(
      id: json['id'] ?? '',
      eventId: json['event_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'discount',
      value: (json['value'] ?? 0.0).toDouble(),
      valueType: json['value_type'] ?? 'percentage',
      minimumOrderAmount: (json['minimum_order_amount'] ?? 0.0).toDouble(),
      maximumDiscount: (json['maximum_discount'] ?? 0.0).toDouble(),
      applicableCategories:
          List<String>.from(json['applicable_categories'] ?? []),
      excludedProducts: List<String>.from(json['excluded_products'] ?? []),
      promoCode: json['promo_code'],
      isActive: json['is_active'] ?? false,
      validFrom: DateTime.tryParse(json['valid_from'] ?? '') ?? DateTime.now(),
      validUntil:
          DateTime.tryParse(json['valid_until'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'description': description,
      'type': type,
      'value': value,
      'value_type': valueType,
      'minimum_order_amount': minimumOrderAmount,
      'maximum_discount': maximumDiscount,
      'applicable_categories': applicableCategories,
      'excluded_products': excludedProducts,
      'promo_code': promoCode,
      'is_active': isActive,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
    };
  }

  // Check if offer is currently valid
  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  // Calculate discount amount for a given order total
  double calculateDiscount(double orderTotal) {
    if (orderTotal < minimumOrderAmount) return 0.0;

    double discount = 0.0;

    if (valueType == 'percentage') {
      discount = orderTotal * (value / 100);
    } else if (valueType == 'fixed') {
      discount = value;
    }

    // Apply maximum discount limit
    if (maximumDiscount > 0 && discount > maximumDiscount) {
      discount = maximumDiscount;
    }

    return discount;
  }

  // Get formatted value string
  String get formattedValue {
    if (valueType == 'percentage') {
      return '${value.toInt()}%';
    } else if (valueType == 'fixed') {
      return '₵${value.toStringAsFixed(2)}';
    } else if (valueType == 'cashback') {
      return '₵${value.toStringAsFixed(2)} cashback';
    }
    return value.toString();
  }

  // Get offer summary
  String get offerSummary {
    if (type == 'discount') {
      return 'Get ${formattedValue} off';
    } else if (type == 'cashback') {
      return 'Earn ${formattedValue}';
    } else if (type == 'free_shipping') {
      return 'Free Shipping';
    } else if (type == 'bonus') {
      return 'Bonus ${formattedValue}';
    }
    return description;
  }
}
