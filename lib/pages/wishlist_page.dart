// pages/wishlist_page.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_error_utils.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../pages/main_tab_shell.dart';
import '../utils/app_theme_colors.dart';
import '../utils/product_detail_navigation.dart';
import '../utils/product_tap_guard.dart';
import '../models/cart_item.dart';
import '../models/wishlist_item.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/homepage_optimization_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

const Color _kWishlistAccent = Color(0xFF0D7A4C);
const Color _kPageBg = Color(0xFFF6F8FA);
const Color _kPageBgMint = Color(0xFFEFFCF4);

Color _wishlistAccent(BuildContext context) =>
    context.appColors.isDark ? AppColors.primaryLight : _kWishlistAccent;

Widget _wishlistPageBackdrop({
  required BuildContext context,
  required Widget child,
}) {
  final theme = context.appColors;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: theme.isDark
            ? [
                const Color(0xFF14231C),
                theme.pageBg,
                theme.pageBg,
              ]
            : [
                _kPageBgMint,
                _kPageBg,
                _kPageBg,
              ],
        stops: const [0.0, 0.28, 1.0],
      ),
    ),
    child: child,
  );
}

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final WishlistService _wishlistService = WishlistService.instance;
  List<WishlistItem> _wishlistItems = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedOnce && _wishlistItems.isEmpty) {
      _hasLoadedOnce = false;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadWishlistItems({bool useCache = true}) async {
    debugPrint('📥 WishlistPage: Loading wishlist items (useCache: $useCache)');

    if (!mounted) return;

    final blockUi = _wishlistItems.isEmpty;
    if (blockUi) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final items =
          await _wishlistService.getWishlistItems(useCache: useCache).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ WishlistPage: Load timeout after 30 seconds');
          throw TimeoutException('Wishlist load timed out');
        },
      );

      debugPrint('📥 WishlistPage: Loaded ${items.length} wishlist items');

      if (!mounted) return;

      setState(() {
        _wishlistItems = items;
        if (blockUi) _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ WishlistPage: Error loading wishlist: $e');

      if (!mounted) return;

      if (blockUi) {
        setState(() {
          _isLoading = false;
        });
      }

      if (mounted) {
        final errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timed out. Please try again.'
            : 'Could not load your wishlist. Pull to refresh.';
        _showSnackBar(errorMessage, const Color(0xFFB91C1C));
      }
    }
  }

  Future<void> _removeFromWishlist(int productId) async {
    try {
      final itemExists =
          _wishlistItems.any((item) => item.product.id == productId);

      if (itemExists) {
        setState(() {
          _wishlistItems.removeWhere((item) => item.product.id == productId);
        });
      }

      final success = await _wishlistService.removeFromWishlist(productId);

      if (mounted) {
        if (success) {
          _showSnackBar('Removed from wishlist', _kWishlistAccent);
          _silentRefreshWishlist();
        } else {
          await _loadWishlistItems(useCache: false);
          if (mounted) {
            _showSnackBar('Could not remove that item. Please try again.',
                const Color(0xFFB91C1C));
          }
        }
      }
    } catch (e) {
      await _loadWishlistItems(useCache: false);
      if (mounted) {
        _showSnackBar(
            'Something went wrong. Try again.', const Color(0xFFB91C1C));
      }
    }
  }

  Future<void> _silentRefreshWishlist() async {
    try {
      final items = await _wishlistService.getWishlistItems(useCache: false);
      if (mounted) {
        setState(() {
          _wishlistItems = items;
        });
      }
    } catch (e) {
      debugPrint('⚠️ WishlistPage: Silent refresh failed: $e');
    }
  }

  Future<void> _incrementWishlistCartLine(
    WishlistItem item,
    CartItem line,
  ) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final incrementItem = CartItem(
      id: line.id,
      productId: item.product.id.toString(),
      originalProductId: item.product.id.toString(),
      serverProductId: line.serverProductId,
      name: line.name,
      price: line.price,
      quantity: 1,
      image: line.image,
      batchNo: line.batchNo.isNotEmpty ? line.batchNo : item.product.batchNo,
      urlName: item.product.urlName,
      totalPrice: line.price,
    );
    await cartProvider.addToCart(incrementItem);
    if (mounted) {
      _showSnackBar('Quantity updated', _kWishlistAccent);
    }
  }

  Future<void> _decrementWishlistCartLine(CartItem line, int quantity) async {
    if (quantity <= 1) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (line.id.isNotEmpty) {
      await cartProvider.updateQuantityById(line.id, quantity - 1);
    }
  }

  Future<void> _moveToCart(WishlistItem item) async {
    if (item.product.otcpom?.toLowerCase() == 'pom') {
      _navigateToProductDetail(item);
      _showSnackBar(
        'Upload a prescription on the product page to add this medicine.',
        _kWishlistAccent,
      );
      return;
    }

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final existingLine = CartProvider.findLineForSku(
        cartProvider,
        productName: item.product.name,
        batchNo: item.product.batchNo,
        catalogProductId: item.product.id.toString(),
      );
      if (existingLine != null) {
        await _incrementWishlistCartLine(item, existingLine);
        return;
      }

      final success =
          await _wishlistService.moveToCart(item.product.id, cartProvider);
      if (!mounted) return;

      if (success) {
        setState(() {
          _wishlistItems.removeWhere((w) => w.product.id == item.product.id);
        });
        _showSnackBar('Added to your cart', _kWishlistAccent);
        unawaited(_silentRefreshWishlist());
      } else {
        _showSnackBar(
          'Could not add to cart. The product may be unavailable.',
          const Color(0xFFB91C1C),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not add to cart.', const Color(0xFFB91C1C));
      }
    }
  }

  void _navigateToProductDetail(WishlistItem item) {
    final urlName = item.product.urlName.trim();
    if (urlName.isEmpty) {
      _showSnackBar(
        'This product cannot be opened right now.',
        const Color(0xFFB91C1C),
      );
      return;
    }
    ProductDetailNavigation.pushNamed(
      context,
      urlName: urlName,
      product: item.product,
      isPrescribed: item.product.otcpom?.toLowerCase() == 'pom',
      fromProductCard: true,
    );
  }

  void _showSnackBar(String message, Color accent) {
    AppErrorUtils.showSnack(
      context,
      message,
      isError: accent != _kWishlistAccent,
    );
  }

  Future<bool> _checkAuthentication() async {
    try {
      return await AuthService.isLoggedIn();
    } catch (e) {
      return false;
    }
  }

  Widget _wishlistHeaderSliver({required bool showClearAction}) {
    return EclExpandableSliverAppBar(
      toolbarTitle: 'Wishlist',
      heroTitle: 'Wishlist',
      heroSubtitle: 'Saved for later',
      actions: [
        if (showClearAction)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete_sweep_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            tooltip: 'Clear wishlist',
            onPressed: _showClearWishlistDialog,
          ),
      ],
    );
  }

  Widget _buildLoginRequiredBody() {
    final theme = context.appColors;
    final accent = _wishlistAccent(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: theme.isDark ? 0.12 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isDark ? 0.32 : 0.06,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                  color: theme.sheetBg,
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: theme.isDark
                              ? [
                                  Colors.red.withValues(alpha: 0.22),
                                  Colors.red.withValues(alpha: 0.12),
                                ]
                              : [
                                  const Color(0xFFFFF1F2),
                                  const Color(0xFFFFE4E6),
                                ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.isDark
                              ? Colors.red.withValues(alpha: 0.28)
                              : const Color(0xFFFECDD3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(
                              alpha: theme.isDark ? 0.16 : 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 34,
                        color: theme.isDark
                            ? Colors.red.shade300
                            : Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sign in to save favourites',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save products you love and move them to your cart whenever you are ready.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.45,
                        color: theme.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            AppRoutes.signIn,
                            arguments: {
                              'returnTo': ModalRoute.of(context)?.settings.name,
                            },
                          );
                          if (result == true ||
                              await AuthService.isLoggedIn()) {
                            _loadWishlistItems();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.isDark
                              ? AppColors.primary
                              : _kWishlistAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: accent.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBody() {
    final theme = context.appColors;
    final accent = _wishlistAccent(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: theme.isDark ? 0.14 : 0.08),
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Loading your wishlist…',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBody() {
    final theme = context.appColors;
    final accent = _wishlistAccent(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.1),
                        ]
                      : [
                          const Color(0xFFECFDF5),
                          const Color(0xFFD1FAE5).withValues(alpha: 0.6),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: theme.isDark ? 0.16 : 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No saved items yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on any product to keep it here. Come back anytime to add items to your cart.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: theme.muted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (MainTabShell.switchToTab(context, 0)) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  return;
                }
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(
                'Browse products',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.isDark ? AppColors.primary : _kWishlistAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySliver() {
    final theme = context.appColors;
    final accent = _wishlistAccent(context);
    final n = _wishlistItems.length;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.sheetBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.28 : 0.05,
                ),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.green.shade400,
                          _kWishlistAccent,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: theme.isDark
                                    ? [
                                        AppColors.primary
                                            .withValues(alpha: 0.2),
                                        AppColors.primary
                                            .withValues(alpha: 0.1),
                                      ]
                                    : [
                                        const Color(0xFFECFDF5),
                                        const Color(0xFFD1FAE5),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.isDark
                                    ? AppColors.primary.withValues(alpha: 0.28)
                                    : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$n saved ${n == 1 ? 'item' : 'items'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: theme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Prices confirmed at checkout',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: theme.muted,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(
                                alpha: theme.isDark ? 0.16 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(
                                  alpha: theme.isDark ? 0.28 : 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              '$n',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistCartAction(
    WishlistItem item,
    Color accent,
    AppThemeColors theme,
  ) {
    final productId = item.product.id.toString();

    return Selector<CartProvider, int>(
      selector: (_, cart) => CartProvider.selectQuantityForProduct(
        cart,
        productName: item.product.name,
        batchNo: item.product.batchNo,
        catalogProductId: productId,
      ),
      builder: (context, cartQuantity, _) {
        if (cartQuantity > 0) {
          final cartProvider =
              Provider.of<CartProvider>(context, listen: false);
          final line = CartProvider.findLineForSku(
            cartProvider,
            productName: item.product.name,
            batchNo: item.product.batchNo,
            catalogProductId: productId,
          );

          return Container(
            decoration: BoxDecoration(
              color: theme.isDark
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: theme.isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: line == null || cartQuantity <= 1
                      ? null
                      : () => _decrementWishlistCartLine(line, cartQuantity),
                  icon: Icon(
                    Icons.remove_rounded,
                    size: 16,
                    color: cartQuantity > 1 ? accent : theme.muted,
                  ),
                ),
                Text(
                  '$cartQuantity',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: accent,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: line == null
                      ? null
                      : () => _incrementWishlistCartLine(item, line),
                  icon: Icon(Icons.add_rounded, size: 16, color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'In cart',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return FilledButton.tonal(
          onPressed: () => _moveToCart(item),
          style: FilledButton.styleFrom(
            backgroundColor: theme.isDark
                ? AppColors.primary.withValues(alpha: 0.16)
                : const Color(0xFFECFDF5),
            foregroundColor: accent,
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_shopping_cart_rounded, size: 16),
              const SizedBox(width: 4),
              Text(
                'Add to cart',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWishlistItemCard(WishlistItem item) {
    final theme = context.appColors;
    final accent = _wishlistAccent(context);
    final imageUrl = HomepageOptimizationService()
        .getProductImageUrl(item.product.thumbnail);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.sheetBg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.black.withValues(
          alpha: theme.isDark ? 0.24 : 0.06,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.22 : 0.04,
                ),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToProductDetail(item),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: accent.withValues(alpha: 0.08),
                    highlightColor: accent.withValues(alpha: 0.04),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 68,
                          height: 68,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: theme.fieldBg,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: theme.fieldBg,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 22,
                                color: theme.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _navigateToProductDetail(item),
                          borderRadius: BorderRadius.circular(8),
                          splashColor: accent.withValues(alpha: 0.06),
                          highlightColor: accent.withValues(alpha: 0.03),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.ink,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.product.category.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.fieldBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.border),
                                  ),
                                  child: Text(
                                    item.product.category,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: theme.muted,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'GHS ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.muted,
                                    ),
                                  ),
                                  Text(
                                    item.product.price,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildWishlistCartAction(item, accent, theme),
                          OutlinedButton(
                            onPressed: () =>
                                _removeFromWishlist(item.product.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.muted,
                              side: BorderSide(color: theme.border),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.heart_broken_outlined,
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Remove',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToProductDetail(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, top: 22),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: theme.muted.withValues(alpha: 0.65),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _wishlistContentSlivers() {
    if (_wishlistItems.isEmpty) {
      return [
        SliverFillRemaining(child: _buildEmptyBody()),
      ];
    }
    return [
      _buildSummarySliver(),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildWishlistItemCard(_wishlistItems[index]);
            },
            childCount: _wishlistItems.length,
          ),
        ),
      ),
    ];
  }

  void _showClearWishlistDialog() {
    final theme = context.appColors;

    showDialog<void>(
      context: context,
      barrierColor: theme.isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.sheetBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? Colors.red.withValues(alpha: 0.16)
                            : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: theme.isDark
                            ? Colors.red.shade300
                            : Colors.red.shade600,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear wishlist?',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'All saved items will be removed. You can add them again from product pages.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.35,
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.muted,
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _wishlistService.clearWishlist();
                        if (mounted) {
                          setState(() => _wishlistItems.clear());
                          _showSnackBar('Wishlist cleared', _kWishlistAccent);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final pageBg = theme.pageBg;
    final refreshColor = _wishlistAccent(context);

    return FutureBuilder<bool>(
      future: _checkAuthentication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: pageBg,
            body: _wishlistPageBackdrop(
              context: context,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _wishlistHeaderSliver(showClearAction: false),
                  SliverFillRemaining(child: _buildLoadingBody()),
                ],
              ),
            ),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            backgroundColor: pageBg,
            body: _wishlistPageBackdrop(
              context: context,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _wishlistHeaderSliver(showClearAction: false),
                  SliverFillRemaining(child: _buildLoginRequiredBody()),
                ],
              ),
            ),
          );
        }

        if (!_hasLoadedOnce) {
          _hasLoadedOnce = true;
          Future.microtask(() {
            if (mounted) {
              _loadWishlistItems(useCache: false);
            }
          });
        }

        return Scaffold(
          backgroundColor: pageBg,
          body: _wishlistPageBackdrop(
            context: context,
            child: RefreshIndicator(
              color: refreshColor,
              onRefresh: () => _loadWishlistItems(useCache: false),
              child: ProductTapScrollScope(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    _wishlistHeaderSliver(
                      showClearAction: _wishlistItems.isNotEmpty && !_isLoading,
                    ),
                    if (_isLoading)
                      SliverFillRemaining(child: _buildLoadingBody())
                    else
                      ..._wishlistContentSlivers(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
