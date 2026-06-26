// pages/loggedout.dart
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/pages/main_tab_shell.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme_colors.dart';
import '../widgets/post_checkout/post_checkout_design.dart';

class LoggedOutScreen extends StatefulWidget {
  const LoggedOutScreen({super.key});

  @override
  State<LoggedOutScreen> createState() => _LoggedOutScreenState();
}

class _LoggedOutScreenState extends State<LoggedOutScreen> {
  bool _isStarting = false;

  Future<void> _startShopping() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      await AuthService.logout();
      if (mounted) {
        await context.read<NotificationProvider>().clearForSignedOutUser();
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainTabShell(initialIndex: 0)),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _openSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignInScreen(returnTo: '/'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _SignedOutPalette.canvas(theme),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _SignedOutColorWash(theme: theme),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    PostCheckoutDesign.logoAsset,
                    height: 30,
                    fit: BoxFit.contain,
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 22),
                  const _OrnamentalRule(),
                  const SizedBox(height: 28),
                  const _SignedOutEmblem(),
                  const SizedBox(height: 24),
                  Text(
                    'SIGNED OUT',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.4,
                      color: AppColors.primaryDark,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 80.ms),
                  const SizedBox(height: 10),
                  Text(
                    'See you soon',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: _SignedOutPalette.ink(theme),
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ).animate().fadeIn(duration: 550.ms, delay: 120.ms),
                  const SizedBox(height: 12),
                  Text(
                    'You\'ve been signed out safely.\n'
                    'Thanks for choosing Ernest Chemists.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: _SignedOutPalette.muted(theme),
                      height: 1.55,
                    ),
                  ).animate().fadeIn(duration: 550.ms, delay: 160.ms),
                  const Spacer(),
                  const _GuestModeBanner(),
                  const SizedBox(height: 16),
                  const _BenefitRow(),
                  const Spacer(),
                  const _OrnamentalRule(width: 120),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isStarting ? null : _startShopping,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isStarting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Browse as guest',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isStarting ? null : _openSignIn,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: AppColors.primaryDark,
                    ),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 240.ms),
                  SizedBox(height: 8 + bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOutColorWash extends StatelessWidget {
  const _SignedOutColorWash({required this.theme});

  final AppThemeColors theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.isDark
                ? [
                    AppColors.primaryDark.withValues(alpha: 0.35),
                    AppColors.primary.withValues(alpha: 0.08),
                    _SignedOutPalette.canvas(theme),
                  ]
                : [
                    const Color(0xFFD4EDE0),
                    const Color(0xFFEEF7F1),
                    _SignedOutPalette.canvas(theme),
                  ],
            stops: const [0.0, 0.32, 0.58],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

abstract final class _SignedOutPalette {
  static Color canvas(AppThemeColors theme) =>
      theme.isDark ? const Color(0xFF111827) : const Color(0xFFFAFAF8);

  static Color ink(AppThemeColors theme) =>
      theme.isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1C1917);

  static Color muted(AppThemeColors theme) =>
      theme.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF78716C);

  static Color line(AppThemeColors theme) =>
      theme.isDark
          ? Colors.white.withValues(alpha: 0.12)
          : AppColors.primary.withValues(alpha: 0.18);
}

class _OrnamentalRule extends StatelessWidget {
  const _OrnamentalRule({this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final line = _SignedOutPalette.line(theme);

    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: line)),
        ],
      ),
    );
  }
}

class _SignedOutEmblem extends StatelessWidget {
  const _SignedOutEmblem();

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : const Color(0xFFE2F5EA),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: const Icon(
        Icons.check_rounded,
        color: AppColors.primaryDark,
        size: 30,
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: theme.isDark ? 0.3 : 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep shopping without signing in — your account is always here when you need it.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _SignedOutPalette.muted(theme),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 550.ms, delay: 180.ms);
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow();

  static const _items = [
    (Icons.local_shipping_outlined, 'Delivery'),
    (Icons.verified_user_outlined, 'Trusted'),
    (Icons.medical_services_outlined, 'Care'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final line = _SignedOutPalette.line(theme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: line),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _items[i].$1,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _items[i].$2.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                        color: _SignedOutPalette.muted(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 550.ms, delay: 220.ms);
  }
}
