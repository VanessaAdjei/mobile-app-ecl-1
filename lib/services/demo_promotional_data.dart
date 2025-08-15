// services/demo_promotional_data.dart
import '../models/promotional_event.dart';

class DemoPromotionalData {
  static PromotionalEvent get ernestFriday2024 {
    return PromotionalEvent(
      id: 'ernest_friday_2024',
      name: 'Ernest Friday 2024',
      description:
          'The biggest sale of the year! Get up to 50% off on all products plus amazing cashback offers.',
      startDate: DateTime.now(), // Starts today
      endDate: DateTime.now()
          .add(const Duration(days: 365)), // Active for the whole year
      isActive: true,
      eventType: 'black_friday',
      rules: {
        'max_discount_per_order': 100.0,
        'min_order_for_cashback': 50.0,
        'cashback_percentage': 5.0,
      },
      offers: [
        PromotionalOffer(
          id: 'offer_1',
          eventId: 'ernest_friday_2024',
          name: '20% Off All Medicines',
          description: 'Get 20% off on all pharmaceutical products',
          type: 'discount',
          value: 20.0,
          valueType: 'percentage',
          minimumOrderAmount: 30.0,
          maximumDiscount: 50.0,
          applicableCategories: ['medicines', 'drugs'],
          excludedProducts: [],
          promoCode: 'ERNEST20',
          isActive: true,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validUntil: DateTime.now().add(const Duration(days: 2)),
        ),
        PromotionalOffer(
          id: 'offer_2',
          eventId: 'ernest_friday_2024',
          name: '₵10 Cashback on Orders Above ₵100',
          description: 'Earn ₵10 cashback on orders above ₵100',
          type: 'cashback',
          value: 10.0,
          valueType: 'fixed',
          minimumOrderAmount: 100.0,
          maximumDiscount: 10.0,
          applicableCategories: [],
          excludedProducts: [],
          promoCode: 'CASHBACK10',
          isActive: true,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validUntil: DateTime.now().add(const Duration(days: 2)),
        ),
        PromotionalOffer(
          id: 'offer_3',
          eventId: 'ernest_friday_2024',
          name: 'Free Shipping on Orders Above ₵150',
          description: 'Free delivery on orders above ₵150',
          type: 'free_shipping',
          value: 0.0,
          valueType: 'fixed',
          minimumOrderAmount: 150.0,
          maximumDiscount: 0.0,
          applicableCategories: [],
          excludedProducts: [],
          promoCode: 'FREESHIP',
          isActive: true,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validUntil: DateTime.now().add(const Duration(days: 2)),
        ),
        PromotionalOffer(
          id: 'offer_4',
          eventId: 'ernest_friday_2024',
          name: '15% Off Health & Beauty',
          description: 'Get 15% off on health and beauty products',
          type: 'discount',
          value: 15.0,
          valueType: 'percentage',
          minimumOrderAmount: 25.0,
          maximumDiscount: 30.0,
          applicableCategories: ['health_beauty', 'wellness'],
          excludedProducts: [],
          promoCode: 'BEAUTY15',
          isActive: true,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validUntil: DateTime.now().add(const Duration(days: 2)),
        ),
        PromotionalOffer(
          id: 'offer_5',
          eventId: 'ernest_friday_2024',
          name: '₵5 Bonus on Baby Care',
          description: 'Earn ₵5 bonus cashback on baby care products',
          type: 'bonus',
          value: 5.0,
          valueType: 'fixed',
          minimumOrderAmount: 40.0,
          maximumDiscount: 5.0,
          applicableCategories: ['baby_care'],
          excludedProducts: [],
          promoCode: 'BABY5',
          isActive: true,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validUntil: DateTime.now().add(const Duration(days: 2)),
        ),
      ],
      bannerImage: 'assets/images/ernest_friday_bg.png',
      themeColor: '#FF6B35',
      requiresPromoCode: false,
    );
  }

  static PromotionalEvent get upcomingErnestFriday {
    return PromotionalEvent(
      id: 'ernest_friday_upcoming',
      name: 'Ernest Friday - Coming Soon!',
      description:
          'Get ready for the biggest sale of the year! Mark your calendar.',
      startDate:
          DateTime.now().add(const Duration(days: 7)), // Starts in 7 days
      endDate: DateTime.now().add(const Duration(days: 9)), // Ends in 9 days
      isActive: true,
      eventType: 'black_friday',
      rules: {
        'max_discount_per_order': 100.0,
        'min_order_for_cashback': 50.0,
        'cashback_percentage': 5.0,
      },
      offers: [
        PromotionalOffer(
          id: 'upcoming_offer_1',
          eventId: 'ernest_friday_upcoming',
          name: 'Early Bird 25% Off',
          description: 'Be among the first to get 25% off on all products',
          type: 'discount',
          value: 25.0,
          valueType: 'percentage',
          minimumOrderAmount: 50.0,
          maximumDiscount: 75.0,
          applicableCategories: [],
          excludedProducts: [],
          promoCode: 'EARLY25',
          isActive: true,
          validFrom: DateTime.now().add(const Duration(days: 7)),
          validUntil: DateTime.now().add(const Duration(days: 9)),
        ),
      ],
      bannerImage: 'assets/images/ernest_friday_bg.png',
      themeColor: '#FF6B35',
      requiresPromoCode: false,
    );
  }

  static List<PromotionalEvent> get allEvents => [
        ernestFriday2024,
        upcomingErnestFriday,
      ];

  static PromotionalEvent? get activeEvent {
    final now = DateTime.now();
    return allEvents
        .where((event) =>
            event.isActive &&
            now.isAfter(event.startDate) &&
            now.isBefore(event.endDate))
        .firstOrNull;
  }

  static PromotionalEvent? get upcomingEvent {
    final now = DateTime.now();
    return allEvents
        .where((event) => event.isActive && now.isBefore(event.startDate))
        .firstOrNull;
  }

  static bool get hasActiveEvent => activeEvent != null;
  static bool get hasUpcomingEvent => upcomingEvent != null;
}
