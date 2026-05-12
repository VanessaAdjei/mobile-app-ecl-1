// widgets/app_header_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/app_back_button.dart';
import '../widgets/cart_icon_button.dart';

class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showCart;

  const AppHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showCart = true,
  });

  bool get _hasSubtitle => subtitle != null && subtitle!.trim().isNotEmpty;

  /// Scaffold [appBar] passes a tight max height; two-line headers need more
  /// than [kToolbarHeight] alone. Extra top padding was removed — [SafeArea]
  /// owns status-bar insets.
  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (_hasSubtitle ? 52 : 12),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppBackButton(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                onPressed: onBack ??
                    () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
              ),
              const SizedBox(width: 12),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: Colors.white,
                            letterSpacing: -0.2,
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
        ),
      ),
    );
  }
}
