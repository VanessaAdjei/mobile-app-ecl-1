import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/order_status_step.dart';

class OrderStatusTimeline extends StatefulWidget {
  const OrderStatusTimeline({
    super.key,
    required this.steps,
    this.accent,
    this.animate = true,
  });

  final List<OrderStatusStep> steps;
  final Color? accent;
  final bool animate;

  @override
  State<OrderStatusTimeline> createState() => _OrderStatusTimelineState();
}

class _OrderStatusTimelineState extends State<OrderStatusTimeline> {
  @override
  Widget build(BuildContext context) {
    final color = widget.accent ?? const Color(0xFF0D7A4C);

    return Column(
      children: List.generate(widget.steps.length, (index) {
        final step = widget.steps[index];
        return _AnimatedTimelineStep(
          key: ValueKey(
            '${step.id}_${step.isCompleted}_${step.isCurrent}',
          ),
          step: step,
          index: index,
          isLast: index == widget.steps.length - 1,
          accent: color,
          animate: widget.animate,
        );
      }),
    );
  }
}

class _AnimatedTimelineStep extends StatefulWidget {
  const _AnimatedTimelineStep({
    super.key,
    required this.step,
    required this.index,
    required this.isLast,
    required this.accent,
    required this.animate,
  });

  final OrderStatusStep step;
  final int index;
  final bool isLast;
  final Color accent;
  final bool animate;

  @override
  State<_AnimatedTimelineStep> createState() => _AnimatedTimelineStepState();
}

