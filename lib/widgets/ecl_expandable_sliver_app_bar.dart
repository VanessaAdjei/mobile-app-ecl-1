import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../pages/app_back_button.dart';

/// Expandable green header (gradient, circles) used across profile, policies,
/// and other secondary screens.
///
/// When [heroTitle] matches [toolbarTitle] (ignoring case), the expanded
/// region does **not** repeat the same headline; [heroSubtitle] is shown
/// there as the large line instead.
class EclExpandableSliverAppBar extends StatelessWidget {
  const EclExpandableSliverAppBar({
    super.key,
    required this.toolbarTitle,
    required this.heroTitle,
    this.heroSubtitle,
    this.expandedHeight,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.onBack,
    this.leadingWidth = 56,
  });

  /// Shown in the collapsed toolbar (center or start per [centerTitle]).
  final String toolbarTitle;

  /// Large headline in the expanded region when it differs from [toolbarTitle].
  final String heroTitle;

  /// Context line under the expanded headline; if [heroTitle] matches
  /// [toolbarTitle], this line is shown **as** the expanded headline instead.
  final String? heroSubtitle;

  /// When null, height is derived from content.
  final double? expandedHeight;

  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final VoidCallback? onBack;
  final double leadingWidth;

  bool _hideHeroBecauseSameAsToolbar() {
    final h = heroTitle.trim();
    final t = toolbarTitle.trim();
    return h.isNotEmpty && h.toLowerCase() == t.toLowerCase();
  }

  /// Flex region under the toolbar row: text + bottom padding only (no overline).
  double _flexRegionHeight() {
    final sub = heroSubtitle?.trim();
    final hasSub = sub != null && sub.isNotEmpty;
    final hideHero = _hideHeroBecauseSameAsToolbar();
    const bottomPad = 8.0;
    const gapUnderToolbar = 2.0;
    const heroLine = 18.0 * 1.05;
    const subLine = 12.0 * 1.15;

    if (hideHero && hasSub) {
      // Subtitle becomes the expanded headline — allow up to two lines.
      return gapUnderToolbar + heroLine * 2 + 4 + bottomPad;
    }
    if (hideHero) {
      return gapUnderToolbar + bottomPad;
    }
    if (heroTitle.trim().isEmpty) {
      if (hasSub) return gapUnderToolbar + subLine + bottomPad;
      return gapUnderToolbar + bottomPad;
    }
    if (hasSub) {
      return gapUnderToolbar + heroLine + 2 + subLine + bottomPad;
    }
    return gapUnderToolbar + heroLine + bottomPad;
  }

  double _effectiveExpandedHeight() {
    if (expandedHeight != null) return expandedHeight!;
    return kToolbarHeight + _flexRegionHeight();
  }

  @override
  Widget build(BuildContext context) {
    final sub = heroSubtitle?.trim();
    final hasSub = sub != null && sub.isNotEmpty;
    final hideHero = _hideHeroBecauseSameAsToolbar();

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: _effectiveExpandedHeight(),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: leading ??
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: AppBackButton(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              iconColor: Colors.white,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
          ),
      leadingWidth: leadingWidth,
      title: Text(
        toolbarTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
      centerTitle: centerTitle,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        background: Stack(
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
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 64, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hideHero && heroTitle.trim().isNotEmpty) ...[
                        Text(
                          heroTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                      ],
                      if (hideHero && hasSub) ...[
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (!hideHero && hasSub) ...[
                        Text(
                          sub,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
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
