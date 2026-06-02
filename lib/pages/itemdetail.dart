// pages/itemdetail.dart
import 'package:eclapp/pages/prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import '../models/cart_item.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/config/api_config.dart';
import '../config/app_colors.dart';
import 'package:eclapp/config/app_routes.dart';
import 'package:eclapp/services/auth_service.dart';
import '../providers/cart_provider.dart';
import '../utils/app_error_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_back_button.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/optimized_quantity_button.dart';
import '../services/stock_utility_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_page_optimization_service.dart';
import '../services/product_detail_service.dart';
import '../cache/product_catalog_memory.dart';
import '../utils/product_detail_parser.dart';

class ItemPage extends StatefulWidget {
  final String urlName;
  final bool isPrescribed;

  const ItemPage({
    super.key,
    required this.urlName,
    this.isPrescribed = false,
  });

  @override
  State<ItemPage> createState() => ItemPageState();
}

class ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  static const Color _detailBg = Color(0xFFF4FAF7);
  static const Color _detailBorder = Color(0xFFE5E7EB);
  static const Color _detailGreenBorder = Color(0xFFBBEAD3);
  static const Color _detailGreenTint = Color(0xFFEEF9F3);
  static const Color _detailInk = Color(0xFF1F2937);
  static const Color _detailMuted = Color(0xFF6B7280);
  static const double _pageHPad = 16;
  static const double _relatedCardWidth = 96;
  static const double _relatedListHeight = 128;
  static const double _galleryHeight = 190;

  late Future<Product> _productFuture;
  late Future<List<Product>> _relatedProductsFuture;
  int quantity = 1;
  final int maxQuantity = 99; // Maximum quantity limit
  final uuid = Uuid();
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;
  ScrollController? _relatedProductsScrollController;
  bool _showRelatedScrollHint = false;
  final ScrollController _pageScrollController = ScrollController();
  bool _pageCanScroll = false;

  /// When image URLs change (refresh / new product), reset [PageView] off a stale page index.
  String _appliedGallerySig = '';
  String? _precachedGallerySig;

  // controllers for animations
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // Debouncing for quantity buttons to prevent spam clicking
  DateTime? _lastQuantityUpdateTime;
  static const Duration _quantityUpdateCooldown = Duration(milliseconds: 500);

  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();
  final ProductDetailService _detailService = ProductDetailService();

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // set up the optimization service
    _initializeOptimization();

    _productFuture = _fetchProductDetailsWithCache(widget.urlName);
    _relatedProductsFuture = _fetchRelatedProductsWithCache(widget.urlName);
    _pageScrollController.addListener(_syncPageScrollbar);

    _productFuture.then((product) {
      if (mounted) {
        _scheduleProductImagePrecache(product);
        _schedulePageScrollbarUpdate();
      }
    }).catchError((_) {});

    _relatedProductsFuture.then((products) {
      if (mounted) {
        _scheduleRelatedImagePrecache(products);
        _schedulePageScrollbarUpdate();
      }
    }).catchError((_) {});
  }

  void _initializeOptimization() {
    _optimizationService.trackPagePerformance(
        'item_detail_${widget.urlName}', 'load');
  }

  void _onProductLoaded() {
    _optimizationService.stopPagePerformanceTracking(
      'item_detail_${widget.urlName}',
      'load',
    );
  }

  @override
  void dispose() {
    _imagePageController?.dispose();
    _pageScrollController.removeListener(_syncPageScrollbar);
    _pageScrollController.dispose();
    _relatedProductsScrollController?.removeListener(_syncRelatedScrollHint);
    _relatedProductsScrollController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  ScrollController _relatedProductsScrollControllerFor(int itemCount) {
    if (_relatedProductsScrollController != null) {
      return _relatedProductsScrollController!;
    }
    final controller = ScrollController();
    controller.addListener(_syncRelatedScrollHint);
    _relatedProductsScrollController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRelatedScrollHint();
    });
    return controller;
  }

  void _syncRelatedScrollHint() {
    final controller = _relatedProductsScrollController;
    if (controller == null || !controller.hasClients) return;
    final maxExtent = controller.position.maxScrollExtent;
    final show = maxExtent > 4 && controller.offset < maxExtent - 4;
    if (show != _showRelatedScrollHint && mounted) {
      setState(() => _showRelatedScrollHint = show);
    }
  }

  bool _relatedListIsScrollable(int itemCount) => itemCount > 1;

  void _syncPageScrollbar() => _updatePageScrollbar();

  void _schedulePageScrollbarUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePageScrollbar();
    });
  }

  void _updatePageScrollbar() {
    if (!mounted || !_pageScrollController.hasClients) return;
    final position = _pageScrollController.position;
    if (!position.hasContentDimensions) return;

    final canScroll = position.maxScrollExtent > 1.0;
    if (canScroll != _pageCanScroll) {
      setState(() => _pageCanScroll = canScroll);
    }
  }

  Future<Product> _fetchProductDetailsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'product_details_$urlName',
      () => _detailService.fetchProductDetails(
        urlName,
        catalogFallback: ProductCatalogMemory.hasProducts
            ? ProductCatalogMemory.products
            : const [],
      ),
      pageName: 'item_detail',
    );
    if (result == null) {
      throw Exception('Product not found');
    }
    _onProductLoaded();
    return result;
  }

  Future<List<Product>> _fetchRelatedProductsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'related_products_$urlName',
      () => _detailService.fetchRelatedProducts(urlName),
      pageName: 'item_detail',
    );
    return result ?? [];
  }

  void _scheduleProductImagePrecache(Product product) {
    final urls = _resolvedGalleryUrls(product);
    if (urls.isEmpty) return;
    final sig = urls.join('\x1E');
    if (_precachedGallerySig == sig) return;
    _precachedGallerySig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheImageUrls(context, urls, priorityCount: 2));
    });
  }

  void _scheduleRelatedImagePrecache(List<Product> products) {
    if (products.isEmpty) return;
    final urls = products
        .take(6)
        .map((p) => ApiConfig.getProductImageUrl(p.thumbnail))
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheImageUrls(context, urls, priorityCount: 3));
    });
  }

  Future<void> _precacheImageUrls(
    BuildContext context,
    List<String> urls, {
    int priorityCount = 2,
  }) async {
    if (urls.isEmpty || !context.mounted) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (200 * dpr).round().clamp(240, 600);

    Future<void> loadOne(String url) async {
      if (!context.mounted) return;
      try {
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            maxWidth: cachePx,
            maxHeight: cachePx,
          ),
          context,
        );
      } catch (_) {}
    }

    final priority = urls.take(priorityCount.clamp(0, urls.length));
    for (final url in priority) {
      if (!context.mounted) return;
      await loadOne(url);
    }

    if (!context.mounted) return;
    final rest = urls.skip(priority.length);
    for (final url in rest) {
      if (!context.mounted) return;
      await loadOne(url);
    }
  }

  void _addToCartWithQuantity(BuildContext context, Product product) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    try {
      // Ensure a valid image is always set
      final String defaultImage = 'assets/images/default_product.png';
      final String image =
          (product.thumbnail.isNotEmpty) ? product.thumbnail : defaultImage;
      final cartItem = CartItem(
        // Use server cart ID only; start with empty and update after server response
        id: '',
        productId: product.id.toString(),
        originalProductId: product.id.toString(),
        name: product.name,
        price: double.tryParse(product.price) ?? 0.0,
        quantity: this.quantity,
        image: image,
        batchNo: product.batch_no,
        urlName: product.urlName,
        totalPrice: (double.tryParse(product.price) ?? 0.0) * this.quantity,
      );

      // reset quantity to 1 before adding to cart
      setState(() {
        quantity = 1;
      });

      cartProvider.addToCart(cartItem);

      if (context.mounted) {
        await _flyToCartAnimation(context);
        if (context.mounted && mounted) {
          _scaleController.forward().then((_) {
            if (mounted) _scaleController.reverse();
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        // check if the error is about stock/quantity
        final errorMessage = e.toString();
        String displayMessage;

        if (errorMessage.contains('out of stock') ||
            errorMessage.contains('unavailable') ||
            errorMessage.contains('only has') ||
            errorMessage.contains('units available') ||
            errorMessage.contains('Unable to verify stock')) {
          // Clean up the error message for display
          displayMessage = errorMessage
              .replaceAll('Exception: ', '')
              .replaceAll('Error: ', '')
              .trim();
        } else {
          displayMessage = 'Error adding item to cart. Please try again.';
        }

        _showErrorSnackBar(context, displayMessage);
      }
    }
  }

  Future<void> _flyToCartAnimation(BuildContext context) async {
    if (!context.mounted) return;

    final overlay = Overlay.of(context);

    // find where the add to cart button and cart icon are on screen
    final addToCartBox = context.findRenderObject() as RenderBox?;
    final scaffoldBox =
        Scaffold.maybeOf(context)?.context.findRenderObject() as RenderBox?;

    // if we cant find them, just use center bottom and top right
    final start = addToCartBox != null && scaffoldBox != null
        ? addToCartBox.localToGlobal(addToCartBox.size.centerLeft(Offset.zero))
        : Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height - 80);
    final end = Offset(MediaQuery.of(context).size.width - 40, 40);

    final animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    final curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    final tween = Tween<Offset>(begin: start, end: end);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final pos = tween.evaluate(curvedAnimation);
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: Icon(
                Icons.add_shopping_cart,
                color: Colors.green.shade700,
                size: 36,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    overlay.insert(entry);
    try {
      await animationController.forward();
    } finally {
      entry.remove();
      animationController.dispose();
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    AppErrorUtils.showSnack(context, message);
  }

  String _productDisplayName(Product product) {
    final full = product.name.trim();
    if (full.isNotEmpty) return full;
    final fromSlug = product.urlName.replaceAll('-', ' ').trim();
    return fromSlug.isEmpty ? 'Product' : fromSlug;
  }

  BoxDecoration _detailCardDecoration({
    Color? bg,
    bool accentTop = false,
  }) =>
      BoxDecoration(
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentTop ? _detailGreenBorder : _detailBorder,
        ),
      );

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleStyle()),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: _sectionCaptionStyle()),
        ],
      ],
    );
  }

  TextStyle _sectionTitleStyle() => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _detailInk,
      );

  TextStyle _sectionCaptionStyle() => GoogleFonts.poppins(
        fontSize: 11,
        color: _detailMuted,
        height: 1.35,
      );

  Widget _buildItemSliverAppBar({Product? product}) {
    final loading = product == null;

    return EclExpandableSliverAppBar(
      toolbarTitle: loading ? 'Product' : '',
      heroTitle: loading ? 'Product' : _productDisplayName(product),
      heroSubtitle: loading ? 'Loading details…' : null,
      centerTitle: true,
      expandedHeight:
          loading ? null : kToolbarHeight + _headerExpandedFlexHeight(product),
      expandedTitleWidget: loading ? null : _buildHeaderProductName(product),
      expandedTitleAlignment: const Alignment(0, 0.08),
      toolbarTitleStyle: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: BackButtonUtils.withConfirmation(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          title: 'Leave Product',
          message: 'Are you sure you want to leave this product page?',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 22,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  double _headerExpandedFlexHeight(Product product) {
    final hasCategory = product.category.trim().isNotEmpty;
    final longName = _productDisplayName(product).length > 34;
    var height = 2.0 + (longName ? 32.0 : 16.0) + 4.0 + 2.0 + 2.0;
    if (hasCategory) height += 14.0;
    return height;
  }

  Widget _buildHeaderProductName(Product product) {
    final displayName = _productDisplayName(product);
    final category = product.category.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (category.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              child: Text(
                category.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isPrescriptionProduct(Product product) =>
      widget.isPrescribed || product.otcpom?.toLowerCase() == 'pom';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError && kDebugMode) {
          debugPrint('item_detail FutureBuilder: ${snapshot.error}');
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _detailBg,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: BackButtonUtils.simple(),
              title: Text(
                'Product',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            body: _buildErrorState(snapshot.error.toString()),
          );
        }

        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(0xFFF5F7F6),
              body: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _buildItemSliverAppBar(),
                  SliverToBoxAdapter(
                    child: _buildLoadingSkeleton(),
                  ),
                ],
              ),
            );
          }
          return Scaffold(
            backgroundColor: _detailBg,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: BackButtonUtils.simple(),
            ),
            body: _buildErrorState('Product not found'),
          );
        }

        return _buildProductScaffold(snapshot.data!);
      },
    );
  }

  Widget _buildProductScaffold(Product product) {
    _schedulePageScrollbarUpdate();

    return Scaffold(
      backgroundColor: _detailBg,
      body: RefreshIndicator(
        onRefresh: () async {
          _precachedGallerySig = null;
          _relatedProductsScrollController
              ?.removeListener(_syncRelatedScrollHint);
          _relatedProductsScrollController?.dispose();
          _relatedProductsScrollController = null;
          _showRelatedScrollHint = false;
          setState(() {
            _productFuture = _fetchProductDetailsWithCache(widget.urlName);
            _relatedProductsFuture =
                _fetchRelatedProductsWithCache(widget.urlName);
          });
          _productFuture.then((p) {
            if (mounted) {
              _scheduleProductImagePrecache(p);
              _schedulePageScrollbarUpdate();
            }
          }).catchError((_) {});
          _relatedProductsFuture.then((products) {
            if (mounted) {
              _scheduleRelatedImagePrecache(products);
              _schedulePageScrollbarUpdate();
            }
          }).catchError((_) {});
          await _productFuture;
          _schedulePageScrollbarUpdate();
        },
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              _updatePageScrollbar();
            }
            return false;
          },
          child: Scrollbar(
            controller: _pageScrollController,
            thumbVisibility: _pageCanScroll,
            radius: const Radius.circular(4),
            thickness: 4,
            child: CustomScrollView(
              controller: _pageScrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildItemSliverAppBar(product: product),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProductImageGallery(product),
                        _buildProductHeroSection(product),
                        _buildDescriptionSection(product),
                        _buildRelatedProductsSection(product),
                        const SizedBox(height: 84),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildPurchaseBottomBar(product),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: _galleryHeight,
              color: _detailGreenTint,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_pageHPad, 10, _pageHPad, 0),
              child: Center(
                child: Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(_pageHPad),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final kind = AppErrorUtils.classifyProductError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppErrorUtils.productDetailIcon(kind),
              size: 56,
              color: kind == ProductDetailErrorKind.offline
                  ? Colors.orange.shade600
                  : Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              AppErrorUtils.productDetailTitle(kind),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppErrorUtils.productDetailMessageFromError(error),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _productFuture =
                          _fetchProductDetailsWithCache(widget.urlName);
                      _relatedProductsFuture =
                          _fetchRelatedProductsWithCache(widget.urlName);
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Go back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Absolute URLs for gallery + single thumbnail fallback.
  List<String> _resolvedGalleryUrls(Product product) {
    final fromGallery = orderProductGalleryUrlsForDisplay(
      product.galleryImages
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => ApiConfig.getProductImageUrl(e))
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    if (fromGallery.length == 2) return [fromGallery.first];
    if (fromGallery.isNotEmpty) return fromGallery;
    final t = product.thumbnail.trim();
    if (t.isEmpty) return <String>[];
    final u = ApiConfig.getProductImageUrl(t);
    return u.isEmpty ? <String>[] : [u];
  }

  Widget _buildProductImageGallery(Product product) {
    final imageUrls = _resolvedGalleryUrls(product);
    _scheduleProductImagePrecache(product);
    final gallerySig = '${product.id}|${imageUrls.join('\x1E')}';
    if (_appliedGallerySig != gallerySig) {
      _appliedGallerySig = gallerySig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_imagePageController?.hasClients ?? false) {
          _imagePageController!.jumpToPage(0);
        }
        if (_currentImageIndex != 0) {
          setState(() => _currentImageIndex = 0);
        }
      });
    }

    return GestureDetector(
      onTap: imageUrls.isEmpty
          ? null
          : () => FullScreenImageViewer.show(
                context,
                imageUrls: imageUrls,
                initialIndex: _currentImageIndex.clamp(0, imageUrls.length - 1),
              ),
      child: SizedBox(
        height: _galleryHeight,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ColoredBox(
              color: _detailGreenTint,
              child: PageView.builder(
                controller: _imagePageController,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = imageUrls.isEmpty ? '' : imageUrls[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    child: Hero(
                      tag: 'product-image-${product.id}-${product.urlName}',
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 700,
                              memCacheHeight: 700,
                              fadeInDuration: index == 0
                                  ? Duration.zero
                                  : const Duration(milliseconds: 150),
                              fadeOutDuration: Duration.zero,
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _galleryPlaceholder(),
                            )
                          : _galleryPlaceholder(),
                    ),
                  );
                },
              ),
            ),
            if (imageUrls.length > 1)
              Positioned(
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageUrls.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _currentImageIndex == index ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _currentImageIndex == index
                            ? AppColors.primary
                            : const Color(0xFFD1E7DD),
                      ),
                    ),
                  ),
                ),
              ),
            if (imageUrls.isNotEmpty)
              Positioned(
                right: _pageHPad,
                bottom: 10,
                child: Icon(
                  Icons.zoom_in_rounded,
                  size: 20,
                  color: AppColors.primaryDark.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _galleryPlaceholder() {
    return Center(
      child: Icon(
        Icons.medical_services_outlined,
        size: 32,
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildProductHeroSection(Product product) {
    final isPrescription = _isPrescriptionProduct(product);
    final inStock = StockUtilityService.isProductInStock(product.quantity);
    final price = double.tryParse(product.price) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_pageHPad, 10, _pageHPad, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GHS ${price.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          if (product.uom != null && product.uom!.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              '/ ${product.uom}',
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: _detailMuted,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            '·',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: _detailMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            inStock ? 'In stock' : 'Out of stock',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: inStock ? AppColors.primaryDark : const Color(0xFFB45309),
            ),
          ),
          if (isPrescription) ...[
            const SizedBox(width: 8),
            Text(
              '·',
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: _detailMuted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Rx required',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF991B1B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required Color fg,
    bool green = false,
    Color? tint,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint ?? (green ? _detailGreenTint : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: border ?? (green ? _detailGreenBorder : _detailBorder),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(Product product) {
    if (product.description.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(_pageHPad, 10, _pageHPad, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _detailGreenTint.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _detailGreenBorder.withValues(alpha: 0.75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Text(
                'Product details',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _detailInk,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: _detailGreenBorder.withValues(alpha: 0.8),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: ProductDescription(
                description: product.description,
                fadeColor: _detailGreenTint.withValues(alpha: 0.95),
                chipBorderColor: _detailGreenBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseBottomBar(Product product) {
    final isPrescription = _isPrescriptionProduct(product);
    final price = double.tryParse(product.price) ?? 0.0;

    return Selector<CartProvider, bool>(
      selector: (_, cart) => CartProvider.selectIsProductInCart(
        cart,
        productName: product.name,
        batchNo: product.batch_no,
      ),
      builder: (context, isInCart, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            _pageHPad,
            10,
            _pageHPad,
            8 + MediaQuery.paddingOf(context).bottom,
          ),
          child: isInCart
              ? _buildInCartBottomBar(context, product, price)
              : _buildAddToCartBottomBar(
                  context, product, isPrescription, price),
        );
      },
    );
  }

  Widget _buildAddToCartBottomBar(
    BuildContext context,
    Product product,
    bool isPrescription,
    double price,
  ) {
    final accent = isPrescription ? const Color(0xFFB91C1C) : AppColors.primary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(fontSize: 10, color: _detailMuted),
              ),
              Text(
                'GHS ${price.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                if (isPrescription) {
                  final token = await AuthService.getToken();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrescriptionUploadPage(
                        token: token ?? 'guest-temp-token',
                        item: {
                          'product': {
                            'name': product.name,
                            'thumbnail': product.thumbnail,
                            'id': product.id,
                          },
                          'price': product.price,
                          'batch_no': product.batch_no,
                        },
                      ),
                    ),
                  );
                } else {
                  _addToCartWithQuantity(context, product);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                isPrescription
                    ? Icons.upload_file_outlined
                    : Icons.add_shopping_cart_outlined,
                size: 18,
              ),
              label: Text(
                isPrescription ? 'Upload prescription' : 'Add to cart',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInCartBottomBar(
    BuildContext context,
    Product product,
    double price,
  ) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => CartProvider.selectQuantityForProduct(
        cart,
        productName: product.name,
        batchNo: product.batch_no,
      ),
      builder: (context, cartQuantity, _) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final productNameNorm = CartProvider.normalizeProductName(product.name);
        final cartItems = cartProvider.cartItems;
        final existingItem = cartItems.cast<CartItem>().where(
              (item) =>
                  CartProvider.normalizeProductName(item.name) ==
                      productNameNorm &&
                  item.batchNo == product.batch_no,
            );
        final line = existingItem.isNotEmpty ? existingItem.first : null;
        if (line == null) return const SizedBox.shrink();

        final itemIndex = cartItems.indexWhere((item) =>
            CartProvider.normalizeProductName(item.name) == productNameNorm &&
            item.batchNo == product.batch_no);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'In cart',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _detailMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  'GHS ${(price * cartQuantity).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _detailGreenBorder),
                    color: _detailGreenTint,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OptimizedRemoveButton(
                        onPressed: (cartQuantity > 1 &&
                                !cartProvider.isItemUpdating(line.id))
                            ? () {
                                final now = DateTime.now();
                                if (_lastQuantityUpdateTime != null &&
                                    now.difference(_lastQuantityUpdateTime!) <
                                        _quantityUpdateCooldown) {
                                  return;
                                }
                                _lastQuantityUpdateTime = now;
                                if (line.id.isNotEmpty) {
                                  cartProvider.updateQuantityById(
                                      line.id, cartQuantity - 1);
                                } else if (itemIndex >= 0) {
                                  cartProvider.updateQuantity(
                                      itemIndex, cartQuantity - 1);
                                }
                              }
                            : null,
                        isEnabled: cartQuantity > 1 &&
                            !cartProvider.isItemUpdating(line.id),
                        size: 32,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          cartQuantity.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      OptimizedAddButton(
                        onPressed: (cartQuantity < maxQuantity &&
                                !cartProvider.isItemUpdating(line.id))
                            ? () async {
                                final now = DateTime.now();
                                if (_lastQuantityUpdateTime != null &&
                                    now.difference(_lastQuantityUpdateTime!) <
                                        _quantityUpdateCooldown) {
                                  return;
                                }
                                _lastQuantityUpdateTime = now;
                                HapticFeedback.mediumImpact();
                                final incrementItem = CartItem(
                                  id: line.id,
                                  productId: product.id.toString(),
                                  originalProductId: product.id.toString(),
                                  serverProductId: line.serverProductId,
                                  name: line.name,
                                  price: line.price,
                                  quantity: 1,
                                  image: line.image,
                                  batchNo: product.batch_no.isNotEmpty
                                      ? product.batch_no
                                      : line.batchNo,
                                  urlName: line.urlName,
                                  totalPrice: line.price,
                                );
                                cartProvider.addToCart(incrementItem);
                                if (context.mounted) {
                                  await _flyToCartAnimation(context);
                                  if (context.mounted && mounted) {
                                    _scaleController.forward().then((_) {
                                      if (mounted) _scaleController.reverse();
                                    });
                                  }
                                }
                              }
                            : null,
                        isEnabled: cartQuantity < maxQuantity &&
                            !cartProvider.isItemUpdating(line.id),
                        size: 32,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.cart);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View cart',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRelatedSwipeHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildRelatedProductsList(List<Product> relatedProducts) {
    final scrollable = _relatedListIsScrollable(relatedProducts.length);
    final controller = scrollable
        ? _relatedProductsScrollControllerFor(relatedProducts.length)
        : null;

    final list = ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(right: scrollable ? 36 : 0),
      physics: scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: relatedProducts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) => _buildRelatedProductCard(
        relatedProducts[index],
        context,
      ),
    );

    if (!scrollable) {
      return SizedBox(height: _relatedListHeight, child: list);
    }

    return SizedBox(
      height: _relatedListHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          list,
          if (_showRelatedScrollHint)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _detailBg.withValues(alpha: 0),
                        _detailBg.withValues(alpha: 0.75),
                        _detailBg,
                      ],
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _detailGreenBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductsSection(Product product) {
    return Container(
      color: _detailBg,
      padding: const EdgeInsets.fromLTRB(_pageHPad, 20, _pageHPad, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<Product>>(
            future: _relatedProductsFuture,
            builder: (context, relatedSnapshot) {
              final relatedProducts = relatedSnapshot.data ?? [];
              final showSwipeHint =
                  relatedSnapshot.connectionState == ConnectionState.done &&
                      !relatedSnapshot.hasError &&
                      _relatedListIsScrollable(relatedProducts.length);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionHeader(
                      'You may also like',
                      subtitle:
                          showSwipeHint ? 'Swipe for more' : 'Similar items',
                    ),
                  ),
                  if (showSwipeHint && _showRelatedScrollHint)
                    _buildRelatedSwipeHint(),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Product>>(
            future: _relatedProductsFuture,
            builder: (context, relatedSnapshot) {
              if (relatedSnapshot.connectionState == ConnectionState.waiting) {
                return _buildRelatedProductsSkeleton();
              }

              if (relatedSnapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline,
                  title: 'Couldn\'t load suggestions',
                  message: 'Pull down to refresh and try again',
                  color: Colors.red.shade400,
                );
              }

              final relatedProducts = relatedSnapshot.data ?? [];
              if (relatedProducts.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'No suggestions yet',
                  message: 'Check back later for similar products',
                  color: Colors.grey.shade400,
                );
              }

              return _buildRelatedProductsList(relatedProducts);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductsSkeleton() {
    return SizedBox(
      height: _relatedListHeight,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(right: 36),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: _relatedCardWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _detailBorder),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _detailBg.withValues(alpha: 0),
                      _detailBg.withValues(alpha: 0.75),
                      _detailBg,
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _detailGreenBorder),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _detailBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductCard(Product product, BuildContext context) {
    final imageUrl = ApiConfig.getProductImageUrl(product.thumbnail);
    final name = product.name.trim().isEmpty
        ? product.urlName.replaceAll('-', ' ')
        : product.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.itemDetail,
            arguments: {
              'urlName': product.urlName,
              'isPrescribed': product.otcpom?.toLowerCase() == 'pom',
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: _relatedCardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _detailBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(11)),
                      child: ColoredBox(
                        color: _detailGreenTint,
                        child: product.thumbnail.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                memCacheWidth: 192,
                                memCacheHeight: 192,
                                placeholder: (context, url) =>
                                    const SizedBox.shrink(),
                                errorWidget: (context, url, error) =>
                                    _galleryPlaceholder(),
                              )
                            : _galleryPlaceholder(),
                      ),
                    ),
                    if (product.otcpom?.toLowerCase() == 'pom')
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            'Rx',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF991B1B),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        height: 1.25,
                        color: _detailInk,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GHS ${product.price}',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
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
}

class ItemPageSkeleton extends StatelessWidget {
  const ItemPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
        leading: BackButtonUtils.simple(
          backgroundColor: Colors.grey[400] ?? Colors.grey,
        ),
        title: Container(
          width: 200,
          height: 24,
          color: Colors.white,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[400],
            ),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 1, bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // product image skeleton
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.white,
              ),

              Container(
                width: 100,
                height: 24,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Container(
                          width: 100,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Container(
                          width: 120,
                          height: 20,
                          color: Colors.white,
                        ),
                      ),
                      const Divider(height: 24, thickness: 1),
                      const SizedBox(height: 8),

                      // description skeleton
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          5,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: index == 4 ? 100 : double.infinity,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: 150,
                  height: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(left: 10, right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 80,
                            height: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDescription extends StatefulWidget {
  final String description;
  final Color? fadeColor;
  final Color? chipBorderColor;

  const ProductDescription({
    super.key,
    required this.description,
    this.fadeColor,
    this.chipBorderColor,
  });

  @override
  State<ProductDescription> createState() => _ProductDescriptionState();
}

class _ProductDescriptionState extends State<ProductDescription> {
  bool _expanded = false;
  final double _collapsedHeight = 200;
  final HtmlEscape _htmlEscape = const HtmlEscape();

  /// [flutter_html] maps `font-feature-settings` to [FontFeature]; CMS values like
  /// `normal` become `FontFeature.enable("normal")` and crash (tag must be 4 chars).
  /// Renaming the property avoids parsing entirely (unknown CSS keys are ignored).
  String _sanitizeRichHtmlForFlutterHtml(String html) {
    if (html.isEmpty) return html;
    return html
        .replaceAll(
            RegExp(r'font-feature-settings', caseSensitive: false), '_ffs_x_')
        .replaceAll(RegExp(r'font-variation-settings', caseSensitive: false),
            '_fvs_x_');
  }

  String _cleanIncomingHtml(String html) {
    var out = html.trim();
    if (out.isEmpty) return out;

    out = out.replaceAll(
        RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    out = out.replaceAll(RegExp(r'\sstyle="[^"]*"', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r"\sstyle='[^']*'", caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\sclass="[^"]*"', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'<span[^>]*>', caseSensitive: false), '');
    out = out.replaceAll('</span>', '');
    out = out.replaceAll(
        RegExp(r'(<br\s*/?>\s*){3,}', caseSensitive: false), '<br><br>');
    out = out.replaceAll(RegExp(r'>\s+<'), '><');

    return _sanitizeRichHtmlForFlutterHtml(out);
  }

  bool _isSectionHeaderLine(String line) {
    if (line.length > 48) return false;
    if (RegExp(r'^#{1,4}\s+').hasMatch(line)) return true;
    if (RegExp(r'^.{1,40}:$').hasMatch(line)) return true;
    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length >= 3 &&
        letters == letters.toUpperCase() &&
        line.length <= 36) {
      return true;
    }
    return false;
  }

  String _plainLineToHtml(String line) {
    final markdownHeading = RegExp(r'^(#{1,4})\s+(.+)$').firstMatch(line);
    if (markdownHeading != null) {
      final level = markdownHeading.group(1)!.length.clamp(1, 4);
      final text = markdownHeading.group(2)!.trim();
      return '<h$level>${_htmlEscape.convert(text)}</h$level>';
    }

    if (_isSectionHeaderLine(line)) {
      final text = line.endsWith(':') ? line : line.trim();
      return '<h4>${_htmlEscape.convert(text)}</h4>';
    }

    final keyValue = RegExp(r'^([^:\n]{2,40}):\s*(.+)$').firstMatch(line);
    if (keyValue != null) {
      final key = keyValue.group(1)!.trim();
      final value = keyValue.group(2)!.trim();
      return '<p><strong>${_htmlEscape.convert(key)}:</strong> '
          '${_htmlEscape.convert(value)}</p>';
    }

    return '<p>${_htmlEscape.convert(line)}</p>';
  }

  String _normalizeDescriptionToHtml(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final hasHtmlTag = RegExp(r'<[a-zA-Z][^>]*>').hasMatch(trimmed);
    if (hasHtmlTag) return _cleanIncomingHtml(trimmed);

    final lines =
        trimmed.split(RegExp(r'\r?\n')).map((line) => line.trim()).toList();

    if (lines.every((line) => line.isEmpty)) {
      return '<p>${_htmlEscape.convert(trimmed)}</p>';
    }

    final buffer = StringBuffer();
    bool inBulletList = false;
    bool inNumberedList = false;

    void closeLists() {
      if (inBulletList) {
        buffer.writeln('</ul>');
        inBulletList = false;
      }
      if (inNumberedList) {
        buffer.writeln('</ol>');
        inNumberedList = false;
      }
    }

    for (final line in lines) {
      if (line.isEmpty) {
        closeLists();
        continue;
      }

      final bulletMatch = RegExp(r'^(\-|\*|•)\s+').firstMatch(line);
      if (bulletMatch != null) {
        if (inNumberedList) {
          buffer.writeln('</ol>');
          inNumberedList = false;
        }
        if (!inBulletList) {
          buffer.writeln('<ul>');
          inBulletList = true;
        }
        final cleanLine = line.replaceFirst(RegExp(r'^(\-|\*|•)\s+'), '');
        buffer.writeln('<li>${_htmlEscape.convert(cleanLine)}</li>');
        continue;
      }

      final numberedMatch = RegExp(r'^\d+[\.\)]\s+').firstMatch(line);
      if (numberedMatch != null) {
        if (inBulletList) {
          buffer.writeln('</ul>');
          inBulletList = false;
        }
        if (!inNumberedList) {
          buffer.writeln('<ol>');
          inNumberedList = true;
        }
        final cleanLine = line.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '');
        buffer.writeln('<li>${_htmlEscape.convert(cleanLine)}</li>');
        continue;
      }

      closeLists();
      buffer.writeln(_plainLineToHtml(line));
    }

    closeLists();
    return buffer.toString().trim();
  }

  Map<String, Style> _descriptionHtmlStyles() {
    const bodyColor = Color(0xFF374151);
    const mutedColor = Color(0xFF6B7280);
    final accentBorder = widget.chipBorderColor ?? const Color(0xFFBBEAD3);

    return {
      'body': Style(
        fontSize: FontSize(13),
        color: bodyColor,
        lineHeight: LineHeight.number(1.35),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      'p': Style(
        fontSize: FontSize(13),
        color: bodyColor,
        lineHeight: LineHeight.number(1.35),
        margin: Margins.only(bottom: 8),
      ),
      'h1': Style(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
        fontSize: FontSize(15),
        margin: Margins.only(top: 2, bottom: 5),
        lineHeight: LineHeight.number(1.15),
      ),
      'h2': Style(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
        fontSize: FontSize(14),
        margin: Margins.only(top: 2, bottom: 5),
        lineHeight: LineHeight.number(1.15),
      ),
      'h3, h4': Style(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
        fontSize: FontSize(12),
        letterSpacing: 0.2,
        margin: Margins.only(top: 8, bottom: 3),
        lineHeight: LineHeight.number(1.15),
      ),
      'ul, ol': Style(
        padding: HtmlPaddings.only(left: 18),
        margin: Margins.only(top: 2, bottom: 8),
      ),
      'li': Style(
        fontSize: FontSize(13),
        color: bodyColor,
        lineHeight: LineHeight.number(1.35),
        margin: Margins.only(bottom: 4),
        display: Display.listItem,
      ),
      'strong, b': Style(
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDark,
      ),
      'em, i': Style(
        fontStyle: FontStyle.italic,
        color: mutedColor,
      ),
      'a': Style(
        color: AppColors.primary,
        textDecoration: TextDecoration.underline,
        textDecorationColor: AppColors.primary,
      ),
      'blockquote': Style(
        border: Border(
          left: BorderSide(color: accentBorder, width: 3),
        ),
        padding: HtmlPaddings.only(left: 12),
        margin: Margins.only(top: 4, bottom: 10),
        color: mutedColor,
        fontStyle: FontStyle.italic,
      ),
      'hr': Style(
        margin: Margins.symmetric(vertical: 10),
        border: Border(
          top: BorderSide(color: accentBorder, width: 1),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final description = _normalizeDescriptionToHtml(widget.description);
    if (description.isEmpty) {
      return Text(
        'No description available.',
        style: GoogleFonts.poppins(
          fontStyle: FontStyle.italic,
          fontSize: 12,
          color: const Color(0xFF6B7280),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final htmlWidget = Html(
          data: description,
          style: _descriptionHtmlStyles(),
        );

        return _ExpandableHtml(
          htmlWidget: htmlWidget,
          expanded: _expanded,
          collapsedHeight: _collapsedHeight,
          fadeColor: widget.fadeColor ?? Colors.white,
          chipBorderColor: widget.chipBorderColor ?? const Color(0xFFE5E7EB),
          onToggle: () => setState(() => _expanded = !_expanded),
        );
      },
    );
  }
}

class _ExpandableHtml extends StatefulWidget {
  final Widget htmlWidget;
  final bool expanded;
  final double collapsedHeight;
  final Color fadeColor;
  final Color chipBorderColor;
  final VoidCallback onToggle;

  const _ExpandableHtml({
    required this.htmlWidget,
    required this.expanded,
    required this.collapsedHeight,
    required this.fadeColor,
    required this.chipBorderColor,
    required this.onToggle,
  });

  @override
  State<_ExpandableHtml> createState() => _ExpandableHtmlState();
}

class _ExpandableHtmlState extends State<_ExpandableHtml> {
  final GlobalKey _key = GlobalKey();
  double? _fullHeight;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final ctx = _key.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && mounted) {
        setState(() {
          _fullHeight = box.size.height;
          _showButton = _fullHeight! > widget.collapsedHeight + 8;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFade = _showButton && !widget.expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: widget.expanded || !_showButton
                  ? const BoxConstraints(maxHeight: 10000)
                  : BoxConstraints(maxHeight: widget.collapsedHeight),
              child: Container(key: _key, child: widget.htmlWidget),
            ),
            if (showFade)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.fadeColor.withValues(alpha: 0),
                          widget.fadeColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_showButton) ...[
          const SizedBox(height: 8),
          Center(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: widget.chipBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.expanded ? 'Show less' : 'Read full details',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CategoryAndTagsWidget extends StatelessWidget {
  final String category;
  final List<String> tags;

  const CategoryAndTagsWidget({
    super.key,
    required this.category,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty)
          Row(
            children: [
              const Text(
                "Category: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tags: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => TagChip(tag: tag)).toList(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  final String tag;

  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
