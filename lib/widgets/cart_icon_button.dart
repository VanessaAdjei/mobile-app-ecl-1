// widgets/cart_icon_button.dart
import 'package:flutter/material.dart';
import '../config/app_routes.dart';
import 'cart_item_count_badge.dart';

class CartIconButton extends StatefulWidget {
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;
  final double? splashRadius;

  const CartIconButton({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize,
    this.padding,
    this.backgroundColor,
    this.margin,
    this.constraints,
    this.visualDensity,
    this.splashRadius,
  });

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (mounted) {
      setState(() {
        // user login status updated
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor,
      ),
      child: IconButton(
        icon: CartItemCountBadge(
          icon: Icons.shopping_cart,
          iconColor: widget.iconColor ?? Colors.white,
          iconSize: widget.iconSize,
        ),
        padding: widget.padding,
        constraints: widget.constraints,
        visualDensity: widget.visualDensity,
        splashRadius: widget.splashRadius,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
      ),
    );
  }
}
