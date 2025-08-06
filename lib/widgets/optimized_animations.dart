// widgets/optimized_animations.dart
// widgets/optimized_animations.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Optimized animation controller for 60fps performance
class OptimizedAnimationController {
  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.easeOutCubic;

  /// Creates a smooth fade-in animation
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    int? delay,
  }) {
    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(
          duration: duration ?? _defaultDuration,
          curve: curve ?? _defaultCurve,
          delay: delay != null ? Duration(milliseconds: delay) : null,
        );
  }

  /// Creates a smooth slide-in animation
  static Widget slideIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    Offset? begin,
    int? delay,
  }) {
    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .moveY(
          duration: duration ?? _defaultDuration,
          curve: curve ?? _defaultCurve,
          begin: (begin?.dy ?? 0.3) * 100,
          delay: delay != null ? Duration(milliseconds: delay) : null,
        )
        .fadeIn(
          duration: duration ?? _defaultDuration,
          curve: curve ?? _defaultCurve,
          delay: delay != null ? Duration(milliseconds: delay) : null,
        );
  }

  /// Creates a smooth scale animation
  static Widget scaleIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double? begin,
    int? delay,
  }) {
    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .scale(
          duration: duration ?? _defaultDuration,
          curve: curve ?? _defaultCurve,
          begin: Offset(begin ?? 0.8, begin ?? 0.8),
          delay: delay != null ? Duration(milliseconds: delay) : null,
        );
  }

  /// Creates a staggered list animation
  static Widget staggeredList({
    required List<Widget> children,
    Duration? itemDuration,
    Curve? curve,
    int? staggerDelay,
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final delay = (staggerDelay ?? 50) * index;

        return child
            .animate(
              onPlay: (controller) => controller.repeat(),
            )
            .fadeIn(
              duration: itemDuration ?? const Duration(milliseconds: 400),
              curve: curve ?? Curves.easeOutQuart,
              delay: Duration(milliseconds: delay),
            )
            .moveY(
              duration: itemDuration ?? const Duration(milliseconds: 400),
              curve: curve ?? Curves.easeOutQuart,
              begin: 20,
              delay: Duration(milliseconds: delay),
            );
      }).toList(),
    );
  }

  /// Creates a smooth button press animation
  static Widget buttonPress({
    required Widget child,
    required VoidCallback onPressed,
    Duration? duration,
    double? scale,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: child
          .animate(
            onPlay: (controller) => controller.repeat(),
          )
          .scale(
            duration: duration ?? const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            begin: Offset(scale ?? 0.95, scale ?? 0.95),
          ),
    );
  }

  /// Creates a smooth card hover animation
  static Widget cardHover({
    required Widget child,
    Duration? duration,
    double? elevation,
  }) {
    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: duration ?? const Duration(milliseconds: 2000),
          color: Colors.white.withValues(alpha: 0.1),
        );
  }
}

/// Optimized list view with smooth scrolling
class OptimizedListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedListView({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return OptimizedAnimationController.fadeIn(
          child: children[index],
          delay: index * 30, // Staggered animation
        );
      },
    );
  }
}

/// Optimized grid view with smooth scrolling
class OptimizedGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedGridView({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: 0.75,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return OptimizedAnimationController.scaleIn(
          child: children[index],
          delay: index * 50, // Staggered animation
        );
      },
    );
  }
}

/// Performance-optimized page transition
class OptimizedPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  OptimizedPageRoute({
    required this.child,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

/// Optimized loading skeleton
class OptimizedSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const OptimizedSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: Colors.white.withValues(alpha: 0.3),
        );
  }
}

/// Optimized shimmer loading effect
class OptimizedShimmer extends StatelessWidget {
  final Widget child;
  final Duration? duration;
  final Color? color;

  const OptimizedShimmer({
    super.key,
    required this.child,
    this.duration,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: duration ?? const Duration(milliseconds: 1500),
          color: color ?? Colors.white.withValues(alpha: 0.3),
        );
  }
}
