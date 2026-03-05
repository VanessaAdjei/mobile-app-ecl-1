// widgets/full_screen_image_viewer.dart
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen image viewer with zoom/pan and optional gallery (PageView).
/// Pass [imageUrls] and [initialIndex]. Tap background or close button to dismiss.
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
        ),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    final urls = widget.imageUrls.isEmpty ? [''] : widget.imageUrls;
    final index = widget.initialIndex.clamp(0, urls.length - 1);
    _pageController = PageController(initialPage: index);
    _currentPage = index;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.isEmpty ? [''] : widget.imageUrls;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred backdrop (product details page behind)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: urls.length,
            itemBuilder: (context, i) {
              final url = urls[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Tap outside image to dismiss (product page visible behind)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Image on top so tapping it doesn't dismiss
                  Center(
                    child: GestureDetector(
                      onTap: () {}, // Consume tap
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  size: 64,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : Icon(
                                Icons.image_not_supported_outlined,
                                size: 64,
                                color: Colors.grey.shade600,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey.shade800, size: 24),
                    ),
                  ),
                  if (urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${urls.length}',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
