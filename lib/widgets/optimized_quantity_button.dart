// widgets/optimized_quantity_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OptimizedQuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final Color? enabledColor;
  final Color? disabledColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const OptimizedQuantityButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
    this.enabledColor,
    this.disabledColor,
    this.size = 40.0,
    this.iconSize = 18.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultEnabledColor = enabledColor ?? theme.primaryColor;
    final defaultDisabledColor = disabledColor ?? Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isEnabled && onPressed != null
            ? () async {
                // Immediate haptic feedback
                HapticFeedback.lightImpact();
                
                // Call the onPressed callback
                onPressed!();
              }
            : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isEnabled 
                ? Colors.grey.shade50 
                : Colors.grey.shade100,
            border: Border.all(
              color: isEnabled 
                  ? defaultEnabledColor.withValues(alpha: 0.3)
                  : defaultDisabledColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: isEnabled ? defaultEnabledColor : defaultDisabledColor,
          ),
        ),
      ).animate()
        .scale(
          duration: 100.ms,
          begin: const Offset(1, 1),
          end: const Offset(0.95, 0.95),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          duration: 100.ms,
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeInOut,
        ),
    );
  }
}

class OptimizedAddButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final double size;
  final String? tooltip;

  const OptimizedAddButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
    this.size = 40.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedQuantityButton(
      icon: Icons.add,
      onPressed: onPressed,
      isEnabled: isEnabled,
      enabledColor: Colors.green.shade600,
      disabledColor: Colors.grey.shade400,
      size: size,
      iconSize: 18.0,
      tooltip: tooltip ?? 'Increase quantity',
    );
  }
}

class OptimizedRemoveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final double size;
  final String? tooltip;

  const OptimizedRemoveButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
    this.size = 40.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedQuantityButton(
      icon: Icons.remove,
      onPressed: onPressed,
      isEnabled: isEnabled,
      enabledColor: Colors.grey.shade700,
      disabledColor: Colors.grey.shade400,
      size: size,
      iconSize: 18.0,
      tooltip: tooltip ?? 'Decrease quantity',
    );
  }
}

class OptimizedDeleteButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final double size;
  final String? tooltip;

  const OptimizedDeleteButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
    this.size = 40.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedQuantityButton(
      icon: Icons.delete_outline,
      onPressed: onPressed,
      isEnabled: isEnabled,
      enabledColor: Colors.red.shade400,
      disabledColor: Colors.grey.shade400,
      size: size,
      iconSize: 16.0,
      tooltip: tooltip ?? 'Remove from cart',
    );
  }
} 