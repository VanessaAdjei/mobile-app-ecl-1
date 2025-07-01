// widgets/optimized_category_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eclapp/widgets/error_display.dart';

class OptimizedCategoryWidget extends StatelessWidget {
  final dynamic category;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? errorMessage;
  final bool showShimmer;

  const OptimizedCategoryWidget({
    super.key,
    required this.category,
    this.onTap,
    this.isLoading = false,
    this.errorMessage,
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showShimmer) {
      return _buildShimmerCard();
    }

    if (errorMessage != null) {
      return _buildErrorCard();
    }

    return _buildCategoryCard(context);
  }

  Widget _buildCategoryCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Optimized image with error handling
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildOptimizedImage(),
                ),
              ),
              const SizedBox(width: 12),
              // Category details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category['name'] ?? 'Unknown Category',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (category['description'] != null)
                      Text(
                        category['description'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Products',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedImage() {
    final imageUrl = _getCategoryImageUrl(category['image_url']);

    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.category,
          size: 40,
          color: Colors.grey.shade400,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.error_outline,
          size: 40,
          color: Colors.grey.shade400,
        ),
      ),
      memCacheWidth: 160, // Optimize memory usage
      memCacheHeight: 160,
    );
  }

  Widget _buildShimmerCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            children: [
              // Shimmer image placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              // Shimmer text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ErrorDisplay(
            title: 'Error',
            message: errorMessage ?? 'Failed to load category',
            showRetry: true,
            onRetry: onTap,
          ),
        ),
      ),
    );
  }

  String _getCategoryImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    return 'https://eclcommerce.ernestchemists.com.gh/storage/categories/${Uri.encodeComponent(imagePath)}';
  }
}

class OptimizedCategoryGrid extends StatelessWidget {
  final List<dynamic> categories;
  final Function(dynamic)? onCategoryTap;
  final bool isLoading;
  final String? errorMessage;
  final bool showShimmer;

  const OptimizedCategoryGrid({
    super.key,
    required this.categories,
    this.onCategoryTap,
    this.isLoading = false,
    this.errorMessage,
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showShimmer) {
      return _buildShimmerGrid();
    }

    if (errorMessage != null) {
      return _buildErrorGrid();
    }

    if (categories.isEmpty && !isLoading) {
      return _buildEmptyState();
    }

    return _buildCategoryGrid();
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return OptimizedCategoryWidget(
          category: category,
          onTap: () => onCategoryTap?.call(category),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6, // Show 6 shimmer items
      itemBuilder: (context, index) {
        return OptimizedCategoryWidget(
          category: {},
          showShimmer: true,
        );
      },
    );
  }

  Widget _buildErrorGrid() {
    return Center(
      child: ErrorDisplay(
        title: 'Error',
        message: errorMessage ?? 'Failed to load categories',
        showRetry: true,
        onRetry: () => onCategoryTap?.call(null),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No categories available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new categories',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class OptimizedCategoryList extends StatelessWidget {
  final List<dynamic> categories;
  final Function(dynamic)? onCategoryTap;
  final bool isLoading;
  final String? errorMessage;
  final bool showShimmer;

  const OptimizedCategoryList({
    super.key,
    required this.categories,
    this.onCategoryTap,
    this.isLoading = false,
    this.errorMessage,
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showShimmer) {
      return _buildShimmerList();
    }

    if (errorMessage != null) {
      return _buildErrorList();
    }

    if (categories.isEmpty && !isLoading) {
      return _buildEmptyState();
    }

    return _buildCategoryList();
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return OptimizedCategoryWidget(
          category: category,
          onTap: () => onCategoryTap?.call(category),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Show 6 shimmer items
      itemBuilder: (context, index) {
        return OptimizedCategoryWidget(
          category: {},
          showShimmer: true,
        );
      },
    );
  }

  Widget _buildErrorList() {
    return Center(
      child: ErrorDisplay(
        title: 'Error',
        message: errorMessage ?? 'Failed to load categories',
        showRetry: true,
        onRetry: () => onCategoryTap?.call(null),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No categories available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new categories',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
