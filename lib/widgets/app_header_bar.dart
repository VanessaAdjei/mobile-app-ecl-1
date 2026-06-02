// widgets/app_header_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../pages/app_back_button.dart';
import '../widgets/cart_icon_button.dart';

/// [accent] matches [EclExpandableSliverAppBar] (deep green gradient + circles).
enum AppHeaderBackground { standard, accent }

class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBack;
  final bool showCart;
  final AppHeaderBackground background;

  /// When true, pads below the status bar / notch (use for full-screen body headers).
  final bool reserveStatusBar;

  /// Tighter toolbar padding and title size (checkout flow headers).
  final bool compact;

  const AppHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.showCart = true,
    this.background = AppHeaderBackground.standard,
    this.reserveStatusBar = false,
    this.compact = false,
  });

  bool get _hasSubtitle => subtitle != null && subtitle!.trim().isNotEmpty;

  double _contentHeight() =>
      (compact ? 44.0 : kToolbarHeight) +
      (_hasSubtitle ? 52 : (compact ? 6 : 12));

  static double _statusBarHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  static double totalHeight(
    BuildContext context, {
    bool hasSubtitle = false,
    bool reserveStatusBar = true,
    bool compact = false,
  }) {
    final content = (compact ? 44.0 : kToolbarHeight) +
        (hasSubtitle ? 52 : (compact ? 6 : 12));
    final top = reserveStatusBar ? _statusBarHeight(context) : 0;
    return top + content;
  }

  /// Use as [Scaffold.appBar] so height includes the status-bar inset.
  static PreferredSize forScaffold(
    BuildContext context, {
    Key? key,
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    bool showBack = true,
    bool showCart = true,
    AppHeaderBackground background = AppHeaderBackground.standard,
    bool compact = false,
  }) {
    final hasSub = subtitle != null && subtitle.trim().isNotEmpty;
    return PreferredSize(
      key: key,
      preferredSize: Size.fromHeight(
        totalHeight(
          context,
          hasSubtitle: hasSub,
          reserveStatusBar: true,
          compact: compact,
        ),
      ),
      child: AppHeaderBar(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        showBack: showBack,
        showCart: showCart,
        background: background,
        reserveStatusBar: true,
        compact: compact,
      ),
    );
  }

  @override
  Size get preferredSize {
    final statusFallback = reserveStatusBar ? 47.0 : 0.0;
    return Size.fromHeight(_contentHeight() + statusFallback);
  }

  @override
  Widget build(BuildContext context) {
    final topInset =
        reserveStatusBar ? MediaQuery.paddingOf(context).top : 0.0;
    final contentHeight = _contentHeight();

    final toolbar = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 4 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            AppBackButton(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              iconColor: Colors.white,
              onPressed: onBack ??
                  () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                    } else {
                      navigator.pushReplacementNamed(AppRoutes.home);
                    }
                  },
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: Colors.white,
                        letterSpacing: compact ? 0.2 : -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_hasSubtitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.1,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showCart) ...[
            const SizedBox(width: 8),
            const CartIconButton(
              iconColor: Colors.white,
              iconSize: 22,
              backgroundColor: Colors.transparent,
            ),
          ],
        ],
      ),
    );

    Widget content;
    if (background == AppHeaderBackground.accent) {
      content = ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _AccentHeaderBackground(),
            toolbar,
          ],
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade600,
              Colors.green.shade700,
              Colors.green.shade800,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: toolbar,
      );
    }

    return SizedBox(
      height: topInset + contentHeight,
      child: Column(
        children: [
          SizedBox(height: topInset),
          SizedBox(height: contentHeight, child: content),
        ],
      ),
    );
  }
}

class _AccentHeaderBackground extends StatelessWidget {
  const _AccentHeaderBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D3D18),
                AppColors.accent,
                Color(0xFF2E7D32),
              ],
              stops: [0.0, 0.45, 1.0],
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
}
