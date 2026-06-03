import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../providers/cart_provider.dart';

/// Cart icon + count badge that rebuilds only when [CartProvider.totalItems] changes.
class CartItemCountBadge extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;

  const CartItemCountBadge({
    super.key,
    this.icon = Icons.shopping_cart,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => CartProvider.selectTotalItems(cart),
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: iconSize,
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.cartBadge,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
