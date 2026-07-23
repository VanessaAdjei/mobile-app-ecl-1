import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';

/// Promo UI when order subtotal is GHS 500+ (5% off — display only).
/// Free delivery applies from GHS 350+ via [qualifiesForFreeDelivery].
class OrderThresholdPromoBanner extends StatelessWidget {
  final double subtotal;
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const OrderThresholdPromoBanner({
    super.key,
    required this.subtotal,
    this.margin,
    this.compact = false,
  });

  static const double freeDeliveryThresholdAmount = 350;
  static const double discountThresholdAmount = 500;

  static bool qualifiesForFreeDelivery(double subtotal) =>
      subtotal >= freeDeliveryThresholdAmount;

  static bool qualifiesForDiscountPromo(double subtotal) =>
      subtotal >= discountThresholdAmount;

  /// Parses API booleans that may arrive as `true`, `1`, or `"true"`.
  static bool isTruthy(dynamic value) {
    if (value == true || value == 1) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static double? _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  static double _deliveryThresholdFromPromo(dynamic value) =>
      _parseAmount(value) ?? freeDeliveryThresholdAmount;

  /// Whether save/get-billing `promo_details` qualifies for free delivery.
  static bool shippingFreeFromPromo(
    Map<String, dynamic>? promo, {
    double? fallbackSubtotal,
  }) {
    if (promo == null) return false;
    if (isTruthy(promo['shipping_free'])) return true;

    final threshold = _deliveryThresholdFromPromo(promo['delivery_threshold']);
    final subtotal = _parseAmount(promo['subtotal']) ??
        _parseAmount(promo['running_subtotal']) ??
        fallbackSubtotal;
    if (subtotal != null && subtotal >= threshold) return true;
    return false;
  }

  /// Free shipping from API flag and/or cart subtotal threshold (GHS 350+).
  static bool effectiveShippingFree({
    required bool apiShippingFree,
    required double merchandiseSubtotal,
    required bool isDelivery,
  }) {
    if (!isDelivery) return false;
    if (apiShippingFree) return true;
    if (merchandiseSubtotal <= 0) return false;
    return qualifiesForFreeDelivery(merchandiseSubtotal);
  }

  /// Delivery fee shown in summaries; zero when free delivery applies (GHS 350+).
  static double displayDeliveryFee(double subtotal, double deliveryFee) =>
      qualifiesForFreeDelivery(subtotal) ? 0.0 : deliveryFee;

  bool get _qualifiesForDiscount => qualifiesForDiscountPromo(subtotal);

  static const String _bannerAsset = 'assets/images/specialoffer.PNG';
  static const double _bannerAspectRatio = 1024 / 157;

  @override
  Widget build(BuildContext context) {
    if (!_qualifiesForDiscount) return const SizedBox.shrink();

    return Container(
      margin: margin ??
          (compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _bannerAspectRatio,
        child: Image.asset(
          _bannerAsset,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }
}

/// Always-visible cart promo: free delivery GHS 350+ and 5% off GHS 500+.
class OrderThresholdPromoCartInfo extends StatelessWidget {
  final double subtotal;

  const OrderThresholdPromoCartInfo({
    super.key,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CartPromoTile(
            icon: Icons.local_shipping_outlined,
            label: 'Free delivery',
            threshold: OrderThresholdPromoBanner.freeDeliveryThresholdAmount,
            subtotal: subtotal,
            unlocked: OrderThresholdPromoBanner.qualifiesForFreeDelivery(
              subtotal,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CartPromoTile(
            icon: Icons.percent_outlined,
            label: '5% off',
            threshold: OrderThresholdPromoBanner.discountThresholdAmount,
            subtotal: subtotal,
            unlocked: OrderThresholdPromoBanner.qualifiesForDiscountPromo(
              subtotal,
            ),
          ),
        ),
      ],
    );
  }
}

class _CartPromoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double threshold;
  final double subtotal;
  final bool unlocked;

  const _CartPromoTile({
    required this.icon,
    required this.label,
    required this.threshold,
    required this.subtotal,
    required this.unlocked,
  });

  static const Color _muted = Color(0xFF5C5C60);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _accent = Color(0xFF1A8F55);

  double get _progress => (subtotal / threshold).clamp(0.0, 1.0);

  double get _remaining => (threshold - subtotal).clamp(0.0, double.infinity);

  String get _detail => unlocked
      ? 'GHS ${threshold.toStringAsFixed(0)}+ · Included'
      : 'GHS ${threshold.toStringAsFixed(0)}+ · ${_remaining.toStringAsFixed(0)} left';

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final inkColor = theme.isDark ? theme.ink : _ink;
    final mutedColor = theme.isDark ? theme.muted : _muted;
    final accentColor = theme.isDark ? AppColors.primaryLight : _accent;
    final tileBg = theme.isDark ? theme.fieldBg : Colors.white;
    final tileBorder = unlocked
        ? accentColor.withValues(alpha: theme.isDark ? 0.45 : 0.4)
        : (theme.isDark ? theme.border : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icon,
                  size: 14,
                  color: unlocked ? accentColor : mutedColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: inkColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _detail,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: unlocked ? accentColor : mutedColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}


