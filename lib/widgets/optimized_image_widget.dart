// widgets/optimized_image_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  const OptimizedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 200),
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  });

  factory OptimizedImageWidget.thumbnail({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return OptimizedImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      memCacheWidth: 120,
      memCacheHeight: 120,
      maxWidthDiskCache: 240,
      maxHeightDiskCache: 240,
      placeholder: (context, url) => _buildThumbnailPlaceholder(),
      errorWidget: (context, url, error) => _buildThumbnailErrorWidget(error),
    );
  }

  factory OptimizedImageWidget.medium({
    required String imageUrl,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
  }) {
    return OptimizedImageWidget(
      imageUrl: imageUrl,
      fit: fit,
      borderRadius: borderRadius,
      memCacheWidth: 400,
      memCacheHeight: 400,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => _buildMediumPlaceholder(),
      errorWidget: (context, url, error) => _buildMediumErrorWidget(error),
    );
  }

  factory OptimizedImageWidget.large({
    required String imageUrl,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
  }) {
    return OptimizedImageWidget(
      imageUrl: imageUrl,
      fit: fit,
      borderRadius: borderRadius,
      memCacheWidth: 800,
      memCacheHeight: 800,
      maxWidthDiskCache: 1200,
      maxHeightDiskCache: 1200,
      fadeInDuration: const Duration(milliseconds: 400),
      fadeOutDuration: const Duration(milliseconds: 400),
      placeholder: (context, url) => _buildLargePlaceholder(),
      errorWidget: (context, url, error) => _buildLargeErrorWidget(error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
        placeholder: placeholder,
        errorWidget: errorWidget,
        fadeInDuration: fadeInDuration,
        fadeOutDuration: fadeOutDuration,
      ),
    );
  }

  static Widget _buildThumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        ),
      ),
    );
  }

  static Widget _buildThumbnailErrorWidget(dynamic error) {
    String errorCode = '404';
    if (error.toString().contains('timeout')) {
      errorCode = 'TO';
    } else if (error.toString().contains('network')) {
      errorCode = 'NE';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 2),
          Text(
            errorCode,
            style: TextStyle(
              fontSize: 8,
              color: Colors.red.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMediumPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMediumErrorWidget(dynamic error) {
    String errorTitle = 'Failed to load image';
    String errorMessage = 'The image could not be loaded.';

    if (error.toString().contains('404')) {
      errorTitle = 'Image File Not Found';
      errorMessage =
          'The image file has been removed or is no longer available.';
    } else if (error.toString().contains('timeout')) {
      errorTitle = 'Connection Timeout';
      errorMessage =
          'The request to load the image timed out. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      errorTitle = 'Network Error';
      errorMessage = 'There was a network error while loading the image.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget _buildLargePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading prescription...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildLargeErrorWidget(dynamic error) {
    String errorTitle = 'Failed to load prescription image';
    String errorMessage = 'The image could not be loaded.';

    if (error.toString().contains('404')) {
      errorTitle = 'Image File Not Found';
      errorMessage =
          'The prescription image file has been removed or is no longer available on the server.';
    } else if (error.toString().contains('timeout')) {
      errorTitle = 'Connection Timeout';
      errorMessage =
          'The request to load the image timed out. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      errorTitle = 'Network Error';
      errorMessage = 'There was a network error while loading the image.';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
