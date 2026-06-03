import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../models/cart_item.dart';
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
    final selectedItems = widget.selectedItems;

    final sectionPadding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : PaymentSectionStyle.padding;
    final itemPadding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(10);
    final itemGap = widget.compact ? 6.0 : 7.0;
    final thumbSize = widget.compact ? 40.0 : 46.0;
    final titleFontSize = widget.compact ? 13.0 : 14.0;
    final nameFontSize = widget.compact ? 12.0 : 13.0;
    final metaFontSize = widget.compact ? 10.0 : 11.0;
    final lineTotalFontSize = widget.compact ? 12.0 : 13.0;
    final accentBarHeight = widget.compact ? 15.0 : 16.0;

    return Container(
      margin: PaymentSectionStyle.margin,
      padding: sectionPadding,
      decoration: PaymentSectionStyle.cardDecoration(),
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
                  color: AppColors.primaryDark,
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FAF7),
                      borderRadius: BorderRadius.circular(
                          PaymentSectionStyle.innerRadius),
                      border:
                          Border.all(color: PaymentSectionStyle.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF9F3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrl(item.image),
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFFEEF9F3),
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
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.quantity}x GHS ${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
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
                color: Colors.blue,
                onTap: () => setState(() => _showAllItems = true),
              ),
            if (selectedItems.length > 3 && _showAllItems)
              _ExpandToggle(
                label: 'Show less',
                icon: Icons.expand_less,
                color: Colors.grey,
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
  final MaterialColor color;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color.shade700,
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
