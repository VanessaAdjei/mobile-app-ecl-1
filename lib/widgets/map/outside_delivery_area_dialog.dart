import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal shown when a picked map point is outside the delivery geofence.
Future<bool> showOutsideDeliveryAreaDialog(
  BuildContext context, {
  required String message,
  bool offerPickup = true,
}) async {
  final theme = context.appColors;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Outside delivery area',
    barrierColor: theme.isDark
        ? Colors.black.withValues(alpha: 0.82)
        : Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: OutsideDeliveryAreaDialog(
          message: message,
          offerPickup: offerPickup,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class OutsideDeliveryAreaDialog extends StatelessWidget {
  const OutsideDeliveryAreaDialog({
    super.key,
    required this.message,
    this.offerPickup = true,
  });

  final String message;
  final bool offerPickup;

  static const _stagger = Duration(milliseconds: 55);

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: theme.sheetBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE8EDEA),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.5 : 0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.muted,
                  ),
                ),
              ).animate().fadeIn(duration: 280.ms),
              const SizedBox(height: 2),
              Container(
                width: 32,
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideX(
                    begin: -0.4,
                    end: 0,
                    duration: 420.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 18),
              Text(
                'DELIVERY UNAVAILABLE',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: theme.muted,
                ),
              )
                  .animate()
                  .fadeIn(duration: 360.ms, delay: _stagger)
                  .slideY(begin: 0.12, end: 0, duration: 360.ms, delay: _stagger),
              const SizedBox(height: 10),
              Text(
                'Outside our delivery area',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: theme.ink,
                  letterSpacing: -0.3,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: _stagger * 2)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 400.ms,
                    delay: _stagger * 2,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 12),
              Text(
                _refinedBody(message),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                  color: theme.muted,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: _stagger * 3)
                  .slideY(begin: 0.08, end: 0, duration: 400.ms, delay: _stagger * 3),
              if (offerPickup) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 16,
                        color: AppColors.primary.withValues(
                          alpha: theme.isDark ? 0.9 : 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              height: 1.35,
                              color: theme.muted,
                            ),
                            children: [
                              TextSpan(
                                text: 'Store pickup',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.ink,
                                ),
                              ),
                              const TextSpan(
                                text: ' · Collect from a nearby shop.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 380.ms, delay: _stagger * 4)
                    .slideY(begin: 0.06, end: 0, duration: 380.ms, delay: _stagger * 4)
                    .scale(
                      begin: const Offset(0.97, 0.97),
                      end: const Offset(1, 1),
                      duration: 380.ms,
                      delay: _stagger * 4,
                    ),
              ],
              const SizedBox(height: 20),
              if (offerPickup)
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue with pickup',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: _stagger * 5)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: _stagger * 5),
              if (offerPickup) const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: theme.muted,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  offerPickup ? 'Choose another location' : 'Close',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 360.ms, delay: _stagger * 6)
                  .slideY(begin: 0.06, end: 0, duration: 360.ms, delay: _stagger * 6),
            ],
          ),
        ),
      ),
    );
  }

  static String _refinedBody(String message) {
    const fallback = 'We are unable to deliver to this address. '
        'Please select a location within our service area, '
        'or choose pickup at one of our stores.';
    if (message.trim().isEmpty) return fallback;
    if (message.toLowerCase().contains('switch to pickup')) {
      return fallback;
    }
    return message;
  }
}
