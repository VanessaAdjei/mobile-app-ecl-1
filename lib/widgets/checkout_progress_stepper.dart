import 'package:flutter/material.dart';

class CheckoutProgressStepper extends StatelessWidget {
  final List<String> steps;
  final int activeStep;
  final Set<int> completedSteps;
  final bool compact;

  /// Green/gray styling for white headers (e.g. post-checkout).
  final bool lightSurface;

  const CheckoutProgressStepper({
    super.key,
    required this.steps,
    required this.activeStep,
    this.completedSteps = const {},
    this.compact = false,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final circleSize = compact ? 24.0 : 30.0;
    final stepFontSize = compact ? 10.0 : 12.0;
    final labelFontSize = compact ? 9.0 : 10.5;
    final labelGap = compact ? 4.0 : 6.0;
    final connectorWidth = compact ? 22.0 : 30.0;
    final connectorMargin = compact ? 4.0 : 6.0;
    final checkIconSize = compact ? 12.0 : 15.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(steps.length, (index) {
          final step = index + 1;
          final isActive = step == activeStep;
          final isCompleted = completedSteps.contains(step);
          final textColor = lightSurface
              ? (isCompleted || isActive
                  ? const Color(0xFF0D7A4C)
                  : const Color(0xFF94A3B8))
              : (isCompleted || isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7));
          final circleFill = lightSurface
              ? (isCompleted || isActive
                  ? const Color(0xFFE8F5EE)
                  : const Color(0xFFF1F5F9))
              : (isCompleted || isActive
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08));
          final connectorColor = lightSurface
              ? (isCompleted
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFE2E8F0))
              : Colors.white.withValues(alpha: 0.35);

          return Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: circleFill,
                      border: Border.all(
                        color: textColor,
                        width: isActive ? 1.6 : 1.2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check_rounded,
                              size: checkIconSize,
                              color: lightSurface
                                  ? const Color(0xFF0D7A4C)
                                  : Colors.white)
                          : Text(
                              step.toString(),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: stepFontSize,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: labelGap),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 6 : 8,
                      vertical: compact ? 1 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (lightSurface
                              ? const Color(0xFFE8F5EE)
                              : Colors.white.withValues(alpha: 0.22))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        color: textColor,
                        fontSize: labelFontSize,
                        fontWeight: isActive || isCompleted
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Container(
                  width: connectorWidth,
                  height: compact ? 3 : 4,
                  margin: EdgeInsets.symmetric(horizontal: connectorMargin),
                  decoration: BoxDecoration(
                    color: connectorColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
