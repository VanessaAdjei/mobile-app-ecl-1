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
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/item_detail_sliver_header.dart';
import '../widgets/item_detail/item_detail_design.dart';
import '../widgets/optimized_quantity_button.dart';
import '../services/stock_utility_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_page_optimization_service.dart';
import '../services/product_detail_service.dart';
import '../services/prescription_upload_status_service.dart';
import '../services/recently_viewed_service.dart';
import '../utils/product_detail_parser.dart';
import '../utils/product_detail_navigation.dart';
import '../utils/product_tap_guard.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/item_detail_rx_hint.dart';

const _leaveProductTitle = 'Leave Product';
const _leaveProductMessage =
    'Are you sure you want to leave this product page?';

class ItemPage extends StatefulWidget {
  final String urlName;
  final bool isPrescribed;
  final bool fromProductCard;

  const ItemPage({
    super.key,
    required this.urlName,
    this.isPrescribed = false,
    this.fromProductCard = false,
  });

  @override
  State<ItemPage> createState() => ItemPageState();
}

class ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  static const double _pageHPad = ItemDetailDesign.pagePadding;
  static const double _relatedCardWidth = 108;
  static const double _relatedListHeight = 148;
  static const double _relatedSeparatorWidth = 8;
  static const double _recentCardWidth = 114;
  static const int _recentMaxCards = 6;
  static const int _relatedLoopRepeats = 3;
  static const int _recentLoopRepeats = 3;
  static const double _galleryHeight = 220;

  // Slightly larger type for readability on product detail.
  static const double _fsToolbarTitle = 17;
  static const double _fsBody = 15;
  static const double _fsBodyMedium = 14;
  static const double _fsCaption = 12;
  static const double _fsSmall = 11;
  static const double _fsChip = 12;
  static const double _fsHeroPrice = 16;
  static const double _fsPriceLarge = 18;
  static const double _fsButton = 15;

  late Future<Product> _productFuture;
  late Future<List<Product>> _relatedProductsFuture;
  List<Product> _recentlyViewedItems = const [];
  String? _recentlyViewedPreparedSlug;
  int quantity = 1;
  final int maxQuantity = 99; // Maximum quantity limit
  final uuid = Uuid();
  bool isDescriptionExpanded = false;
  PageController? _imagePageController;
  int _currentImageIndex = 0;
  ScrollController? _relatedProductsScrollController;
  double _relatedLoopSegmentWidth = 0;
  bool _relatedLoopScrollInitialized = false;
  Timer? _relatedAutoScrollTimer;
  Timer? _relatedAutoScrollResumeTimer;
  bool _relatedAutoScrollPausedByUser = false;
  static const Duration _relatedAutoScrollInterval = Duration(seconds: 3);
  static const double _relatedScrollStep = _relatedCardWidth + 8;
  ScrollController? _recentlyViewedScrollController;
  double _recentLoopSegmentWidth = 0;
  bool _recentLoopScrollInitialized = false;
  Timer? _recentAutoScrollTimer;
  Timer? _recentAutoScrollResumeTimer;
  bool _recentAutoScrollPausedByUser = false;
  static const Duration _recentAutoScrollInterval = Duration(seconds: 3);
  static const double _recentScrollStep =
      _recentCardWidth + _relatedSeparatorWidth;
  final ScrollController _pageScrollController = ScrollController();
  bool _pageCanScroll = false;
  bool _prescriptionUploaded = false;
  bool _rxHintScheduled = false;
  final GlobalKey _rxUploadButtonKey = GlobalKey();
  final FocusNode _headerSearchFocusNode = FocusNode();

  /// When image URLs change (refresh / new product), reset [PageView] off a stale page index.
  String _appliedGallerySig = '';
  String? _precachedGallerySig;

  // controllers for animations
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // Debouncing for quantity buttons to prevent spam clicking
  DateTime? _lastQuantityUpdateTime;
  static const Duration _quantityUpdateCooldown = Duration(milliseconds: 200);

  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();
  final ProductDetailService _detailService = ProductDetailService();
  final RecentlyViewedService _recentlyViewedService = RecentlyViewedService();

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

    ProductDetailService.warmProductDetails(widget.urlName);
    _productFuture = _fetchProductDetailsFromApi(widget.urlName);
    _relatedProductsFuture = _fetchRelatedProductsWithCache(widget.urlName);
    _pageScrollController.addListener(_syncPageScrollbar);
    unawaited(_loadRecentlyViewedPreview());

    _relatedProductsFuture.then((products) {
      if (mounted) {
        _scheduleRelatedImagePrecache(products);
        _schedulePageScrollbarUpdate();
      }
    }).catchError((_) {});

    _productFuture.then((product) {
      if (mounted) {
        _scheduleProductImagePrecache(product);
        _schedulePageScrollbarUpdate();
        unawaited(_refreshPrescriptionUploadStatus(product));
        _ensureRecentlyViewedLoaded(product);
      }
    }).catchError((_) {});

  }

  /// Shows prior visits from disk before the current product API finishes.
  Future<void> _loadRecentlyViewedPreview() async {
    final slug = widget.urlName.trim();
    if (slug.isEmpty) return;
    try {
      final items = await _recentlyViewedService.getRecent(excludeUrlName: slug);
      if (!mounted || items.isEmpty) return;
      if (widget.urlName.trim().toLowerCase() != slug.toLowerCase()) return;
      _resetRecentlyViewedScroll();
      setState(() => _recentlyViewedItems = _capRecentItems(items));
    } catch (_) {}
  }

  void _ensureRecentlyViewedLoaded(Product product) {
    final slug = product.urlName.trim();
    if (slug.isEmpty) return;
    if (_recentlyViewedPreparedSlug == slug) return;
    _recentlyViewedPreparedSlug = slug;
    unawaited(_refreshRecentlyViewed(product));
  }

  Future<void> _refreshRecentlyViewed(Product product) async {
    final slug = product.urlName.trim().toLowerCase();
    if (slug.isEmpty) return;
    try {
      final items = await _recentlyViewedService.recordAndLoadOthers(product);
      if (!mounted) return;
      if (widget.urlName.trim().toLowerCase() != slug) return;
      _resetRecentlyViewedScroll();
      setState(() => _recentlyViewedItems = _capRecentItems(items));
      if (items.isNotEmpty) {
        _scheduleRelatedImagePrecache(items);
      }
    } catch (_) {
      if (!mounted) return;
      if (widget.urlName.trim().toLowerCase() == slug) {
        _resetRecentlyViewedScroll();
        setState(() => _recentlyViewedItems = const []);
      }
    }
  }

  List<Product> _capRecentItems(List<Product> items) {
    if (items.length <= _recentMaxCards) return items;
    return items.take(_recentMaxCards).toList();
  }

  void _resetRecentlyViewedScroll() {
    _stopRecentAutoScroll();
    _recentAutoScrollResumeTimer?.cancel();
    _recentlyViewedScrollController?.removeListener(_onRecentScrollChanged);
    _recentlyViewedScrollController?.dispose();
    _recentlyViewedScrollController = null;
    _recentLoopScrollInitialized = false;
    _recentLoopSegmentWidth = 0;
    _recentAutoScrollPausedByUser = false;
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
    _stopRelatedAutoScroll();
    _relatedAutoScrollResumeTimer?.cancel();
    _relatedProductsScrollController?.removeListener(_onRelatedScrollChanged);
    _relatedProductsScrollController?.dispose();
    _resetRecentlyViewedScroll();
    _fadeController.dispose();
    _scaleController.dispose();
    _headerSearchFocusNode.dispose();
    super.dispose();
  }

  double _relatedLoopSegmentWidthFor(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * _relatedCardWidth +
        (itemCount - 1) * _relatedSeparatorWidth;
  }

  void _onRelatedScrollChanged() => _normalizeRelatedScrollOffset();

  void _normalizeRelatedScrollOffset() {
    final controller = _relatedProductsScrollController;
    if (controller == null || !controller.hasClients) return;
    final segment = _relatedLoopSegmentWidth;
    if (segment <= 0) return;

    final offset = controller.offset;
    if (offset >= segment * 2 - 2) {
      controller.jumpTo(offset - segment);
    } else if (offset < segment * 0.5) {
      controller.jumpTo(offset + segment);
    }
  }

  void _initializeRelatedLoopScroll() {
    final controller = _relatedProductsScrollController;
    if (controller == null ||
        !controller.hasClients ||
        _relatedLoopScrollInitialized) {
      return;
    }
    final segment = _relatedLoopSegmentWidth;
    if (segment <= 0) return;
    controller.jumpTo(segment);
    _relatedLoopScrollInitialized = true;
  }

  ScrollController _relatedProductsScrollControllerFor(int itemCount) {
    if (_relatedProductsScrollController != null) {
      return _relatedProductsScrollController!;
    }
    final controller = ScrollController();
    controller.addListener(_onRelatedScrollChanged);
    _relatedProductsScrollController = controller;
    return controller;
  }

  void _stopRelatedAutoScroll() {
    _relatedAutoScrollTimer?.cancel();
    _relatedAutoScrollTimer = null;
  }

  void _startRelatedAutoScroll(int itemCount) {
    _stopRelatedAutoScroll();
    if (!_relatedListIsScrollable(itemCount)) return;

    _relatedAutoScrollTimer = Timer.periodic(
      _relatedAutoScrollInterval,
      (_) => _tickRelatedAutoScroll(),
    );
  }

  void _tickRelatedAutoScroll() {
    if (!mounted || _relatedAutoScrollPausedByUser) return;
    final controller = _relatedProductsScrollController;
    if (controller == null || !controller.hasClients) return;

    final segment = _relatedLoopSegmentWidth;
    if (segment <= 0) return;

    final next = controller.offset + _relatedScrollStep;
    try {
      if (next >= segment * 2) {
        controller.jumpTo(next - segment);
      } else {
        controller.animateTo(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    } catch (_) {
      _stopRelatedAutoScroll();
    }
  }

  void _pauseRelatedAutoScrollForUser() {
    _relatedAutoScrollPausedByUser = true;
    _relatedAutoScrollResumeTimer?.cancel();
    _relatedAutoScrollResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _relatedAutoScrollPausedByUser = false;
    });
  }

  bool _relatedListIsScrollable(int itemCount) => itemCount > 1;

  double _recentLoopSegmentWidthFor(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * _recentCardWidth +
        (itemCount - 1) * _relatedSeparatorWidth;
  }

  void _onRecentScrollChanged() => _normalizeRecentScrollOffset();

  void _normalizeRecentScrollOffset() {
    final controller = _recentlyViewedScrollController;
    if (controller == null || !controller.hasClients) return;
    final segment = _recentLoopSegmentWidth;
    if (segment <= 0) return;

    final offset = controller.offset;
    if (offset >= segment * 2 - 2) {
      controller.jumpTo(offset - segment);
    } else if (offset < segment * 0.5) {
      controller.jumpTo(offset + segment);
    }
  }

  void _initializeRecentLoopScroll() {
    final controller = _recentlyViewedScrollController;
    if (controller == null ||
        !controller.hasClients ||
        _recentLoopScrollInitialized) {
      return;
    }
    final segment = _recentLoopSegmentWidth;
    if (segment <= 0) return;
    controller.jumpTo(segment);
    _recentLoopScrollInitialized = true;
  }

  ScrollController _recentlyViewedScrollControllerFor(int itemCount) {
    if (_recentlyViewedScrollController != null) {
      return _recentlyViewedScrollController!;
    }
    final controller = ScrollController();
    controller.addListener(_onRecentScrollChanged);
    _recentlyViewedScrollController = controller;
    return controller;
  }

  void _stopRecentAutoScroll() {
    _recentAutoScrollTimer?.cancel();
    _recentAutoScrollTimer = null;
  }

  void _startRecentAutoScroll(int itemCount) {
    _stopRecentAutoScroll();
    if (!_relatedListIsScrollable(itemCount)) return;

    _recentAutoScrollTimer = Timer.periodic(
      _recentAutoScrollInterval,
      (_) => _tickRecentAutoScroll(),
    );
  }

  void _tickRecentAutoScroll() {
    if (!mounted || _recentAutoScrollPausedByUser) return;
    final controller = _recentlyViewedScrollController;
    if (controller == null || !controller.hasClients) return;

    final segment = _recentLoopSegmentWidth;
    if (segment <= 0) return;

    final next = controller.offset + _recentScrollStep;
    try {
      if (next >= segment * 2) {
        controller.jumpTo(next - segment);
      } else {
        controller.animateTo(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    } catch (_) {
      _stopRecentAutoScroll();
    }
  }

  void _pauseRecentAutoScrollForUser() {
    _recentAutoScrollPausedByUser = true;
    _recentAutoScrollResumeTimer?.cancel();
    _recentAutoScrollResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _recentAutoScrollPausedByUser = false;
    });
  }

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

  /// Detail body uses product-details API only (cached copies are prior API data).
  Future<Product> _fetchProductDetailsFromApi(
    String urlName, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final warm = ProductDetailService.takeWarmFuture(urlName);
      if (warm != null) {
        try {
          final product = await warm;
          _onProductLoaded();
          return product;
        } catch (_) {
          // Warm failed; fetch below.
        }
      }
    }

    final product = await _detailService.fetchProductDetails(
      urlName,
      catalogFallback: const [],
      allowCatalogFallback: false,
      timeout: const Duration(seconds: 15),
      forceRefresh: forceRefresh,
      onStaleRefresh: forceRefresh
          ? null
          : (fresh) {
              if (!mounted) return;
              setState(() => _productFuture = Future.value(fresh));
              _scheduleProductImagePrecache(fresh);
            },
    );
    _onProductLoaded();
    return product;
  }

  Future<List<Product>> _fetchRelatedProductsWithCache(String urlName) async {
    final result = await _optimizationService.fetchData(
      'related_products_$urlName',
      () => _detailService.fetchRelatedProducts(
        urlName,
        timeout: const Duration(seconds: 20),
      ),
      pageName: 'item_detail',
      persistToDisk: false,
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

      if (context.mounted) {
        unawaited(_flyToCartAnimation(context));
      }

      await cartProvider.addToCart(cartItem);

      if (context.mounted && mounted) {
        _scaleController.forward().then((_) {
          if (mounted) _scaleController.reverse();
        });
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

  Widget _buildSectionHeader(String title, {String? subtitle, IconData? icon}) {
    return ItemDetailDesign.sectionLabel(context, title, subtitle: subtitle, icon: icon);
  }

  Widget _itemDetailBackButton({Color? backgroundColor}) {
    return BackButtonUtils.withConfirmation(
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      title: _leaveProductTitle,
      message: _leaveProductMessage,
    );
  }

  void _leaveItemDetail(BuildContext context) {
    BackButtonUtils.popOrGoHome(
      context,
      showConfirmation: true,
      title: _leaveProductTitle,
      message: _leaveProductMessage,
    );
  }

  Widget _buildItemSliverHeader({Product? product}) {
    return ItemDetailSliverHeader(
      leading: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: _itemDetailBackButton(),
      ),
      scrollController: _pageScrollController,
      searchFocusNode: _headerSearchFocusNode,
      product: product,
      loading: product == null,
      displayNameBuilder: _productDisplayName,
    );
  }

  bool _isPrescriptionProduct(Product product) =>
      widget.isPrescribed || product.otcpom?.toLowerCase() == 'pom';

  Future<void> _refreshPrescriptionUploadStatus(Product product) async {
    if (!_isPrescriptionProduct(product)) {
      if (_prescriptionUploaded && mounted) {
        setState(() => _prescriptionUploaded = false);
      }
      return;
    }
    final uploaded = await PrescriptionUploadStatusService.isUploaded(
      productId: product.id,
      batchNo: product.batch_no,
    );
    if (mounted && uploaded != _prescriptionUploaded) {
      setState(() => _prescriptionUploaded = uploaded);
    }
  }

  Future<bool> _promptSignInForPrescriptionUpload(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final ink = ItemDetailDesign.ink(ctx);
        final muted = ItemDetailDesign.muted(ctx);
        final card = ItemDetailDesign.card(ctx);
        final border = ItemDetailDesign.cardBorder(ctx);
        final action = ItemDetailDesign.prescriptionAction(ctx);

        return Dialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ItemDetailDesign.radiusLg),
            side: BorderSide(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: action,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sign in required',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You need to sign in before you can upload a prescription for this medicine.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.45,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ItemDetailDesign.radiusMd),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: action,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ItemDetailDesign.radiusMd),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _openPrescriptionUpload(
    BuildContext context,
    Product product,
  ) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!context.mounted) return;

    if (!isLoggedIn) {
      final shouldSignIn = await _promptSignInForPrescriptionUpload(context);
      if (!context.mounted) return;
      if (!shouldSignIn) return;

      await Navigator.pushNamed(context, AppRoutes.signIn);
      if (!mounted) return;
      if (!await AuthService.isLoggedIn()) return;
    }

    final token = await AuthService.getToken();
    if (!context.mounted) return;
    if (token == null || token.isEmpty) return;

    final uploaded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionUploadPage(
          token: token,
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
    if (!mounted) return;
    if (uploaded == true) {
      setState(() => _prescriptionUploaded = true);
    } else {
      await _refreshPrescriptionUploadStatus(product);
    }
  }

  Widget _buildPrescriptionUploadedBanner() {
    return ItemDetailDesign.accentStripeCard(
      context: context,
      stripeColor: AppColors.primary,
      backgroundColor: ItemDetailDesign.accentTint(context),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescription uploaded',
                  style: GoogleFonts.poppins(
                    fontSize: _fsBodyMedium,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Our pharmacist will review it. You can replace the file if needed.',
                  style: GoogleFonts.poppins(
                    fontSize: _fsCaption,
                    color: context.appColors.muted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            backgroundColor: ItemDetailDesign.pageBg(context),
            appBar: AppBar(
              backgroundColor: ItemDetailDesign.card(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: ItemDetailDesign.ink(context),
              leading:
                  _itemDetailBackButton(backgroundColor: AppColors.primary),
              title: Text(
                'Product',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: _fsToolbarTitle,
                  color: ItemDetailDesign.ink(context),
                ),
              ),
            ),
            body: _buildErrorState(snapshot.error.toString()),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: ItemDetailDesign.pageBg(context),
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildItemSliverHeader(),
                SliverToBoxAdapter(child: _buildLoadingSkeleton()),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: ItemDetailDesign.pageBg(context),
            appBar: AppBar(
              backgroundColor: ItemDetailDesign.card(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: ItemDetailDesign.ink(context),
              leading:
                  _itemDetailBackButton(backgroundColor: AppColors.primary),
            ),
            body: _buildErrorState('Product not found'),
          );
        }

        return _buildProductScaffold(snapshot.data!);
      },
    );
  }

  void _scheduleRxHintIfNeeded(Product product) {
    if (_rxHintScheduled ||
        !_isPrescriptionProduct(product) ||
        _prescriptionUploaded) {
      return;
    }
    final inCart = CartProvider.selectIsProductInCart(
      context.read<CartProvider>(),
      productName: product.name,
      batchNo: product.batch_no,
      catalogProductId: product.id.toString(),
    );
    if (inCart) return;

    _rxHintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 450), () async {
        if (!mounted) return;
        if (_prescriptionUploaded) return;
        final stillInCart = CartProvider.selectIsProductInCart(
          context.read<CartProvider>(),
          productName: product.name,
          batchNo: product.batch_no,
          catalogProductId: product.id.toString(),
        );
        if (stillInCart) return;
        if (!context.mounted) return;
        await ItemDetailRxHint.maybeStart(
          context: context,
          uploadButtonKey: _rxUploadButtonKey,
        );
      });
    });
  }

  Widget _buildProductScaffold(Product product) {
    _schedulePageScrollbarUpdate();
    _ensureRecentlyViewedLoaded(product);
    _scheduleRxHintIfNeeded(product);

    return Scaffold(
      backgroundColor: ItemDetailDesign.pageBg(context),
      body: RefreshIndicator(
        onRefresh: () async {
          _precachedGallerySig = null;
          _stopRelatedAutoScroll();
          _relatedAutoScrollResumeTimer?.cancel();
          _relatedProductsScrollController
              ?.removeListener(_onRelatedScrollChanged);
          _relatedProductsScrollController?.dispose();
          _relatedProductsScrollController = null;
          _relatedLoopScrollInitialized = false;
          _relatedLoopSegmentWidth = 0;
          _relatedAutoScrollPausedByUser = false;
          setState(() {
            _productFuture = _fetchProductDetailsFromApi(
              widget.urlName,
              forceRefresh: true,
            );
            _relatedProductsFuture =
                _fetchRelatedProductsWithCache(widget.urlName);
            _recentlyViewedPreparedSlug = null;
            _resetRecentlyViewedScroll();
            _recentlyViewedItems = const [];
          });
          _productFuture.then((p) {
            if (mounted) {
              _scheduleProductImagePrecache(p);
              _schedulePageScrollbarUpdate();
              _recentlyViewedPreparedSlug = null;
              _ensureRecentlyViewedLoaded(p);
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
        backgroundColor: ItemDetailDesign.card(context),
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
                _buildItemSliverHeader(product: product),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: ItemDetailDesign.pageBg(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pageHPad,
                        12,
                        _pageHPad,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProductImageGallery(product),
                          _buildProductTitleUnderGallery(product),
                          const SizedBox(height: 10),
                          _buildProductHeroSection(product),
                          if (_isPrescriptionProduct(product) &&
                              _prescriptionUploaded) ...[
                            const SizedBox(height: 10),
                            _buildPrescriptionUploadedBanner(),
                          ],
                          if (!_isPrescriptionProduct(product))
                            _buildDescriptionSection(product),
                          _buildRecentlyViewedSection(),
                          _buildRelatedProductsSection(product),
                          const SizedBox(height: 84),
                        ],
                      ),
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
    final shimmer = ItemDetailDesign.shimmerColors(context);
    return Shimmer.fromColors(
      baseColor: shimmer.$1,
      highlightColor: shimmer.$2,
      child: ColoredBox(
        color: ItemDetailDesign.pageBg(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_pageHPad, 12, _pageHPad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: _galleryHeight,
                decoration: ItemDetailDesign.surfaceCard(context),
              ),
              const SizedBox(height: 10),
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: ItemDetailDesign.card(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 88,
                decoration: ItemDetailDesign.surfaceCard(context),
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: ItemDetailDesign.surfaceCard(context),
              ),
            ],
          ),
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
                fontSize: _fsToolbarTitle,
                fontWeight: FontWeight.bold,
                color: ItemDetailDesign.ink(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppErrorUtils.productDetailMessageFromError(error),
              style: TextStyle(
                fontSize: _fsBody,
                color: ItemDetailDesign.muted(context),
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
                      _productFuture = _fetchProductDetailsFromApi(
                        widget.urlName,
                        forceRefresh: true,
                      );
                      _relatedProductsFuture =
                          _fetchRelatedProductsWithCache(widget.urlName);
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _leaveItemDetail(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Go back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ItemDetailDesign.muted(context),
                    side: BorderSide(color: ItemDetailDesign.cardBorder(context)),
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
      child: Container(
        height: _galleryHeight,
        width: double.infinity,
        decoration: ItemDetailDesign.surfaceCard(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ItemDetailDesign.radiusLg - 1),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ColoredBox(
                color: ItemDetailDesign.imageWell(context),
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
                        horizontal: 24,
                        vertical: 14,
                      ),
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
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ItemDetailDesign.card(context).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ItemDetailDesign.cardBorder(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        imageUrls.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _currentImageIndex == index ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: _currentImageIndex == index
                                ? ItemDetailDesign.priceAccent(context)
                                : ItemDetailDesign.galleryDotInactive(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (imageUrls.isNotEmpty)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ItemDetailDesign.card(context).withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: ItemDetailDesign.cardBorder(context)),
                    ),
                    child: Icon(
                      Icons.zoom_in_rounded,
                      size: 18,
                      color: ItemDetailDesign.headingAccent(context)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryPlaceholder() {
    return Center(
      child: Icon(
        Icons.medical_services_outlined,
        size: 32,
        color: ItemDetailDesign.priceAccent(context).withValues(alpha: 0.35),
      ),
    );
  }

  /// Visible in the body when the sliver header title has collapsed on scroll.
  Widget _buildProductTitleUnderGallery(Product product) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        _productDisplayName(product),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.appColors.ink,
          height: 1.25,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildProductHeroSection(Product product) {
    final isPrescription = _isPrescriptionProduct(product);
    final inStock = StockUtilityService.isProductInStock(product.quantity);
    final price = double.tryParse(product.price) ?? 0.0;

    return ItemDetailDesign.accentStripeCard(
      context: context,
      stripeColor: ItemDetailDesign.priceAccent(context),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'GHS ',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ItemDetailDesign.priceAccent(context),
                  height: 1.1,
                ),
              ),
              Text(
                price.toStringAsFixed(2),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ItemDetailDesign.priceAccent(context),
                  letterSpacing: -0.3,
                  height: 1.05,
                ),
              ),
              if (product.uom != null && product.uom!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '/ ${product.uom}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    height: 1.1,
                    color: context.appColors.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _buildMetaChip(
                label: inStock ? 'In stock' : 'Out of stock',
                fg: inStock
                    ? ItemDetailDesign.headingAccent(context)
                    : ItemDetailDesign.warningAccent(context),
                green: inStock,
                compact: true,
              ),
              if (isPrescription)
                _buildMetaChip(
                  label: _prescriptionUploaded ? 'Rx uploaded' : 'Rx required',
                  fg: _prescriptionUploaded
                      ? ItemDetailDesign.headingAccent(context)
                      : ItemDetailDesign.rxInk(context),
                  green: _prescriptionUploaded,
                  tint: _prescriptionUploaded
                      ? ItemDetailDesign.accentTint(context)
                      : ItemDetailDesign.rxTint(context),
                  border: _prescriptionUploaded
                      ? ItemDetailDesign.accentBorder(context)
                      : ItemDetailDesign.rxBorder(context),
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required Color fg,
    bool green = false,
    bool compact = false,
    Color? tint,
    Color? border,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: tint ??
            (green
                ? ItemDetailDesign.accentTint(context)
                : ItemDetailDesign.mutedWell(context)),
        borderRadius: BorderRadius.circular(compact ? 5 : 6),
        border: Border.all(
          color: border ?? (green ? ItemDetailDesign.accentBorder(context) : ItemDetailDesign.cardBorder(context)),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: compact ? 10 : _fsChip,
          fontWeight: FontWeight.w500,
          height: 1.1,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(Product product) {
    final hasDescription = product.description.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ItemDetailDesign.accentStripeCard(
        context: context,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ItemDetailDesign.sectionLabel(
              context,
              'Product details',
              subtitle: 'Ingredients, usage & more',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 8),
            if (hasDescription)
              ProductDescription(
                description: product.description,
                fadeColor: ItemDetailDesign.card(context),
                chipBorderColor: ItemDetailDesign.cardBorder(context),
              )
            else
              Text(
                'Details coming soon',
                style: GoogleFonts.poppins(
                  fontSize: _fsBody,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.muted,
                  height: 1.4,
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
        catalogProductId: product.id.toString(),
      ),
      builder: (context, isInCart, _) {
        return Container(
          decoration: BoxDecoration(
            color: ItemDetailDesign.card(context),
            border: Border(
              top: BorderSide(color: ItemDetailDesign.cardBorder(context)),
            ),
            boxShadow: ItemDetailDesign.bottomBarShadow(context),
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
                  context,
                  product,
                  isPrescription,
                  price,
                  prescriptionUploaded: _prescriptionUploaded,
                ),
        );
      },
    );
  }

  Widget _buildAddToCartBottomBar(
    BuildContext context,
    Product product,
    bool isPrescription,
    double price, {
    bool prescriptionUploaded = false,
  }) {
    final accent = isPrescription
        ? (prescriptionUploaded
            ? AppColors.primary
            : ItemDetailDesign.prescriptionAction(context))
        : AppColors.primary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: _fsCaption,
                  color: context.appColors.muted,
                ),
              ),
              Text(
                'GHS ${price.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: _fsPriceLarge,
                  fontWeight: FontWeight.w600,
                  color: ItemDetailDesign.priceAccent(context),
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
              key: isPrescription ? _rxUploadButtonKey : null,
              onPressed: () async {
                HapticFeedback.mediumImpact();
                if (isPrescription) {
                  await _openPrescriptionUpload(context, product);
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
                    ? (prescriptionUploaded
                        ? Icons.check_circle_outline
                        : Icons.upload_file_outlined)
                    : Icons.add_shopping_cart_outlined,
                size: 18,
              ),
              label: Text(
                isPrescription
                    ? (prescriptionUploaded
                        ? 'Prescription uploaded'
                        : 'Upload prescription')
                    : 'Add to cart',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: _fsButton,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown only if cart qty > 0 but [CartProvider.findLineForSku] missed (transient).
  Widget _buildInCartFallbackBar(
    BuildContext context,
    int cartQuantity,
    double unitPrice,
  ) {
    return Row(
      children: [
        Text(
          'In cart ($cartQuantity)',
          style: GoogleFonts.poppins(
            fontSize: _fsBodyMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
            style: OutlinedButton.styleFrom(
              foregroundColor: ItemDetailDesign.headingAccent(context),
              side: BorderSide(color: ItemDetailDesign.accentBorder(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'View cart',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: _fsButton,
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
        catalogProductId: product.id.toString(),
      ),
      builder: (context, cartQuantity, _) {
        if (cartQuantity <= 0) return const SizedBox.shrink();

        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final line = CartProvider.findLineForSku(
          cartProvider,
          productName: product.name,
          batchNo: product.batch_no,
          catalogProductId: product.id.toString(),
        );
        if (line == null) {
          return _buildInCartFallbackBar(context, cartQuantity, price);
        }

        final itemIndex = cartProvider.cartItems.indexOf(line);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'In cart',
                  style: GoogleFonts.poppins(
                    fontSize: _fsSmall,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  'GHS ${(price * cartQuantity).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: _fsHeroPrice,
                    fontWeight: FontWeight.w600,
                    color: ItemDetailDesign.priceAccent(context),
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
                    border: Border.all(color: ItemDetailDesign.accentBorder(context)),
                    color: ItemDetailDesign.accentTint(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OptimizedRemoveButton(
                        onPressed: (cartQuantity > 1 &&
                                !cartProvider.isItemUpdating(
                                    line.id, itemIndex))
                            ? () {
                                final now = DateTime.now();
                                if (_lastQuantityUpdateTime != null &&
                                    now.difference(_lastQuantityUpdateTime!) <
                                        _quantityUpdateCooldown) {
                                  return;
                                }
                                _lastQuantityUpdateTime = now;
                                cartProvider.updateQuantityById(
                                  line.id,
                                  cartQuantity - 1,
                                  rowIndex: itemIndex,
                                );
                              }
                            : null,
                        isEnabled: cartQuantity > 1 &&
                            !cartProvider.isItemUpdating(line.id, itemIndex),
                        size: 32,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          cartQuantity.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: _fsBodyMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      OptimizedAddButton(
                        onPressed: (cartQuantity < maxQuantity &&
                                !cartProvider.isItemUpdating(
                                    line.id, itemIndex))
                            ? () async {
                                final now = DateTime.now();
                                if (_lastQuantityUpdateTime != null &&
                                    now.difference(_lastQuantityUpdateTime!) <
                                        _quantityUpdateCooldown) {
                                  return;
                                }
                                _lastQuantityUpdateTime = now;
                                HapticFeedback.mediumImpact();
                                if (context.mounted) {
                                  unawaited(_flyToCartAnimation(context));
                                }
                                await cartProvider.incrementCartLine(
                                  line.id,
                                  rowIndex: itemIndex,
                                );
                                if (context.mounted && mounted) {
                                  _scaleController.forward().then((_) {
                                    if (mounted) _scaleController.reverse();
                                  });
                                }
                              }
                            : null,
                        isEnabled: cartQuantity < maxQuantity &&
                            !cartProvider.isItemUpdating(line.id, itemIndex),
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
                        foregroundColor: ItemDetailDesign.headingAccent(context),
                        side: BorderSide(
                          color: ItemDetailDesign.accentBorder(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View cart',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: _fsButton,
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

  Widget _buildRecentlyViewedSection() {
    if (_recentlyViewedItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: ItemDetailDesign.surfaceCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Recently viewed',
              subtitle: 'Pick up where you left off',
              icon: Icons.restore_rounded,
            ),
            const SizedBox(height: 10),
            _buildRecentlyViewedList(_recentlyViewedItems),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedList(List<Product> items) {
    final sourceCount = items.length;
    final scrollable = _relatedListIsScrollable(sourceCount);
    if (scrollable) {
      _recentLoopSegmentWidth = _recentLoopSegmentWidthFor(sourceCount);
      _recentLoopScrollInitialized = false;
    }
    final controller =
        scrollable ? _recentlyViewedScrollControllerFor(sourceCount) : null;
    final listItemCount =
        scrollable ? sourceCount * _recentLoopRepeats : sourceCount;

    final list = ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      physics: scrollable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: listItemCount,
      separatorBuilder: (_, __) =>
          const SizedBox(width: _relatedSeparatorWidth),
      itemBuilder: (context, index) => _buildRecentlyViewedCard(
        items[index % sourceCount],
        context,
      ),
    );

    final scrollingList = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification ||
            notification is ScrollEndNotification) {
          ProductTapGuard.markScrolling();
        }
        if (notification is UserScrollNotification) {
          _pauseRecentAutoScrollForUser();
        }
        return false;
      },
      child: list,
    );

    if (scrollable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initializeRecentLoopScroll();
        _startRecentAutoScroll(sourceCount);
      });
    }

    return SizedBox(height: _relatedListHeight, child: scrollingList);
  }

  Widget _buildRecentlyViewedCard(Product product, BuildContext context) {
    final imageUrl = ApiConfig.getProductImageUrl(product.thumbnail);
    final name = _productDisplayName(product);
    final price = double.tryParse(product.price) ?? 0.0;
    final isRx = product.otcpom?.toLowerCase() == 'pom';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ProductDetailNavigation.pushNamed(
            context,
            urlName: product.urlName,
            product: product,
            fromProductCard: true,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: _recentCardWidth,
          decoration: BoxDecoration(
            color: ItemDetailDesign.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ItemDetailDesign.cardBorder(context),
              width: 0.8,
            ),
            boxShadow: ItemDetailDesign.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: ColoredBox(
                        color: ItemDetailDesign.imageWell(context),
                        child: product.thumbnail.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  errorWidget: (context, url, error) =>
                                      _galleryPlaceholder(),
                                ),
                              )
                            : _galleryPlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ItemDetailDesign.card(context)
                              .withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: ItemDetailDesign.cardBorder(context)),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 11,
                          color: context.appColors.muted.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (isRx)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ItemDetailDesign.rxTint(context),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: ItemDetailDesign.rxBorder(context)),
                          ),
                          child: Text(
                            'Rx',
                            style: GoogleFonts.poppins(
                              color: ItemDetailDesign.rxInk(context),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: ItemDetailDesign.cardBorder(context).withValues(alpha: 0.7),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: _fsCaption,
                        height: 1.15,
                        color: context.appColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'GHS ${price.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: ItemDetailDesign.priceAccent(context),
                        fontWeight: FontWeight.w700,
                        fontSize: _fsCaption,
                        height: 1.1,
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

  Widget _buildRelatedProductsList(List<Product> relatedProducts) {
    final sourceCount = relatedProducts.length;
    final scrollable = _relatedListIsScrollable(sourceCount);
    if (scrollable) {
      _relatedLoopSegmentWidth = _relatedLoopSegmentWidthFor(sourceCount);
      _relatedLoopScrollInitialized = false;
    }
    final controller =
        scrollable ? _relatedProductsScrollControllerFor(sourceCount) : null;
    final listItemCount =
        scrollable ? sourceCount * _relatedLoopRepeats : sourceCount;

    final list = ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      physics: scrollable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: listItemCount,
      separatorBuilder: (_, __) =>
          const SizedBox(width: _relatedSeparatorWidth),
      itemBuilder: (context, index) => _buildRelatedProductCard(
        relatedProducts[index % sourceCount],
        context,
      ),
    );

    final scrollingList = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification ||
            notification is ScrollEndNotification) {
          ProductTapGuard.markScrolling();
        }
        if (notification is UserScrollNotification) {
          _pauseRelatedAutoScrollForUser();
        }
        return false;
      },
      child: list,
    );

    if (scrollable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initializeRelatedLoopScroll();
        _startRelatedAutoScroll(sourceCount);
      });
    }

    return SizedBox(height: _relatedListHeight, child: scrollingList);
  }

  Widget _buildRelatedProductsSection(Product product) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: ItemDetailDesign.surfaceCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<List<Product>>(
              future: _relatedProductsFuture,
              builder: (context, relatedSnapshot) {
                final relatedProducts = relatedSnapshot.data ?? [];
                final showSubtitle =
                    relatedSnapshot.connectionState == ConnectionState.done &&
                        !relatedSnapshot.hasError &&
                        relatedProducts.isNotEmpty;

                return _buildSectionHeader(
                  'You may also like',
                  subtitle: showSubtitle ? 'Similar items' : null,
                  icon: Icons.grid_view_rounded,
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Product>>(
              future: _relatedProductsFuture,
              builder: (context, relatedSnapshot) {
                if (relatedSnapshot.connectionState ==
                    ConnectionState.waiting) {
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
      ),
    );
  }

  Widget _buildRelatedProductsSkeleton() {
    final shimmer = ItemDetailDesign.shimmerColors(context);
    return SizedBox(
      height: _relatedListHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: shimmer.$1,
          highlightColor: shimmer.$2,
          child: Container(
            width: _relatedCardWidth,
            decoration: BoxDecoration(
              color: ItemDetailDesign.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ItemDetailDesign.cardBorder(context)),
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ItemDetailDesign.mutedWell(context),
        borderRadius: BorderRadius.circular(ItemDetailDesign.radiusMd),
        border: Border.all(color: ItemDetailDesign.cardBorder(context)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: _fsBody,
              fontWeight: FontWeight.w600,
              color: ItemDetailDesign.ink(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1),
          Text(
            message,
            style: TextStyle(
              fontSize: _fsSmall,
              color: ItemDetailDesign.muted(context),
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
          ProductDetailNavigation.pushNamed(
            context,
            urlName: product.urlName,
            product: product,
            fromProductCard: true,
          );
        },
        borderRadius: BorderRadius.circular(ItemDetailDesign.radiusMd),
        child: Ink(
          width: _relatedCardWidth,
          decoration: BoxDecoration(
            color: ItemDetailDesign.card(context),
            borderRadius: BorderRadius.circular(ItemDetailDesign.radiusMd),
            border: Border.all(color: ItemDetailDesign.cardBorder(context)),
            boxShadow: ItemDetailDesign.cardShadow(context) ??
                (context.appColors.isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]),
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
                        color: ItemDetailDesign.imageWell(context),
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
                            color: ItemDetailDesign.rxTint(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: ItemDetailDesign.rxBorder(context)),
                          ),
                          child: Text(
                            'Rx',
                            style: GoogleFonts.poppins(
                              color: ItemDetailDesign.rxInk(context),
                              fontSize: 9,
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
                        fontSize: _fsCaption,
                        height: 1.15,
                        color: context.appColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'GHS ${product.price}',
                      style: GoogleFonts.poppins(
                        color: ItemDetailDesign.priceAccent(context),
                        fontWeight: FontWeight.w600,
                        fontSize: _fsCaption,
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
    final shimmer = ItemDetailDesign.shimmerColors(context);

    return Scaffold(
      backgroundColor: ItemDetailDesign.pageBg(context),
      body: Shimmer.fromColors(
        baseColor: shimmer.$1,
        highlightColor: shimmer.$2,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: kToolbarHeight + 36,
              backgroundColor: AppColors.accent,
              leading: BackButtonUtils.withConfirmation(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                title: _leaveProductTitle,
                message: _leaveProductMessage,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ItemDetailDesign.pagePadding,
                  12,
                  ItemDetailDesign.pagePadding,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 220,
                      decoration: ItemDetailDesign.surfaceCard(context),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: ItemDetailDesign.card(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 88,
                      decoration: ItemDetailDesign.surfaceCard(context),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 140,
                      decoration: ItemDetailDesign.surfaceCard(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final bodyColor = ItemDetailDesign.ink(context);
    final mutedColor = ItemDetailDesign.muted(context);
    final headingColor = ItemDetailDesign.headingAccent(context);
    final accentBorder =
        widget.chipBorderColor ?? ItemDetailDesign.cardBorder(context);

    return {
      'body': Style(
        fontSize: FontSize(15),
        color: bodyColor,
        lineHeight: LineHeight.number(1.28),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      'p': Style(
        fontSize: FontSize(15),
        color: bodyColor,
        lineHeight: LineHeight.number(1.28),
        margin: Margins.only(bottom: 5),
      ),
      'h1': Style(
        color: headingColor,
        fontWeight: FontWeight.w700,
        fontSize: FontSize(17),
        margin: Margins.only(top: 2, bottom: 4),
        lineHeight: LineHeight.number(1.12),
      ),
      'h2': Style(
        color: headingColor,
        fontWeight: FontWeight.w700,
        fontSize: FontSize(16),
        margin: Margins.only(top: 2, bottom: 4),
        lineHeight: LineHeight.number(1.12),
      ),
      'h3, h4': Style(
        color: headingColor,
        fontWeight: FontWeight.w600,
        fontSize: FontSize(14),
        letterSpacing: 0.2,
        margin: Margins.only(top: 6, bottom: 2),
        lineHeight: LineHeight.number(1.12),
      ),
      'ul, ol': Style(
        padding: HtmlPaddings.only(left: 18),
        margin: Margins.only(top: 2, bottom: 5),
      ),
      'li': Style(
        fontSize: FontSize(15),
        color: bodyColor,
        lineHeight: LineHeight.number(1.28),
        margin: Margins.only(bottom: 2),
        display: Display.listItem,
      ),
      'strong, b': Style(
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      'em, i': Style(
        fontStyle: FontStyle.italic,
        color: mutedColor,
      ),
      'a': Style(
        color: ItemDetailDesign.priceAccent(context),
        textDecoration: TextDecoration.underline,
        textDecorationColor: ItemDetailDesign.priceAccent(context),
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
          fontSize: 14,
          color: ItemDetailDesign.muted(context),
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
          fadeColor: widget.fadeColor ?? ItemDetailDesign.card(context),
          chipBorderColor:
              widget.chipBorderColor ?? ItemDetailDesign.cardBorder(context),
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
    final chipBg = ItemDetailDesign.card(context);
    final chipInk = ItemDetailDesign.headingAccent(context);

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
          const SizedBox(height: 6),
          Center(
            child: Material(
              color: chipBg,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: chipInk,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: chipInk,
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
              Text(
                'Category: ',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ItemDetailDesign.ink(context),
                ),
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: ItemDetailDesign.categoryChipDecoration(context),
                  child: Text(
                    category,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: ItemDetailDesign.headingAccent(context),
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
              Text(
                'Tags: ',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ItemDetailDesign.ink(context),
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
      decoration: ItemDetailDesign.tagChipDecoration(context),
      child: Text(
        tag,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: ItemDetailDesign.muted(context),
        ),
      ),
    );
  }
}
