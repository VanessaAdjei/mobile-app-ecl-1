// widgets/cart_icon_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart.dart';
import '../pages/cartprovider.dart';

class CartIconButton extends StatelessWidget {
  final Color? iconColor;
  final double? iconSize;
  final Color? backgroundColor;

  const CartIconButton({
    super.key,
    this.iconColor,
    this.iconSize,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: backgroundColor != null
                  ? BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: IconButton(
                icon: Icon(
                  Icons.shopping_cart,
                  color: iconColor ?? Colors.white,
                  size: iconSize ?? 24,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Cart(),
                    ),
                  );
                },
              ),
            ),
            if (cart.totalItems > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${cart.totalItems}',
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

