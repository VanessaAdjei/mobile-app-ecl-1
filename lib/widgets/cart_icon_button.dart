// widgets/cart_icon_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart.dart';
import '../pages/cartprovider.dart';
import '../pages/auth_service.dart';

class CartIconButton extends StatefulWidget {
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
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  bool _userLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() {
        _userLoggedIn = loggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor,
      ),
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            // Always show the shopping cart icon
            Icon(
              Icons.shopping_cart,
              color: widget.iconColor ?? Colors.white,
              size: widget.iconSize,
            ),
            // Only show the counter if user is logged in and has items
            if (_userLoggedIn && cart.totalItems > 0)
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
        padding: widget.padding,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Cart()),
        ),
      ),
    );
  }
}
