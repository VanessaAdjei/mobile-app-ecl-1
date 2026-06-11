import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../models/cart_item.dart';
import '../../utils/app_theme_colors.dart';
import '../../utils/responsive_extension.dart';
import 'payment_section_style.dart';

/// Order line items on the payment information screen.
class PaymentOrderItemsSection extends StatefulWidget {
  final List<CartItem> selectedItems;
  final bool compact;

  const PaymentOrderItemsSection({
    super.key,
    required this.selectedItems,
    this.compact = false,
  });

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
    final selectedItems = widget.selectedItems;

    final itemPadding = EdgeInsets.symmetric(
      horizontal: context.rs(8),
      vertical: context.rs(6),
    );
    final itemGap = context.rs(5);
    final thumbSize = context.rs(36);
    final nameFontSize = context.sp(12);
    final metaFontSize = context.sp(10);
    final lineTotalFontSize = context.sp(12);

    return PaymentSectionCard(
      accentStripe: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PaymentSectionHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Order summary',
            subtitle: selectedItems.isEmpty
                ? 'No items selected'
                : '${selectedItems.length} item${selectedItems.length == 1 ? '' : 's'}',
            accentColors: const [Color(0xFF43A047), AppColors.primary],
          ),
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: 9),
            ...selectedItems.take(_showAllItems ? selectedItems.length : 3).map(
                  (item) => Container(
                    margin: EdgeInsets.only(bottom: itemGap),
                    padding: itemPadding,
                    decoration: PaymentSectionStyle.innerPanelDecoration(context),
                    child: Row(
                      children: [
                        Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: t.accentTint,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrl(item.image),
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                color: t.accentTint,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.medical_services_outlined,
                                color: AppColors.primary.withValues(alpha: 0.4),
                                size: thumbSize * 0.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: nameFontSize,
                                  height: 1.25,
                                  color: t.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '×${item.quantity}',
                                      style: TextStyle(
                                        fontSize: metaFontSize,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'GHS ${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: t.muted,
                                      fontSize: metaFontSize,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'GHS ${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: lineTotalFontSize,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (selectedItems.length > 3 && !_showAllItems)
              _ExpandToggle(
                label: 'Show ${selectedItems.length - 3} more item(s)',
                icon: Icons.expand_more,
                accent: true,
                onTap: () => setState(() => _showAllItems = true),
              ),
            if (selectedItems.length > 3 && _showAllItems)
              _ExpandToggle(
                label: 'Show less',
                icon: Icons.expand_less,
                accent: false,
                onTap: () => setState(() => _showAllItems = false),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;

    final bg = accent
        ? (t.isDark
            ? AppColors.primary.withValues(alpha: 0.14)
            : Colors.blue.shade50)
        : t.fieldBg;
    final border = accent
        ? (t.isDark
            ? AppColors.primary.withValues(alpha: 0.35)
            : Colors.blue.shade200)
        : t.border;
    final ink = accent
        ? (t.isDark ? AppColors.primaryLight : Colors.blue.shade700)
        : t.muted;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
