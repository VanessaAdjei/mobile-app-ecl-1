// widgets/wishlist_button.dart
// widgets/wishlist_button.dart
import 'package:flutter/material.dart';
import '../services/wishlist_service.dart';
import '../models/product.dart';

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

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInWishlist) {
        final success =
            await _wishlistService.removeFromWishlist(widget.product.id);
        if (success && mounted) {
          setState(() {
            _isInWishlist = false;
          });
          _showSnackBar('Removed from wishlist', Colors.green);
        }
      } else {
        final success = await _wishlistService.addToWishlist(widget.product);
        if (success && mounted) {
          setState(() {
            _isInWishlist = true;
          });
          _showSnackBar('Added to wishlist', Colors.green);
        } else if (mounted) {
          _showSnackBar('Already in wishlist', Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating wishlist', Colors.red);
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
            color: Colors.grey.withOpacity(0.3),
            width: 1,
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
                width: widget.size ?? 16,
                height: widget.size ?? 16,
                child: const CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(
                _isInWishlist ? Icons.favorite : Icons.favorite_border,
                size: widget.size ?? 16,
                color: _isInWishlist
                    ? (widget.activeColor ?? Colors.red)
                    : Colors.grey[600],
              ),
      ),
    );
  }
}
