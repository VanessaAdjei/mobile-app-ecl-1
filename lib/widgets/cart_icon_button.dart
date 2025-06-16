// widgets/cart_icon_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart.dart';
import '../pages/cartprovider.dart';
import '../pages/auth_service.dart';

class CartIconButton extends StatelessWidget {
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const CartIconButton({
    Key? key,
    this.iconColor = Colors.white,
    this.iconSize,
    this.padding,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.shopping_cart,
              color: iconColor,
              size: iconSize,
            ),
            if (cart.totalItems > 0)
              Positioned(
                right: -6,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.all(2),
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
        ),
        padding: padding,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Cart()),
        ),
      ),
    );
  }
}
