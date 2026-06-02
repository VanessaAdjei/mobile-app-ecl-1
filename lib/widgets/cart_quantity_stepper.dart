import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact +/- stepper for cart line items.
class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  static const Color _green = Color(0xFF16A34A);
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final canDecrement = quantity > 1;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canDecrement) ...[
            _StepperTap(
              onTap: () {
                HapticFeedback.lightImpact();
                onDecrement();
              },
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13),
              ),
              backgroundColor: const Color(0xFFF8FAFC),
              child: const Icon(
                Icons.remove_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ),
            Container(
              width: 1,
              height: 18,
              color: _border,
            ),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(canDecrement ? 0 : 13),
                right: const Radius.circular(0),
              ),
            ),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: _border,
          ),
          _StepperTap(
            onTap: () {
              HapticFeedback.lightImpact();
              onIncrement();
            },
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(13),
            ),
            backgroundColor: _green,
            pressedColor: _greenDark,
            child: const Icon(
              Icons.add_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperTap extends StatefulWidget {
  const _StepperTap({
    required this.onTap,
    required this.borderRadius,
    required this.backgroundColor,
    required this.child,
    this.pressedColor,
  });

  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color? pressedColor;
  final Widget child;

  @override
  State<_StepperTap> createState() => _StepperTapState();
}

class _StepperTapState extends State<_StepperTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final bg = !enabled
        ? widget.backgroundColor.withValues(alpha: 0.6)
        : _pressed && widget.pressedColor != null
            ? widget.pressedColor!
            : widget.backgroundColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged:
            enabled ? (value) => setState(() => _pressed = value) : null,
        borderRadius: widget.borderRadius,
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: widget.pressedColor?.withValues(alpha: 0.15),
        child: Ink(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
