import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onboarding_slide_background.dart';

/// Safety onboarding — legacy disclaimer card on photo background.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: OnboardingSlideBackground(
            imageAsset: 'assets/images/onboarding3.png',
            imageOpacity: 0.48,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.shade200, width: 2),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 52,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Important Safety Information',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please read carefully before using our services.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.45,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.shade100.withValues(alpha: 0.9),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        _LegacyDisclaimerItem(
                          icon: Icons.warning_amber_rounded,
                          iconColor: Color(0xFFE53935),
                          title: 'Know your allergies',
                          body:
                              'Consider allergies or adverse reactions before purchasing medications.',
                        ),
                        SizedBox(height: 12),
                        _LegacyDisclaimerItem(
                          icon: Icons.medical_services_outlined,
                          iconColor: Color(0xFF1E88E5),
                          title: 'Consult healthcare providers',
                          body:
                              'Speak with your doctor or pharmacist before starting new medications.',
                        ),
                        SizedBox(height: 12),
                        _LegacyDisclaimerItem(
                          icon: Icons.block_flipped,
                          iconColor: Color(0xFF8E24AA),
                          title: 'No drug misuse',
                          body:
                              'Medicines are for legitimate medical use only.',
                        ),
                        SizedBox(height: 12),
                        _LegacyDisclaimerItem(
                          icon: Icons.menu_book_outlined,
                          iconColor: Color(0xFF43A047),
                          title: 'Read instructions',
                          body:
                              'Follow labels, dosage, and warnings before use.',
                        ),
                        SizedBox(height: 12),
                        _LegacyDisclaimerItem(
                          icon: Icons.inventory_2_outlined,
                          iconColor: Color(0xFF00897B),
                          title: 'Store safely',
                          body:
                              'Keep medicines away from children and pets as directed.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        progressDots,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'I understand',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegacyDisclaimerItem extends StatelessWidget {
  const _LegacyDisclaimerItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.35,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
