import 'package:flutter/material.dart';

class CheckoutProgressStepper extends StatelessWidget {
  final List<String> steps;
  final int activeStep;
  final Set<int> completedSteps;

  const CheckoutProgressStepper({
    super.key,
    required this.steps,
    required this.activeStep,
    this.completedSteps = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(steps.length, (index) {
          final step = index + 1;
          final isActive = step == activeStep;
          final isCompleted = completedSteps.contains(step);
          final textColor = isCompleted || isActive
              ? Colors.white
              : Colors.white.withValues(alpha: 0.7);

          return Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: textColor,
                        width: isActive ? 1.8 : 1.4,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded,
                              size: 15, color: Colors.white)
                          : Text(
                              step.toString(),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10.5,
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
                  width: 30,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
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
