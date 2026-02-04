// widgets/wishlist_button.dart
// button to add/remove items from wishlist
import 'package:flutter/material.dart';
import '../services/wishlist_service.dart';
import '../models/product.dart';
import '../pages/auth_service.dart';
import '../pages/signinpage.dart';

class WishlistButton extends StatefulWidget {
  final Product product;
  final double? size;
  final Color? color;
  final Color? activeColor;
  final bool showTooltip;

  const WishlistButton({
    super.key,
    required this.product,
    this.size,
    this.color,
    this.activeColor,
    this.showTooltip = true,
  });

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton> {
  final WishlistService _wishlistService = WishlistService.instance;
  bool _isInWishlist = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    final isInWishlist = await _wishlistService.isInWishlist(widget.product.id);
    if (mounted) {
      setState(() {
        _isInWishlist = isInWishlist;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (_isLoading) return;

    // Check if user is logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    
    if (!isLoggedIn) {
      // Show login prompt
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('Please sign in to add items to your wishlist.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        // Navigate to sign in page
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignInScreen(
              returnTo: ModalRoute.of(context)?.settings.name,
            ),
          ),
        );

        // Check if user logged in after returning
        final nowLoggedIn = await AuthService.isLoggedIn();
        if (!nowLoggedIn) {
          return; // User didn't log in
        }

        // Refresh wishlist status after login
        await _checkWishlistStatus();
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInWishlist) {
        debugPrint(
            '🗑️ WishlistButton: Removing product ID ${widget.product.id}');
        final success =
            await _wishlistService.removeFromWishlist(widget.product.id);
        debugPrint('🗑️ WishlistButton: Remove result: $success');

        if (success && mounted) {
          setState(() {
            _isInWishlist = false;
          });
          _showSnackBar('Removed from wishlist', Colors.green);
        } else if (mounted) {
          // Check if it's still in wishlist or if removal failed
          final isStillInWishlist =
              await _wishlistService.isInWishlist(widget.product.id);
          if (isStillInWishlist) {
            _showSnackBar('Failed to remove from wishlist. Please try again.',
                Colors.red);
          } else {
            // Item was removed, update UI
            setState(() {
              _isInWishlist = false;
            });
          }
        }
      } else {
        final success = await _wishlistService.addToWishlist(widget.product);
        if (success && mounted) {
          setState(() {
            _isInWishlist = true;
          });
          _showSnackBar('Added to wishlist', Colors.green);
        } else if (mounted) {
          // Check if it's already in wishlist or if it failed
          final isAlreadyInWishlist =
              await _wishlistService.isInWishlist(widget.product.id);
          if (isAlreadyInWishlist) {
            _showSnackBar('Already in wishlist', Colors.orange);
          } else {
            // Operation failed (likely connection error)
            _showSnackBar(
                'Failed to add to wishlist. Please check your connection.',
                Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('sign in')
            ? 'Please sign in to use wishlist'
            : e.toString().contains('Connection failed') ||
                    e.toString().contains('Unable to connect')
                ? 'No internet connection. Please check your connection and try again.'
                : 'Error updating wishlist. Please try again.';
        _showSnackBar(errorMessage, Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleWishlist,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: _isLoading
            ? SizedBox(
                width: widget.size ?? 18,
                height: widget.size ?? 18,
                child: const CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(
                _isInWishlist ? Icons.favorite : Icons.favorite_border,
                size: widget.size ?? 18,
                color: _isInWishlist
                    ? (widget.activeColor ?? Colors.green)
                    : Colors.green[600]!,
              ),
      ),
    );
  }
}
