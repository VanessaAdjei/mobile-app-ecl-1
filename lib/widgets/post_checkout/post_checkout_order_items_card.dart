import 'package:eclapp/config/api_config.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Order items list with header band matching [PostCheckoutOrderProgressCard].
class PostCheckoutOrderItemsCard extends StatefulWidget {
  const PostCheckoutOrderItemsCard({
    super.key,
    required this.items,
    required this.accent,
    this.maxVisibleCollapsed = 3,
    this.animate = true,
    this.showAllItems = false,
  });

  final List<OrderTrackingItem> items;
  final Color accent;
  final int maxVisibleCollapsed;
  final bool animate;

  /// When true, lists every item with no expand/collapse control.
  final bool showAllItems;

  @override
  State<PostCheckoutOrderItemsCard> createState() =>
      _PostCheckoutOrderItemsCardState();
}

class _PostCheckoutOrderItemsCardState extends State<PostCheckoutOrderItemsCard> {
  bool _expanded = false;

  int get _totalQty =>
      widget.items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get _itemsSubtotal =>
      widget.items.fold<double>(0, (sum, i) => sum + i.lineTotal);

  List<OrderTrackingItem> get _visibleItems {
    if (widget.showAllItems ||
        _expanded ||
        widget.items.length <= widget.maxVisibleCollapsed) {
      return widget.items;
    }
    return widget.items.take(widget.maxVisibleCollapsed).toList();
  }

  int get _hiddenCount =>
      widget.items.length - widget.maxVisibleCollapsed;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final showToggle = !widget.showAllItems &&
        widget.items.length > widget.maxVisibleCollapsed;

    return Container(
      width: double.infinity,
      decoration: PostCheckoutDesign.compactCard(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: widget.accent),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ItemsCardHeader(
                  accent: widget.accent,
                  itemCount: widget.items.length,
                  totalQty: _totalQty,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 12, 0),
                  child: Column(
                    children: [
                      ..._visibleItems.asMap().entries.map((entry) {
                        final row = PostCheckoutOrderItemRow(
                          item: entry.value,
                          accent: widget.accent,
                          showDivider: entry.key < _visibleItems.length - 1,
                        );
                        if (!widget.animate) return row;
                        return row
                            .animate()
                            .fadeIn(
                              duration: 280.ms,
                              delay: (40 + entry.key * 50).ms,
                            )
                            .slideX(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      }),
                      if (showToggle) ...[
                        const SizedBox(height: 4),
                        _ExpandToggle(
                          accent: widget.accent,
                          expanded: _expanded,
                          hiddenCount: _hiddenCount,
                          onTap: () => setState(() => _expanded = !_expanded),
                        ),
                      ],
                    ],
                  ),
                ),
                _ItemsCardFooter(
                  accent: widget.accent,
                  subtotal: _itemsSubtotal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsCardHeader extends StatelessWidget {
  const _ItemsCardHeader({
    required this.accent,
    required this.itemCount,
    required this.totalQty,
  });

  final Color accent;
  final int itemCount;
  final int totalQty;

  @override
  Widget build(BuildContext context) {
    final t = context.appColors;
    final productLabel =
        '$itemCount product${itemCount == 1 ? '' : 's'} · $totalQty unit${totalQty == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PostCheckoutDesign.accentLight(context).withValues(alpha: 0.85),
            t.surface,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: PostCheckoutDesign.border(context)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your items',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PostCheckoutDesign.ink(context),
                    letterSpacing: -0.25,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  productLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: PostCheckoutDesign.muted(context),
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCardFooter extends StatelessWidget {
  const _ItemsCardFooter({
    required this.accent,
    required this.subtotal,
  });

  final Color accent;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 12, 11),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PostCheckoutDesign.pageBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PostCheckoutDesign.border(context)),
      ),
      child: Row(
        children: [
          Text(
            'ITEMS TOTAL',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: PostCheckoutDesign.muted(context),
            ),
          ),
          const Spacer(),
          Text(
            'GHS ${subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.accent,
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final Color accent;
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded
        ? 'Show less'
        : 'Show $hiddenCount more item${hiddenCount == 1 ? '' : 's'}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single product row for post-checkout items surfaces.
class PostCheckoutOrderItemRow extends StatelessWidget {
  const PostCheckoutOrderItemRow({
    super.key,
    required this.item,
    required this.accent,
    this.showDivider = true,
  });

  final OrderTrackingItem item;
  final Color accent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl.startsWith('http')
        ? item.imageUrl
        : ApiConfig.getProductImageUrl(item.imageUrl);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: PostCheckoutDesign.pageBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PostCheckoutDesign.border(context)),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl.isEmpty
                    ? Icon(
                        Icons.medication_outlined,
                        size: 22,
                        color: PostCheckoutDesign.muted(context).withValues(alpha: 0.5),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.medication_outlined,
                          size: 22,
                          color:
                              PostCheckoutDesign.muted(context).withValues(alpha: 0.5),
                        ),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PostCheckoutDesign.ink(context),
                        height: 1.25,
                        letterSpacing: -0.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            '×${item.quantity}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                        if (item.batchNo.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.batchNo,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: PostCheckoutDesign.muted(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.quantity > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        'GHS ${item.price.toStringAsFixed(2)} each',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: PostCheckoutDesign.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'GHS ${item.lineTotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PostCheckoutDesign.ink(context),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: PostCheckoutDesign.border(context)),
      ],
    );
  }
}
