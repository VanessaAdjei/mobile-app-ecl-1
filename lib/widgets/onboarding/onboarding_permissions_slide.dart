import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/widgets/onboarding/onboarding_ui.dart';
import 'package:flutter/material.dart';

/// Permissions step — notifications and location.
class OnboardingPermissionsSlide extends StatelessWidget {
  const OnboardingPermissionsSlide({
    super.key,
    required this.isLoading,
    required this.onAllow,
    required this.progressDots,
  });

  final bool isLoading;
  final VoidCallback onAllow;
  final Widget progressDots;

  static const Color _teal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OnboardingUi.surface,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                children: [
                  const OnboardingStepLabel(current: 3, total: 4),
                  const SizedBox(height: 20),
                  const _PermissionsHero(),
                  const SizedBox(height: 28),
                  Text(
                    'Stay in the loop',
                    textAlign: TextAlign.center,
                    style: OnboardingUi.displayTitle.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Allow notifications and location so we can confirm orders and deliver to the right place.',
                    textAlign: TextAlign.center,
                    style: OnboardingUi.body,
                  ),
                  const SizedBox(height: 24),
                  const _PermissionTile(
                    icon: Icons.notifications_active_rounded,
                    iconColor: AppColors.primary,
                    title: 'Order alerts',
                    description:
                        'Confirmations, delivery updates, and messages from pharmacists.',
                  ),
                  const SizedBox(height: 12),
                  const _PermissionTile(
                    icon: Icons.near_me_rounded,
                    iconColor: _teal,
                    title: 'Delivery location',
                    description:
                        'Used only while you use the app to set your delivery address and show accurate delivery fees.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.primaryDark.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can change these anytime in Settings.',
                            style: OnboardingUi.body.copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          OnboardingSlideFooter(
            progressDots: progressDots,
            buttonLabel: 'Continue',
            onPressed: isLoading ? null : onAllow,
            isLoading: isLoading,
            buttonIcon: Icons.arrow_forward_rounded,
            bottomPadding: 20,
          ),
        ],
      ),
    );
  }
}

class _PermissionsHero extends StatelessWidget {
  const _PermissionsHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconOrb(
                icon: Icons.notifications_active_rounded,
                color: AppColors.primary,
                size: 58,
                offset: const Offset(0, 6),
              ),
              const SizedBox(width: 16),
              _IconOrb(
                icon: Icons.location_on_rounded,
                color: OnboardingPermissionsSlide._teal,
                size: 54,
                offset: const Offset(0, -6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({
    required this.icon,
    required this.color,
    required this.size,
    this.offset = Offset.zero,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return OnboardingContentCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: OnboardingUi.bodyStrong.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: OnboardingUi.body.copyWith(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
