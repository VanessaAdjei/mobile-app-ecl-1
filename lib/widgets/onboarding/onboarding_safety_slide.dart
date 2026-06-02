import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/widgets/onboarding/onboarding_ui.dart';
import 'package:flutter/material.dart';

/// Safety disclaimers before using pharmacy services.
class OnboardingSafetySlide extends StatelessWidget {
  const OnboardingSafetySlide({
    super.key,
    required this.progressDots,
    required this.onContinue,
    this.isLoading = false,
  });

  final Widget progressDots;
  final VoidCallback onContinue;
  final bool isLoading;

  static const _items = [
    _SafetyItem(
      icon: Icons.health_and_safety_outlined,
      color: Color(0xFFE53935),
      title: 'Allergies',
      body: 'Check before you buy.',
    ),
    _SafetyItem(
      icon: Icons.medical_services_outlined,
      color: Color(0xFF1E88E5),
      title: 'Ask a pharmacist',
      body: 'When starting something new.',
    ),
    _SafetyItem(
      icon: Icons.block_flipped,
      color: Color(0xFF8E24AA),
      title: 'Use responsibly',
      body: 'For legitimate medical use.',
    ),
    _SafetyItem(
      icon: Icons.menu_book_outlined,
      color: AppColors.primary,
      title: 'Read the label',
      body: 'Follow dosage and warnings.',
    ),
    _SafetyItem(
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF00897B),
      title: 'Store safely',
      body: 'Keep from children and pets.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OnboardingUi.surface,
      child: Column(
        children: [
          const OnboardingHeroHeader(
            height: 140,
            imageAsset: 'assets/images/onboarding3.png',
            imageOpacity: 0.38,
            showLogo: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 48),
                child: Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  const OnboardingStepLabel(current: 2, total: 4),
                  const SizedBox(height: 12),
                  Text(
                    'Safety first',
                    textAlign: TextAlign.center,
                    style: OnboardingUi.displayTitle.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A few quick reminders.',
                    textAlign: TextAlign.center,
                    style: OnboardingUi.body.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  OnboardingContentCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 14,
                              color: Colors.grey.shade200,
                            ),
                          _SafetyRow(item: _items[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          OnboardingSlideFooter(
            progressDots: progressDots,
            buttonLabel: 'I understand',
            onPressed: isLoading ? null : onContinue,
            isLoading: isLoading,
            bottomPadding: 20,
          ),
        ],
      ),
    );
  }
}

class _SafetyItem {
  const _SafetyItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({required this.item});

  final _SafetyItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, size: 20, color: item.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: OnboardingUi.bodyStrong.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                style: OnboardingUi.body.copyWith(fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
