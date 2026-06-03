import 'package:eclapp/widgets/post_checkout/post_checkout_design.dart';
import 'package:eclapp/widgets/post_checkout/post_checkout_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Primary + optional support actions for post-checkout screens.
class PostCheckoutActionButtons extends StatelessWidget {
  const PostCheckoutActionButtons({
    super.key,
    required this.accent,
    required this.onHome,
    this.onSupport,
    this.showSupport = true,
    this.animate = true,
    this.breathingPrimary = true,
  });

  final Color accent;
  final VoidCallback onHome;
  final VoidCallback? onSupport;
  final bool showSupport;
  final bool animate;
  final bool breathingPrimary;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: double.infinity,
      decoration: PostCheckoutDesign.compactCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeActionButton(accent: accent, onPressed: onHome),
          if (showSupport && onSupport != null) ...[
            Divider(height: 1, color: PostCheckoutDesign.border),
            _SupportActionButton(accent: accent, onPressed: onSupport!),
          ],
        ],
      ),
    );

    if (breathingPrimary) {
      card = PostCheckoutBreathingButton(child: card);
    }

    if (!animate) return card;

    return card
        .animate()
        .fadeIn(duration: 360.ms, delay: 80.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Back to home',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Continue shopping',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportActionButton extends StatelessWidget {
  const _SupportActionButton({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PostCheckoutDesign.accentLight.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Icon(
                  Icons.headset_mic_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact support',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PostCheckoutDesign.ink,
                        letterSpacing: -0.15,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get help with your order',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: PostCheckoutDesign.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: PostCheckoutDesign.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
