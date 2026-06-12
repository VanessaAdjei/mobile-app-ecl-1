import 'package:eclapp/pages/app_back_button.dart';
import 'package:eclapp/utils/app_theme_colors.dart';
import 'package:eclapp/widgets/cart_icon_button.dart';
import 'package:eclapp/widgets/category/subcategory_design.dart';
import 'package:flutter/material.dart';

/// Refined app bar shared by [SubcategoryPage] and [ProductListPage].
class CategoryBrowseAppBar extends StatelessWidget {
  const CategoryBrowseAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow = 'Shop',
    this.onBack,
    this.showCart = true,
  });

  final String title;
  final String subtitle;
  final String eyebrow;
  final VoidCallback? onBack;
  final bool showCart;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appColors.isDark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0B1A12), Color(0xFF122A1C), Color(0xFF1A3D28)]
              : const [Color(0xFF0E2E1C), Color(0xFF1B5E32), Color(0xFF2E7D46)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppBackButton(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    iconColor: Colors.white,
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showCart)
                    CartIconButton(
                      iconColor: Colors.white,
                      iconSize: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// In-content header above the product grid.
class CategorySectionHeader extends StatelessWidget {
  const CategorySectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.itemCount,
  });

  final String title;
  final String subtitle;
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: SubcategoryDesign.contentBg(context),
        border: Border(
          bottom: BorderSide(color: SubcategoryDesign.railBorder(context)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 42,
            margin: const EdgeInsets.only(top: 2, right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SubcategoryDesign.accent(context),
                  SubcategoryDesign.accentDark(context),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SubcategoryDesign.ink(context),
                    height: 1.2,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SubcategoryDesign.muted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (itemCount != null && itemCount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: SubcategoryDesign.countChipBg(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: SubcategoryDesign.countChipBorder(context),
                ),
              ),
              child: Text(
                '$itemCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SubcategoryDesign.selectedInk(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders subcategory names without splitting words across lines.
class _SubcategoryRailWords extends StatelessWidget {
  const _SubcategoryRailWords({
    required this.label,
    required this.style,
  });

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final words = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return Text('?', maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }

    if (words.length == 1) {
      return Text(
        words.first,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < words.length; i++)
          Text(
            words[i],
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              height: i < words.length - 1 ? 1.1 : style.height,
            ),
          ),
      ],
    );
  }
}

class CategorySubcategoryRailTile extends StatelessWidget {
  const CategorySubcategoryRailTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final display = compact
        ? (label.trim().isNotEmpty ? label.trim()[0].toUpperCase() : '?')
        : label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 7,
            vertical: compact ? 0 : 6,
          ),
          height: compact ? 30 : null,
          alignment: compact ? Alignment.center : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 8 : 10),
            gradient: selected && !compact
                ? LinearGradient(
                    colors: [
                      SubcategoryDesign.accent(context),
                      SubcategoryDesign.accentDark(context),
                    ],
                  )
                : null,
            color: selected
                ? (compact
                    ? SubcategoryDesign.selectedTint(context)
                    : null)
                : SubcategoryDesign.unselectedItemBg(context),
            border: Border.all(
              color: selected
                  ? (compact
                      ? SubcategoryDesign.selectedBorder(context)
                      : Colors.transparent)
                  : SubcategoryDesign.railBorder(context),
            ),
            boxShadow: selected && !compact
                ? [
                    BoxShadow(
                      color: SubcategoryDesign.accent(context)
                          .withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: selected
                            ? SubcategoryDesign.accent(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? SubcategoryDesign.selectedInk(context)
                            : SubcategoryDesign.unselectedInk(context),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    Expanded(
                      child: _SubcategoryRailWords(
                        label: display,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : SubcategoryDesign.unselectedInk(context),
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CategoryBrowsePaginationBar extends StatelessWidget {
  const CategoryBrowsePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  static const double _footerHeight = 36;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = context.appColors;
    final canGoBack = currentPage > 0;
    final canGoForward = currentPage < totalPages - 1;
    final progress = (currentPage + 1) / totalPages;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: SubcategoryDesign.railBorder(context)),
        ),
      ),
      child: SizedBox(
        height: _footerHeight,
        width: double.infinity,
        child: Center(
          child: _CategoryPaginationPill(
            theme: theme,
            currentPage: currentPage,
            totalPages: totalPages,
            progress: progress,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ),
      ),
    );
  }
}

class _CategoryPaginationPill extends StatelessWidget {
  const _CategoryPaginationPill({
    required this.theme,
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final AppThemeColors theme;
  final int currentPage;
  final int totalPages;
  final double progress;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: SubcategoryDesign.accent(context)
                .withValues(alpha: theme.isDark ? 0.12 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 236),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.isDark
                  ? const [Color(0xFF151D2B), Color(0xFF111827)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF8FBF9)],
            ),
            border: Border.all(
              color: SubcategoryDesign.selectedBorder(context),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PaginationEdgeButton(
                icon: Icons.chevron_left_rounded,
                enabled: canGoBack,
                onTap: onPrevious,
              ),
              Container(
                width: 1,
                height: 16,
                color: SubcategoryDesign.railBorder(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentPage + 1} / $totalPages',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SubcategoryDesign.selectedInk(context),
                          height: 1.1,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: SubcategoryDesign.railBorder(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            SubcategoryDesign.accent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: SubcategoryDesign.railBorder(context),
              ),
              _PaginationEdgeButton(
                icon: Icons.chevron_right_rounded,
                enabled: canGoForward,
                onTap: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationEdgeButton extends StatelessWidget {
  const _PaginationEdgeButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? SubcategoryDesign.selectedTint(context)
          : Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 32,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? SubcategoryDesign.selectedInk(context)
                : SubcategoryDesign.muted(context).withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// Scroll-to-top FAB styling.
class CategoryBrowseScrollFab extends StatelessWidget {
  const CategoryBrowseScrollFab({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: visible ? 1 : 0.85,
          child: FloatingActionButton.small(
            elevation: 4,
            backgroundColor: SubcategoryDesign.accent(context),
            foregroundColor: Colors.white,
            onPressed: onPressed,
            child: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}
