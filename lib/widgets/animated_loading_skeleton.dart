// widgets/animated_loading_skeleton.dart
import 'package:flutter/material.dart';

class AnimatedLoadingSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;
  final Color? color;

  const AnimatedLoadingSkeleton({
    super.key,
    this.height = 20,
    this.width = double.infinity,
    this.borderRadius = 8,
    this.color,
  });

  @override
  State<AnimatedLoadingSkeleton> createState() => _AnimatedLoadingSkeletonState();
}

class _AnimatedLoadingSkeletonState extends State<AnimatedLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                0.0,
                _animation.value.clamp(0.0, 1.0),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductSkeletonCard extends StatelessWidget {
  const ProductSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          AnimatedLoadingSkeleton(
            height: 120,
            borderRadius: 8,
          ),
          const SizedBox(height: 12),
          // Title skeleton
          AnimatedLoadingSkeleton(
            height: 16,
            width: double.infinity,
            borderRadius: 4,
          ),
          const SizedBox(height: 8),
          // Price skeleton
          AnimatedLoadingSkeleton(
            height: 14,
            width: 80,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
} 
 