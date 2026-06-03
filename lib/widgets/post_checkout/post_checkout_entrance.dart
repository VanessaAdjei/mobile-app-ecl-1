import 'package:flutter/material.dart';

/// One-shot staggered entrance (survives parent rebuilds from polling).
class PostCheckoutEntrance extends StatefulWidget {
  const PostCheckoutEntrance({
    super.key,
    required this.index,
    required this.child,
    this.stepMs = 90,
    this.duration = const Duration(milliseconds: 520),
    this.slideY = 28,
    this.slideX = 0,
  });

  final int index;
  final Widget child;
  final int stepMs;
  final Duration duration;
  final double slideY;
  final double slideX;

  @override
  State<PostCheckoutEntrance> createState() => _PostCheckoutEntranceState();
}

class _PostCheckoutEntranceState extends State<PostCheckoutEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late Animation<double> _translateX;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _translateY = Tween<double>(begin: widget.slideY, end: 0).animate(curve);
    _translateX = Tween<double>(begin: widget.slideX, end: 0).animate(curve);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    Future.delayed(Duration(milliseconds: widget.index * widget.stepMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(_translateX.value, _translateY.value),
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Elastic pop-in once, then a gentle repeating pulse.
class PostCheckoutAnimatedIcon extends StatefulWidget {
  const PostCheckoutAnimatedIcon({
    super.key,
    required this.child,
    this.pulse = true,
  });

  final Widget child;
  final bool pulse;

  @override
  State<PostCheckoutAnimatedIcon> createState() =>
      _PostCheckoutAnimatedIconState();
}

class _PostCheckoutAnimatedIconState extends State<PostCheckoutAnimatedIcon>
    with TickerProviderStateMixin {
  late AnimationController _popController;
  late AnimationController _pulseController;
  late Animation<double> _popScale;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _popScale = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(parent: _popController, curve: Curves.elasticOut),
    );
    _popController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseScale = Tween<double>(begin: 1, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_popController, _pulseController]),
      builder: (context, child) {
        final scale = _popScale.value * (widget.pulse ? _pulseScale.value : 1);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

/// Subtle breathing scale for primary CTAs.
class PostCheckoutBreathingButton extends StatefulWidget {
  const PostCheckoutBreathingButton({super.key, required this.child});

  final Widget child;

  @override
  State<PostCheckoutBreathingButton> createState() =>
      _PostCheckoutBreathingButtonState();
}

class _PostCheckoutBreathingButtonState extends State<PostCheckoutBreathingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
