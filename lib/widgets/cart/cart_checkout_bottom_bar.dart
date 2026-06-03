import 'package:eclapp/widgets/cart/cart_checkout_summary_row.dart';
import 'package:eclapp/widgets/order_threshold_promo_banner.dart';
import 'package:flutter/material.dart';

/// Compact checkout footer: promo progress, order total, and checkout action.
class CartCheckoutBottomBar extends StatelessWidget {
  const CartCheckoutBottomBar({
    super.key,
    required this.subtotal,
    required this.selectedQuantity,
    required this.selectedLineCount,
    required this.totalLineCount,
    required this.checkoutButton,
  });

  final double subtotal;
  final int selectedQuantity;
  final int selectedLineCount;
  final int totalLineCount;
  final Widget checkoutButton;

  String get _itemsLabel {
    if (totalLineCount != selectedLineCount) {
      return '$selectedLineCount of $totalLineCount selected';
    }
    if (selectedQuantity == 1) return '1 item';
    return '$selectedQuantity items';
  }

  @override
  Widget build(BuildContext context) {
    return CartCheckoutBottomShell(
      topSlot: OrderThresholdPromoCartInfo(subtotal: subtotal),
      child: CartCheckoutSummaryRow(
        amount: subtotal,
        badgeLabel: _itemsLabel,
        action: SizedBox(width: 148, child: checkoutButton),
      ),
    );
  }
}
