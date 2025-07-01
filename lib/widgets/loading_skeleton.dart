// widgets/loading_skeleton.dart
import 'package:flutter/material.dart';

class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                widget.baseColor ?? Colors.grey.shade300,
                widget.highlightColor ?? Colors.grey.shade100,
                widget.baseColor ?? Colors.grey.shade300,
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

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: const LoadingSkeleton(
                  height: double.infinity,
                  borderRadius: 0,
                ),
              ),
            ),
          ),
          // Content skeleton
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LoadingSkeleton(height: 14, borderRadius: 4),
                  const SizedBox(height: 8),
                  const LoadingSkeleton(
                    height: 12,
                    width: 80,
                    borderRadius: 4,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const LoadingSkeleton(
                        height: 10,
                        width: 30,
                        borderRadius: 4,
                      ),
                      const Spacer(),
                      const LoadingSkeleton(
                        height: 16,
                        width: 50,
                        borderRadius: 4,
                      ),
                    ],
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

class CategoryGridSkeleton extends StatelessWidget {
  const CategoryGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const LoadingSkeleton(
              height: double.infinity,
              borderRadius: 0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const LoadingSkeleton(height: 16, borderRadius: 4),
      ],
    );
  }
}

class SearchResultsSkeleton extends StatelessWidget {
  final int itemCount;

  const SearchResultsSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              // Image skeleton
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const LoadingSkeleton(
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LoadingSkeleton(height: 16, borderRadius: 4),
                    const SizedBox(height: 8),
                    const LoadingSkeleton(
                      height: 12,
                      width: 120,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    const LoadingSkeleton(
                      height: 14,
                      width: 80,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