class _AnimatedTimelineStepState extends State<_AnimatedTimelineStep>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _completeController;
  late Animation<double> _entryOpacity;
  late Animation<double> _entrySlide;
  late Animation<double> _completeScale;

  bool _wasCompleted = false;

  static String _messageForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return 'We have received your order.';
      case 'paid':
        return 'Payment has been received.';
      case 'pendingConfirmation':
        return 'Awaiting confirmation from the store.';
      case 'orderConfirmed':
        return 'Your order has been confirmed!';
      case 'outForDelivery':
        return 'Your order is on its way.';
      case 'delivered':
        return 'Your order has been delivered!';
      case 'readyForPickup':
        return 'Your order is ready to be picked up.';
      case 'pickedUp':
        return 'Your order has been picked up!';
      default:
        return 'In progress';
    }
  }

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.step.isCompleted;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
    );
    _entrySlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _completeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 55),
    ]).animate(
      CurvedAnimation(parent: _completeController, curve: Curves.easeOut),
    );

    if (widget.animate) {
      Future.delayed(Duration(milliseconds: 60 + widget.index * 90), () {
        if (mounted) _entryController.forward();
      });
    } else {
      _entryController.value = 1;
    }

    _syncPulse();
  }

  void _syncPulse() {
    if (widget.step.isCurrent && !widget.step.isCompleted) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedTimelineStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasCompleted && widget.step.isCompleted) {
      _completeController.forward(from: 0);
    }
    _wasCompleted = widget.step.isCompleted;
    _syncPulse();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _completeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final isDone = step.isCompleted;
    final isCurrent = step.isCurrent;
    final isPending = !isDone && !isCurrent;
    final color = widget.accent;
    final activeColor = isPending ? Colors.grey.shade400 : color;

    final pulseScale = isCurrent && !isDone
        ? Tween<double>(begin: 1.0, end: 1.1).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          )
        : const AlwaysStoppedAnimation(1.0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        _pulseController,
        _completeController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: widget.animate ? _entryOpacity.value : 1,
          child: Transform.translate(
            offset: Offset(0, widget.animate ? _entrySlide.value : 0),
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _completeController]),
                builder: (context, child) {
                  final scale = _completeScale.value * pulseScale.value;
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: isCurrent ? 30 : 28,
                  height: isCurrent ? 30 : 28,
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.grey.shade100
                        : activeColor.withValues(alpha: isCurrent ? 0.16 : 0.1),
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: color, width: 2)
                        : isDone
                            ? Border.all(
                                color: color.withValues(alpha: 0.35),
                                width: 1,
                              )
                            : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.22),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _AnimatedStepIcon(
                      stepId: step.id,
                      isCurrent: isCurrent,
                      isDone: isDone,
                      isPending: isPending,
                      color: isPending ? Colors.grey.shade400 : color,
                      size: isCurrent ? 15 : 14,
                      animate: widget.animate,
                      staggerIndex: widget.index,
                      completeAnimation: _completeController,
                    ),
                  ),
                ),
              ),
              if (!widget.isLast)
                _AnimatedConnector(
                  isDone: isDone,
                  color: color,
                  animate: widget.animate,
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: isPending
                          ? Colors.grey.shade400
                          : const Color(0xFF1A1A1A),
                    ),
                    child: Text(
                      step.title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPending
                          ? Colors.grey.shade400
                          : isCurrent
                              ? color.withValues(alpha: 0.85)
                              : Colors.grey.shade600,
                      height: 1.2,
                      letterSpacing: 0.1,
                      fontWeight:
                          isCurrent ? FontWeight.w500 : FontWeight.w400,
                    ),
                    child: Text(
                      _messageForStep(step.id),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStepIcon extends StatefulWidget {
  const _AnimatedStepIcon({
    required this.stepId,
    required this.isCurrent,
    required this.isDone,
    required this.isPending,
    required this.color,
    required this.size,
    required this.animate,
    required this.staggerIndex,
    required this.completeAnimation,
  });

  final String stepId;
  final bool isCurrent;
  final bool isDone;
  final bool isPending;
  final Color color;
  final double size;
  final bool animate;
  final int staggerIndex;
  final Animation<double> completeAnimation;

  @override
  State<_AnimatedStepIcon> createState() => _AnimatedStepIconState();
}

class _AnimatedStepIconState extends State<_AnimatedStepIcon>
    with TickerProviderStateMixin {
  late AnimationController _motionController;
  late AnimationController _popInController;
  late Animation<double> _popInScale;

  static IconData iconForStep(String id) {
    switch (id) {
      case 'orderPlaced':
        return Icons.shopping_bag_rounded;
      case 'paid':
        return Icons.payment_rounded;
      case 'pendingConfirmation':
        return Icons.hourglass_top_rounded;
      case 'orderConfirmed':
        return Icons.check_circle_outline_rounded;
      case 'outForDelivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'readyForPickup':
        return Icons.storefront_rounded;
      case 'pickedUp':
        return Icons.check_circle_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: _motionDurationFor(widget.stepId),
    );
    _popInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _popInScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _popInController, curve: Curves.elasticOut),
    );

    if (widget.animate) {
      Future.delayed(
        Duration(milliseconds: 80 + widget.staggerIndex * 90),
        () {
          if (mounted) _popInController.forward();
        },
      );
    } else {
      _popInController.value = 1;
    }
    _syncMotion();
  }

  Duration _motionDurationFor(String stepId) {
    switch (stepId) {
      case 'pendingConfirmation':
        return const Duration(milliseconds: 2200);
      case 'outForDelivery':
        return const Duration(milliseconds: 900);
      case 'orderPlaced':
      case 'readyForPickup':
        return const Duration(milliseconds: 1100);
      case 'paid':
        return const Duration(milliseconds: 1600);
      default:
        return const Duration(milliseconds: 1300);
    }
  }

  void _syncMotion() {
    if (widget.isCurrent && !widget.isDone) {
      if (!_motionController.isAnimating) {
        _motionController.repeat(reverse: true);
      }
    } else {
      _motionController
        ..stop()
        ..reset();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedStepIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _popInController.dispose();
    super.dispose();
  }

  Widget _applyStepMotion(Widget icon) {
    if (!widget.isCurrent || widget.isDone) return icon;

    return AnimatedBuilder(
      animation: _motionController,
      builder: (context, child) {
        final t = _motionController.value;
        final wave = math.sin(t * math.pi * 2);

        switch (widget.stepId) {
          case 'pendingConfirmation':
            return Transform.rotate(
              angle: wave * 0.35,
              child: child,
            );
          case 'outForDelivery':
            return Transform.translate(
              offset: Offset(wave * 3.5, 0),
              child: Transform.rotate(
                angle: wave * 0.08,
                child: child,
              ),
            );
          case 'orderPlaced':
            return Transform.scale(
              scale: 1 + (wave * 0.12),
              child: child,
            );
          case 'paid':
            return Transform.rotate(
              angle: wave * 0.12,
              child: child,
            );
          case 'orderConfirmed':
            return Transform.scale(
              scale: 1 + (wave * 0.1),
              child: child,
            );
          case 'readyForPickup':
            return Transform.scale(
              scale: 1 + (wave * 0.14),
              child: Transform.translate(
                offset: Offset(0, wave * -1.2),
                child: child,
              ),
            );
          default:
            return Transform.scale(
              scale: 1 + (wave * 0.08),
              child: child,
            );
        }
      },
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      iconForStep(widget.stepId),
      size: widget.size,
      color: widget.color,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        _popInController,
        widget.completeAnimation,
      ]),
      builder: (context, child) {
        final v = widget.completeAnimation.value;
        final completeBump =
            1 + math.sin(v.clamp(0.0, 1.0) * math.pi) * 0.2;
        return Transform.scale(
          scale: _popInScale.value * completeBump,
          child: child,
        );
      },
      child: _applyStepMotion(icon),
    );
  }
}

class _AnimatedConnector extends StatelessWidget {
  const _AnimatedConnector({
    required this.isDone,
    required this.color,
    required this.animate,
  });

  final bool isDone;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isDone ? 1.0 : 0.0),
      duration: animate
          ? const Duration(milliseconds: 520)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        const fullHeight = 28.0;
        final filledHeight = fullHeight * progress.clamp(0.0, 1.0);

        return Container(
          width: 2,
          height: fullHeight,
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 2,
                height: fullHeight,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                width: 2,
                height: filledHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
