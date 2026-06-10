import 'package:cached_network_image/cached_network_image.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows a compact remove-from-cart confirmation dialog.
Future<bool> showRemoveFromCartDialog(
  BuildContext context, {
  required String itemName,
  required String imageUrl,
  required double price,
  required int quantity,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Remove from cart',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: RemoveFromCartDialog(
          itemName: itemName,
          imageUrl: imageUrl,
          price: price,
          quantity: quantity,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class RemoveFromCartDialog extends StatelessWidget {
  const RemoveFromCartDialog({
    super.key,
    required this.itemName,
    required this.imageUrl,
    required this.price,
    required this.quantity,
  });

  final String itemName;
  final String imageUrl;
  final double price;
  final int quantity;

  static const Color _greenTint = Color(0xFFEEF9F3);
  static const Color _greenBorder = Color(0xFFBBEAD3);
  static const Color _removeRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final lineTotal = price * quantity;
    final displayName =
        itemName.length > 48 ? '${itemName.substring(0, 48)}…' : itemName;
    final headerGradient = theme.isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF3F1D24),
              theme.surface,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF1F2),
              Color(0xFFFFFBFB),
            ],
          );
    final headerBorder = theme.isDark
        ? theme.border
        : const Color(0xFFFECDD3);
    final itemPanelBg = theme.isDark ? theme.fieldBg : _greenTint;
    final itemPanelBorder = theme.isDark ? theme.accentBorder : _greenBorder;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.isDark ? 0.45 : 0.1,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 9),
              decoration: BoxDecoration(
                gradient: headerGradient,
                border: Border(bottom: BorderSide(color: headerBorder)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.isDark
                            ? _removeRed.withValues(alpha: 0.45)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 16,
                      color: _removeRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove from cart?',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Add it back anytime.',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: theme.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: theme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: itemPanelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: itemPanelBorder),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 36,
                        height: 36,
                        color: theme.fieldBg,
                        child: imageUrl.isEmpty
                            ? Icon(
                                Icons.medical_services_outlined,
                                size: 15,
                                color: AppColors.primary.withValues(alpha: 0.45),
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (compatible; Flutter)',
                                },
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.medical_services_outlined,
                                  size: 15,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.45),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'GHS ${price.toStringAsFixed(2)} × $quantity',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: theme.muted,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'GHS ${lineTotal.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: theme.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _removeRed,
                          side: BorderSide(
                            color: theme.isDark
                                ? _removeRed.withValues(alpha: 0.45)
                                : const Color(0xFFFECACA),
                          ),
                          backgroundColor: theme.isDark
                              ? _removeRed.withValues(alpha: 0.12)
                              : const Color(0xFFFFF6F5),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Remove',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 34,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Keep',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
}
