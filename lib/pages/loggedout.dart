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
      backgroundColor: theme.pageBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.isDark
                ? [
                    AppColors.navBar.withValues(alpha: 0.35),
                    theme.pageBg,
                    theme.pageBg,
                  ]
                : [
                    const Color(0xFFE8F5EC),
                    theme.pageBg,
                    theme.pageBg,
                  ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottom),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _SignedOutMark(theme: theme),
                const SizedBox(height: 28),
                Image.asset(
                  'assets/images/png.png',
                  height: 44,
                  fit: BoxFit.contain,
                ).animate().fadeIn(duration: 400.ms, delay: 120.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      duration: 480.ms,
                      delay: 120.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 20),
                Text(
                  'Signed out successfully',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: theme.ink,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 380.ms, delay: 180.ms).slideY(
                      begin: 0.12,
                      end: 0,
                      duration: 420.ms,
                      delay: 180.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 8),
                Text(
                  'Thanks for visiting Ernest Chemists',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: theme.muted,
                    height: 1.45,
                  ),
                ).animate().fadeIn(duration: 380.ms, delay: 220.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 420.ms,
                      delay: 220.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 28),
                const _QuickPerksRow(),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isStarting ? null : _startShopping,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isStarting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Start Shopping',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 260.ms).slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 440.ms,
                      delay: 260.ms,
                    ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isStarting ? null : _openSignIn,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primaryDark,
                  ),
                  child: Text(
                    'Sign in',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedOutMark extends StatelessWidget {
  const _SignedOutMark({required this.theme});

  final AppThemeColors theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.logout_rounded,
        color: Colors.white,
        size: 38,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 360.ms);
  }
}

class _QuickPerksRow extends StatelessWidget {
  const _QuickPerksRow();

  static const _icons = [
    Icons.local_shipping_outlined,
    Icons.verified_user_outlined,
    Icons.medical_services_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _icons.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
              boxShadow: theme.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(
              _icons[i],
              size: 22,
              color: AppColors.primaryDark,
            ),
          ).animate().fadeIn(duration: 360.ms, delay: (220 + i * 60).ms).slideY(
                begin: 0.15,
                end: 0,
                duration: 400.ms,
                delay: (220 + i * 60).ms,
              ),
        ],
      ],
    );
  }
}
