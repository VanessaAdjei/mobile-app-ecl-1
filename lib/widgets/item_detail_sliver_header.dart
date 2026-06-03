import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/models/product_model.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/widgets/item_detail_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Green product header: expanded shows category + name; collapsed shows search bar.
class ItemDetailSliverHeader extends StatefulWidget {
  const ItemDetailSliverHeader({
    super.key,
    required this.leading,
    this.onToggleSearch,
    this.onSearchClose,
    required this.searchFocusNode,
    this.scrollController,
    this.product,
    this.loading = false,
    this.displayNameBuilder,
  });

  final Widget leading;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onSearchClose;
  final FocusNode searchFocusNode;
  final ScrollController? scrollController;
  final Product? product;
  final bool loading;
  final String Function(Product product)? displayNameBuilder;

  @override
  State<ItemDetailSliverHeader> createState() => _ItemDetailSliverHeaderState();
}

class _ItemDetailSliverHeaderState extends State<ItemDetailSliverHeader> {
  static const double _toolbarRowHeight = kToolbarHeight;
  static const double _chipToNameGap = 18;
  static const double _collapsedThreshold = 0.88;

  double _collapseT = 0;

  bool get _isCollapsed => _collapseT >= _collapsedThreshold;

  String _name(Product p) =>
      widget.displayNameBuilder?.call(p) ??
      (p.name.trim().isNotEmpty ? p.name.trim() : p.urlName);

  double _heroFlexHeight(Product p) {
    final hasCategory = p.category.trim().isNotEmpty;
    final longName = _name(p).length > 34;
    var h = 2.0 + (longName ? 28.0 : 12.0) + 8.0;
    if (hasCategory) h += 36.0;
    return h;
  }

  double _expandedHeight() {
    if (widget.loading) return _toolbarRowHeight + 36;
    if (widget.product != null) {
      return _toolbarRowHeight + _heroFlexHeight(widget.product!);
    }
    return _toolbarRowHeight;
  }

  double get _collapseScrollOffset =>
      (_expandedHeight() - _toolbarRowHeight).clamp(0.0, double.infinity);

  void _onCollapseTChanged(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if ((clamped - _collapseT).abs() < 0.02) return;
    setState(() => _collapseT = clamped);
  }

  Future<void> _scrollToCollapsed() async {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final target = _collapseScrollOffset.clamp(0.0, sc.position.maxScrollExtent);
    await sc.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted) widget.searchFocusNode.requestFocus();
  }

  Future<void> _scrollToExpanded() async {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    await sc.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    widget.searchFocusNode.unfocus();
  }

  void _handleToggleSearch() {
    if (_isCollapsed) {
      _scrollToExpanded();
    } else {
      _scrollToCollapsed();
    }
    widget.onToggleSearch?.call();
  }

  void _handleSearchClose() {
    _scrollToExpanded();
    widget.onSearchClose?.call();
  }

  Widget _gradientBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0D3D18),
                AppColors.accent,
                const Color(0xFF2E7D32),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -40,
          bottom: -28,
          child: CircleAvatar(
            radius: 72,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        Positioned(
          left: -20,
          top: 48,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      splashRadius: 14,
      icon: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildToolbarActions() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isCollapsed)
                _buildToolbarIcon(
                  icon: Icons.search_rounded,
                  onPressed: _handleToggleSearch,
                  tooltip: 'Search',
                ),
              CartIconButton(
                iconColor: Colors.white,
                iconSize: 16,
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                visualDensity: VisualDensity.compact,
                splashRadius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildToolbarSearchField(BuildContext context) {
    if (!_isCollapsed) return null;
    final width = MediaQuery.sizeOf(context).width - 52 - 56;
    return SizedBox(
      width: width.clamp(120.0, double.infinity),
      child: ItemDetailSearchBar(
        inHeader: true,
        focusNode: widget.searchFocusNode,
        onClose: _handleSearchClose,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget? _buildExpandedCategoryChip(Product p) {
    final category = p.category.trim();
    if (category.isEmpty) return null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          category.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }

  Widget? _buildExpandedHero(Product p) {
    final chip = _buildExpandedCategoryChip(p);
    final name = _name(p);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip != null) ...[
            chip,
            const SizedBox(height: _chipToNameGap),
          ],
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildExpandedContent() {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          'Product',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }
    if (widget.product != null) {
      return _buildExpandedHero(widget.product!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final expandedContent = _buildExpandedContent();

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: _expandedHeight(),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: widget.leading,
      leadingWidth: 52,
      centerTitle: false,
      titleSpacing: 8,
      title: _buildToolbarSearchField(context),
      actions: [_buildToolbarActions()],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            _gradientBackground(),
            if (expandedContent != null)
              _FlexibleSpaceCollapseFade(
                onCollapseTChanged: _onCollapseTChanged,
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: expandedContent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fades expanded header content and reports collapse progress to the parent.
class _FlexibleSpaceCollapseFade extends StatelessWidget {
  const _FlexibleSpaceCollapseFade({
    required this.onCollapseTChanged,
    required this.child,
  });

  final ValueChanged<double> onCollapseTChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();

    var collapseT = 0.0;
    if (settings != null) {
      final range = settings.maxExtent - settings.minExtent;
      if (range > 0) {
        collapseT =
            1.0 - (settings.currentExtent - settings.minExtent) / range;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onCollapseTChanged(collapseT);
    });

    final visible = (1.0 - collapseT).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: visible < 0.5,
      child: Opacity(
        opacity: visible,
        child: child,
      ),
    );
  }
}
