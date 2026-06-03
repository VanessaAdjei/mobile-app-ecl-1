import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layout density for [CartCheckoutSummaryRow].
enum CartCheckoutSummarySize {
  /// Cart checkout footer (44px actions).
  compact,
  /// Product detail dock (52px actions, roomier padding).
  comfortable,
}

/// Green gradient price row + right action — shared by cart checkout and product detail.
class CartCheckoutSummaryRow extends StatelessWidget {
  const CartCheckoutSummaryRow({
    super.key,
    required this.amount,
    required this.action,
    this.titleLabel = 'Order total',
    this.badgeLabel,
    this.footerHint = 'Excludes delivery fees',
    this.actionWidth = 148,
    this.sideSlot,
    this.size = CartCheckoutSummarySize.compact,
    this.actionExpanded = false,
    this.actionFlex = 2,
  });

  final double amount;
  final Widget action;
  final String titleLabel;
  final String? badgeLabel;
  final String? footerHint;
  final double actionWidth;
  /// Placed between the price block and [action] (e.g. qty stepper on product detail).
  final Widget? sideSlot;
  final CartCheckoutSummarySize size;
  /// When true, [action] fills remaining width (product detail primary CTA).
  final bool actionExpanded;
  final int actionFlex;

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _greenBorder = Color(0xFFBBEAD3);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _ink = Color(0xFF1F2937);

  bool get _comfortable => size == CartCheckoutSummarySize.comfortable;

  @override
  Widget build(BuildContext context) {
    final amountStr = amount.toStringAsFixed(2);
    final whole = amountStr.split('.').first;
    final cents = amountStr.split('.').last;
    final hasSide = sideSlot != null;
    final pad = _comfortable ? (hasSide ? 12.0 : 14.0) : 10.0;
    final gap = _comfortable ? (hasSide ? 8.0 : 12.0) : 10.0;
    final sideGap = _comfortable ? 8.0 : 8.0;
    final stripeH = _comfortable ? 46.0 : 36.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4FAF7),
            Color(0xFFEEF9F3),
          ],
        ),
        borderRadius: BorderRadius.circular(_comfortable ? 14 : 12),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: sideSlot != null ? 2 : (_comfortable ? 5 : 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: stripeH,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: _comfortable ? 10 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: _comfortable ? 11 : 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (badgeLabel != null) ...[
                            SizedBox(width: _comfortable ? 6 : 6),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _comfortable ? 6 : 6,
                                  vertical: _comfortable ? 2 : 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  badgeLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: _comfortable ? 9 : 8,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: _comfortable ? 4 : 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'GHS',
                            style: GoogleFonts.poppins(
                              fontSize: _comfortable ? 12 : 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    whole,
                                    style: GoogleFonts.poppins(
                                      fontSize: _comfortable ? 24 : 22,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                      height: 1,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  Text(
                                    '.$cents',
                                    style: GoogleFonts.poppins(
                                      fontSize: _comfortable ? 15 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: _muted,
                                      height: 1,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (footerHint != null && footerHint!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: _comfortable ? 3 : 0),
                          child: Text(
                            footerHint!,
                            style: GoogleFonts.poppins(
                              fontSize: _comfortable ? 9 : 8,
                              color: _muted,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (sideSlot != null) ...[
            SizedBox(width: sideGap),
            sideSlot!,
          ],
          SizedBox(width: gap),
          if (actionExpanded)
            Expanded(
              flex: actionFlex,
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: action,
              ),
            )
          else
            SizedBox(width: actionWidth, child: action),
        ],
      ),
    );
  }
}

/// White rounded top dock — same shell as [CartCheckoutBottomBar].
class CartCheckoutBottomShell extends StatelessWidget {
  const CartCheckoutBottomShell({
    super.key,
    required this.child,
    this.topSlot,
    this.comfortable = false,
  });

  final Widget child;
  final Widget? topSlot;
  final bool comfortable;

  @override
  Widget build(BuildContext context) {
    final outerPad = comfortable
        ? const EdgeInsets.fromLTRB(14, 12, 14, 10)
        : const EdgeInsets.fromLTRB(14, 10, 14, 8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: outerPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (topSlot != null) ...[
                topSlot!,
                const SizedBox(height: 8),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
