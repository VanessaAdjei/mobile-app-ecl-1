import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../utils/app_theme_colors.dart';

/// Promo UI when order subtotal is GHS 500+ (5% off — display only).
/// Free delivery applies from GHS 150+ via [qualifiesForFreeDelivery].
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

  static const double freeDeliveryThresholdAmount = 150;
  static const double discountThresholdAmount = 500;

  static bool qualifiesForFreeDelivery(double subtotal) =>
      subtotal >= freeDeliveryThresholdAmount;

  static bool qualifiesForDiscountPromo(double subtotal) =>
      subtotal >= discountThresholdAmount;

  /// Delivery fee shown in summaries; zero when free delivery applies (GHS 150+).
  static double displayDeliveryFee(double subtotal, double deliveryFee) =>
      qualifiesForFreeDelivery(subtotal) ? 0.0 : deliveryFee;

  bool get _qualifiesForDiscount => qualifiesForDiscountPromo(subtotal);

  @override
  Widget build(BuildContext context) {
    if (!_qualifiesForDiscount) return const SizedBox.shrink();

    if (compact) {
      final t = context.appColors;
      return Container(
        margin: margin ?? EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: t.isDark
                ? [
                    AppColors.primary.withValues(alpha: 0.18),
                    t.fieldBg,
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.12),
                    const Color(0xFFE8F5E9),
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.celebration_rounded,
              color: t.isDark ? AppColors.primaryLight : AppColors.primaryDark,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Free delivery on orders GHS 150+ and 5% off orders GHS 500+',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: t.isDark
                      ? AppColors.primaryLight
                      : const Color(0xFF1B4332),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7A4C), Color(0xFF20AF67)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special offer unlocked',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Free delivery for orders GHS 150 and above. 5% off all orders GHS 500 and above.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PromoChip(
                icon: Icons.percent_rounded,
                label: '5% off @ GHS 500+',
              ),
              _PromoChip(
                icon: Icons.local_shipping_rounded,
                label: 'Free delivery @ GHS 150+',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Free delivery applies on orders GHS 150+, and 5% off applies on all orders GHS 500+.',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Always-visible cart promo: free delivery GHS 150+ and 5% off GHS 500+.
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

class _PromoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PromoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
