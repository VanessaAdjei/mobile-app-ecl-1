// pages/wishlist_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/wishlist_item.dart';
import '../services/wishlist_service.dart';
import '../services/homepage_optimization_service.dart';
import 'itemdetail.dart';
import 'homepage.dart';
import 'auth_service.dart';
import 'signinpage.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final WishlistService _wishlistService = WishlistService.instance;
  List<WishlistItem> _wishlistItems = [];
  bool _isLoading = false; // Start as false, will be set to true when loading
  bool _hasLoadedOnce = false; // Track if we've attempted to load

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset loaded flag when page becomes visible again to ensure fresh data
    if (_hasLoadedOnce && _wishlistItems.isEmpty) {
      _hasLoadedOnce = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Don't load wishlist here - wait for authentication check
  }

  Future<void> _loadWishlistItems({bool useCache = true}) async {
    debugPrint('📥 WishlistPage: Loading wishlist items (useCache: $useCache)');

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Add timeout to prevent infinite loading
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
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ WishlistPage: Error loading wishlist: $e');
      debugPrint('❌ WishlistPage: Error type: ${e.runtimeType}');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timed out. Please try again.'
            : 'Error loading wishlist: $e';
        _showSnackBar(errorMessage, Colors.red);
      }
    }
  }

  Future<void> _removeFromWishlist(int productId) async {
    try {
      debugPrint('🗑️ WishlistPage: Removing product ID $productId');
      debugPrint(
          '🗑️ WishlistPage: Current items before removal: ${_wishlistItems.map((item) => item.product.id).toList()}');

      // Optimistically remove item from UI immediately for instant feedback
      final itemExists =
          _wishlistItems.any((item) => item.product.id == productId);

      if (itemExists) {
        // Item exists, remove it optimistically from UI
        setState(() {
          _wishlistItems.removeWhere((item) => item.product.id == productId);
        });
        debugPrint('🗑️ WishlistPage: Optimistically removed item from UI');
      }

      // Call API to remove from server
      final success = await _wishlistService.removeFromWishlist(productId);
      debugPrint('🗑️ WishlistPage: Remove result: $success');

      if (mounted) {
        if (success) {
          _showSnackBar('Removed from wishlist', Colors.green);
          // Silently refresh in background to ensure sync (without showing loading)
          _silentRefreshWishlist();
        } else {
          // API removal failed, reload from server to restore correct state
          debugPrint(
              '⚠️ WishlistPage: API removal failed, reloading from server');
          await _loadWishlistItems(useCache: false);
          if (mounted) {
            _showSnackBar(
                'Failed to remove item. Please try again.', Colors.red);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ WishlistPage: Error removing item: $e');
      // On error, reload to sync UI with server state
      await _loadWishlistItems(useCache: false);
      if (mounted) {
        _showSnackBar('Error removing item: $e', Colors.red);
      }
    }
  }

  // Silently refresh wishlist without showing loading indicator
  Future<void> _silentRefreshWishlist() async {
    try {
      final items = await _wishlistService.getWishlistItems(useCache: false);
      if (mounted) {
        setState(() {
          _wishlistItems = items;
        });
        debugPrint('🔄 WishlistPage: Silently refreshed ${items.length} items');
      }
    } catch (e) {
      debugPrint('⚠️ WishlistPage: Silent refresh failed: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _moveToCart(int productId) async {
    try {
      final success = await _wishlistService.moveToCart(productId);
      if (success) {
        await _removeFromWishlist(productId);
        if (mounted) {
          _showSnackBar('Moved to cart', Colors.green);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error moving to cart: $e', Colors.red);
      }
    }
  }

  void _navigateToProductDetail(WishlistItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemPage(
          urlName: item.product.urlName,
          isPrescribed: item.product.otcpom?.toLowerCase() == 'pom',
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<bool> _checkAuthentication() async {
    try {
      return await AuthService.isLoggedIn();
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  Widget _buildLoginRequiredScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title: const Text('My Wishlist'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Please sign in to view and manage your wishlist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignInScreen(
                        returnTo: ModalRoute.of(context)?.settings.name,
                      ),
                    ),
                  );
                  if (result == true || await AuthService.isLoggedIn()) {
                    _loadWishlistItems();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication first
    return FutureBuilder<bool>(
      future: _checkAuthentication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              title: const Text('My Wishlist'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data != true) {
          // User not logged in, show login required screen
          return _buildLoginRequiredScreen(context);
        }

        // User is authenticated - load wishlist items if not already loaded
        // Use a flag to ensure we only load once
        if (!_hasLoadedOnce) {
          _hasLoadedOnce = true;
          debugPrint(
              '🔄 WishlistPage: Authentication confirmed, loading wishlist items...');
          // Load immediately after authentication is confirmed
          Future.microtask(() {
            if (mounted) {
              debugPrint(
                  '🔄 WishlistPage: Executing microtask to load wishlist');
              _loadWishlistItems(useCache: false); // Force fresh load from API
            } else {
              debugPrint('⚠️ WishlistPage: Widget not mounted, skipping load');
            }
          });
        } else {
          debugPrint('ℹ️ WishlistPage: Already loaded once, skipping reload');
        }

        // User is authenticated - show wishlist content
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Wishlist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              if (_wishlistItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _showClearWishlistDialog,
                  tooltip: 'Clear all',
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              debugPrint('🔄 WishlistPage: Pull to refresh triggered');
              await _loadWishlistItems(useCache: false);
            },
            color: Colors.green.shade600,
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.green.shade600,
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading your wishlist...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _wishlistItems.isEmpty
                          ? _buildEmptyState()
                          : _buildWishlistContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.shade200,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your wishlist is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start adding products you love\nand they\'ll appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shopping_bag_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Start Shopping',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade50,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_wishlistItems.length} item${_wishlistItems.length == 1 ? '' : 's'} saved',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Products you love',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_wishlistItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _wishlistItems.length,
            itemBuilder: (context, index) {
              final item = _wishlistItems[index];
              return _buildWishlistItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWishlistItem(WishlistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProductDetail(item),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image - smaller
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: HomepageOptimizationService()
                          .getProductImageUrl(item.product.thumbnail),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint(
                            '❌ WishlistPage: Image load error for ${item.product.thumbnail}: $error');
                        return Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.product.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'GHS ${item.product.price}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (item.product.quantity.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'In Stock',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons - smaller
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade600.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () => _moveToCart(item.product.id),
                          child: const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () => _removeFromWishlist(item.product.id),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearWishlistDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Clear Wishlist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to remove all items from your wishlist? This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _wishlistService.clearWishlist();
                          setState(() {
                            _wishlistItems.clear();
                          });
                          if (mounted) {
                            _showSnackBar('Wishlist cleared', Colors.green);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('Clear All'),
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
}
