// pages/wishlist_page.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_error_utils.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../models/wishlist_item.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/homepage_optimization_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';

const Color _kWishlistAccent = Color(0xFF0D7A4C);
const Color _kPageBg = Color(0xFFF6F8FA);
const Color _kPageBgMint = Color(0xFFEFFCF4);

Widget _wishlistPageBackdrop({required Widget child}) {
  return DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kPageBgMint,
          _kPageBg,
          _kPageBg,
        ],
        stops: [0.0, 0.28, 1.0],
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

  Future<void> _moveToCart(int productId) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final success =
          await _wishlistService.moveToCart(productId, cartProvider);
      if (success) {
        await _removeFromWishlist(productId);
        if (mounted) {
          _showSnackBar('Added to your cart', _kWishlistAccent);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not add to cart.', const Color(0xFFB91C1C));
      }
    }
  }

  void _navigateToProductDetail(WishlistItem item) {
    Navigator.pushNamed(
      context,
      AppRoutes.itemDetail,
      arguments: {
        'urlName': item.product.urlName,
        'isPrescribed': item.product.otcpom?.toLowerCase() == 'pom',
      },
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
                  color: _kWishlistAccent.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
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
                  color: Colors.white,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.8)),
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
                          colors: [
                            const Color(0xFFFFF1F2),
                            const Color(0xFFFFE4E6),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFECDD3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 34,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sign in to save favourites',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
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
                        color: const Color(0xFF64748B),
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
                          backgroundColor: _kWishlistAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: _kWishlistAccent.withValues(alpha: 0.4),
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
                  color: _kWishlistAccent.withValues(alpha: 0.08),
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.green.shade600,
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
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBody() {
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
                  colors: [
                    const Color(0xFFECFDF5),
                    const Color(0xFFD1FAE5).withValues(alpha: 0.6),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kWishlistAccent.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No saved items yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on any product to keep it here. Come back anytime to add items to your cart.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
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
                backgroundColor: _kWishlistAccent,
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
    final n = _wishlistItems.length;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                                colors: [
                                  const Color(0xFFECFDF5),
                                  const Color(0xFFD1FAE5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.green.shade800,
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
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Prices confirmed at checkout',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
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
                              color: _kWishlistAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _kWishlistAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '$n',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _kWishlistAccent,
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

  Widget _buildWishlistItemCard(WishlistItem item) {
    final imageUrl = HomepageOptimizationService()
        .getProductImageUrl(item.product.thumbnail);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: () => _navigateToProductDetail(item),
          splashColor: _kWishlistAccent.withValues(alpha: 0.08),
          highlightColor: _kWishlistAccent.withValues(alpha: 0.04),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EEF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
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
                            color: const Color(0xFFF1F5F9),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 22,
                              color: Colors.grey.shade400,
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
                        Text(
                          item.product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
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
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              item.product.category,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
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
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              item.product.price,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kWishlistAccent,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _moveToCart(item.product.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFECFDF5),
                                foregroundColor: _kWishlistAccent,
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
                                  const Icon(Icons.add_shopping_cart_rounded,
                                      size: 16),
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
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _removeFromWishlist(item.product.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 2, top: 22),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: const Color(0xFFCBD5E1),
                      size: 24,
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
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
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
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'All saved items will be removed. You can add them again from product pages.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.35,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthentication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: _kPageBg,
            body: _wishlistPageBackdrop(
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
            backgroundColor: _kPageBg,
            body: _wishlistPageBackdrop(
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
          backgroundColor: _kPageBg,
          body: _wishlistPageBackdrop(
            child: RefreshIndicator(
              color: _kWishlistAccent,
              onRefresh: () => _loadWishlistItems(useCache: false),
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
        );
      },
    );
  }
}
