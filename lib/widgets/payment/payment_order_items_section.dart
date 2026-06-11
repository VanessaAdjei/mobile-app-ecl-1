import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../models/cart_item.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_extension.dart';
import 'payment_section_style.dart';

/// Order line items on the payment screen.
class PaymentOrderItemsSection extends StatefulWidget {
  final List<CartItem> selectedItems;

  const PaymentOrderItemsSection({
    super.key,
    required this.selectedItems,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<PaymentOrderItemsSection> createState() =>
      _PaymentOrderItemsSectionState();
}

class _PaymentOrderItemsSectionState extends State<PaymentOrderItemsSection> {
  bool _showAllItems = false;

  String _imageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiConfig.getImageOrStorageUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final accent = PaymentSectionAccent.order(context);
    final selectedItems = widget.selectedItems;
    final thumbSize = context.rs(44);

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PaymentSectionHeader(
            eyebrow: 'Your order',
            title: 'Items',
            icon: Icons.shopping_bag_outlined,
            accent: accent,
            compact: widget.embedded,
            trailing: selectedItems.isEmpty
                ? null
                : '${selectedItems.length} item${selectedItems.length == 1 ? '' : 's'}',
          ),
          if (selectedItems.isEmpty) ...[
            SizedBox(height: widget.embedded ? 8 : 10),
            Text(
              'No items selected',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: t.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            SizedBox(height: widget.embedded ? 10 : 12),
            ...selectedItems
                .take(_showAllItems ? selectedItems.length : 3)
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index ==
                  (selectedItems.length > 3 && !_showAllItems
                      ? 2
                      : selectedItems.length - 1);

              final itemRow = Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.border?.withValues(alpha: 0.45) ??
                                t.border,
                          ),
                        ),
                        child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          color: accent.tint,
                          child: CachedNetworkImage(
                            imageUrl: _imageUrl(item.image),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.medical_services_outlined,
                              color: AppColors.primary.withValues(alpha: 0.35),
                              size: thumbSize * 0.42,
                            ),
                          ),
                        ),
                      ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.25,
                                color: t.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.tint,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: accent.border
                                              ?.withValues(alpha: 0.4) ??
                                          t.border,
                                    ),
                                  ),
                                  child: Text(
                                    '×${item.quantity}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent.gradient.last,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'GHS ${item.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  );

              if (widget.embedded) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: itemRow,
                    ),
                    if (!isLast) PaymentSectionStyle.sectionDivider(context),
                  ],
                );
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: PaymentSectionStyle.innerPanelDecoration(
                      context,
                      accent: accent,
                    ),
                    child: itemRow,
                  ),
                  if (!isLast) const SizedBox(height: 8),
                ],
              );
            }),
            if (selectedItems.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ExpandToggle(
                  label: _showAllItems
                      ? 'Show less'
                      : 'View ${selectedItems.length - 3} more',
                  icon: _showAllItems ? Icons.expand_less : Icons.expand_more,
                  onTap: () => setState(() => _showAllItems = !_showAllItems),
                ),
              ),
          ],
        ],
      );

    if (widget.embedded) return content;

    return PaymentSectionCard(
      accent: accent,
      child: content,
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
