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

    final sectionPadding = widget.compact
        ? EdgeInsets.symmetric(
            horizontal: context.rs(12),
            vertical: context.rs(12),
          )
        : PaymentSectionStyle.paddingOf(context);
    final itemPadding = widget.compact
        ? EdgeInsets.symmetric(
            horizontal: context.rs(10),
            vertical: context.rs(8),
          )
        : EdgeInsets.all(context.rs(10));
    final itemGap = widget.compact ? context.rs(6) : context.rs(7);
    final thumbSize = widget.compact ? context.rs(40) : context.rs(46);
    final titleFontSize = widget.compact ? context.sp(13) : context.sp(14);
    final nameFontSize = widget.compact ? context.sp(12) : context.sp(13);
    final metaFontSize = widget.compact ? context.sp(10) : context.sp(11);
    final lineTotalFontSize = widget.compact ? context.sp(12) : context.sp(13);
    final accentBarHeight = widget.compact ? context.rs(15) : context.rs(16);

    return Container(
      margin: PaymentSectionStyle.marginOf(context),
      padding: sectionPadding,
      decoration: PaymentSectionStyle.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: accentBarHeight,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                selectedItems.length == 1
                    ? 'Order summary (1 item)'
                    : 'Order summary (${selectedItems.length} items)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: titleFontSize,
                  color: t.isDark ? AppColors.primaryLight : AppColors.primaryDark,
                ),
              ),
            ],
          ),
          if (selectedItems.isNotEmpty) ...[
            SizedBox(height: widget.compact ? 8 : 10),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: nameFontSize,
                                  height: 1.3,
                                  color: t.ink,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.quantity}x GHS ${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: t.muted,
                                  fontSize: metaFontSize,
                                ),
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
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 12,
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
