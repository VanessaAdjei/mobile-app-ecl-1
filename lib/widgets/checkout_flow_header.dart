import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../pages/app_back_button.dart';
import '../utils/app_theme_colors.dart';
import 'checkout_progress_stepper.dart';

/// Shared green header for cart → delivery → checkout → confirmation.
class CheckoutFlowHeader extends StatelessWidget {
  static const List<String> checkoutSteps = [
    'Cart',
    'Delivery',
    'Payment',
    'Confirmation',
  ];

  const CheckoutFlowHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.activeStep,
    this.completedSteps = const {},
    this.confirmOnBack = false,
    this.leaveTitle,
    this.leaveMessage,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final int activeStep;
  final Set<int> completedSteps;
  final bool confirmOnBack;
  final String? leaveTitle;
  final String? leaveMessage;
  final Widget? footer;

  bool get _hasSubtitle => subtitle != null && subtitle!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final backButton = confirmOnBack
        ? BackButtonUtils.withConfirmation(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            title: leaveTitle ?? 'Leave',
            message:
                leaveMessage ?? 'Are you sure you want to leave this page?',
          )
        : BackButtonUtils.simple(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppThemeColors.headerBackground,
            AppColors.primaryDark,
            AppColors.primary,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  backButton,
                  Expanded(
                    child: _hasSubtitle
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                subtitle!.trim(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: CheckoutProgressStepper(
                compact: true,
                steps: checkoutSteps,
                activeStep: activeStep,
                completedSteps: completedSteps,
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
