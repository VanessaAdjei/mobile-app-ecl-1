// widgets/animated_list_item.dart
import 'package:flutter/material.dart';

class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? duration;
  final Curve? curve;
  final Offset? slideOffset;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration,
    this.curve,
    this.slideOffset,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (widget.index * 0.1).clamp(0.0, 0.8),
        1.0,
        curve: widget.curve ?? Curves.easeOutCubic,
      ),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (widget.index * 0.1).clamp(0.0, 0.8),
        1.0,
        curve: widget.curve ?? Curves.easeOutCubic,
      ),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(
        (widget.index * 0.1).clamp(0.0, 0.8),
        1.0,
        curve: widget.curve ?? Curves.easeOutCubic,
      ),
    ));

    // Start animation after a short delay
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
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
        return Transform.translate(
          offset: Offset(
            (widget.slideOffset?.dx ?? 50) * _slideAnimation.value,
            (widget.slideOffset?.dy ?? 0) * _slideAnimation.value,
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class AnimatedListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Duration? animationDuration;
  final Curve? animationCurve;
  final Offset? slideOffset;

  const AnimatedListView({
    super.key,
    required this.children,
    this.physics,
    this.padding,
    this.animationDuration,
    this.animationCurve,
    this.slideOffset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          duration: animationDuration,
          curve: animationCurve,
          slideOffset: slideOffset,
          child: children[index],
        );
      },
    );
  }
} 
 