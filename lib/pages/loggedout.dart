// pages/loggedout.dart
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/pages/main_tab_shell.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

class LoggedOutScreen extends StatefulWidget {
  const LoggedOutScreen({super.key});

  @override
  State<LoggedOutScreen> createState() => _LoggedOutScreenState();
}

class _LoggedOutScreenState extends State<LoggedOutScreen> {
  bool _isStarting = false;

  Future<void> _ensureLoggedOut() async {
    await AuthService.logout();
  }

  Future<void> _startShopping() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      await _ensureLoggedOut();
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF6),
      body: Column(
        children: [
          const _LoggedOutHero(),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Browse without signing in',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your cart and preferences stay on this device. '
                            'Sign in anytime to sync orders and checkout faster.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.55,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _TrustFeatureRow(),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: 180.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 480.ms,
                          delay: 180.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.32,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isStarting ? null : _startShopping,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Start shopping',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: 280.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 480.ms,
                          delay: 280.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _isStarting ? null : _openSignIn,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppColors.primaryDark,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Sign in to my account',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 420.ms, delay: 340.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 460.ms,
                          delay: 340.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedOutHero extends StatelessWidget {
  const _LoggedOutHero();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: topInset + 248,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF041A0C),
                    Color(0xFF0D3D18),
                    Color(0xFF1B5E32),
                    Color(0xFF2E7D32),
                  ],
                  stops: [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.35),
                  radius: 1.05,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            child: CustomPaint(
              size: const Size(double.infinity, 42),
              painter: _HeroWavePainter(
                fillColor: const Color(0xFFF4FAF6),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, topInset + 18, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/png.png',
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.82, 0.82),
                      end: const Offset(1, 1),
                      duration: 560.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 420.ms),
                const SizedBox(height: 18),
                Text(
                  'Signed out successfully',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 450.ms, delay: 80.ms)
                    .slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 500.ms,
                      delay: 80.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 8),
                Text(
                  'Thanks for visiting Ernest Chemists',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 450.ms, delay: 140.ms)
                    .slideY(
                      begin: 0.12,
                      end: 0,
                      duration: 480.ms,
                      delay: 140.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustFeatureRow extends StatelessWidget {
  const _TrustFeatureRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _TrustFeatureTile(
            icon: Icons.local_shipping_outlined,
            label: 'Fast delivery',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _TrustFeatureTile(
            icon: Icons.verified_user_outlined,
            label: 'Secure checkout',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _TrustFeatureTile(
            icon: Icons.medical_services_outlined,
            label: 'Pharmacist care',
          ),
        ),
      ],
    );
  }
}

class _TrustFeatureTile extends StatelessWidget {
  const _TrustFeatureTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryDark),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroWavePainter extends CustomPainter {
  const _HeroWavePainter({required this.fillColor});

  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fillColor;
    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.02,
        size.width * 0.5,
        size.height * 0.22,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.42,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroWavePainter oldDelegate) =>
      oldDelegate.fillColor != fillColor;
}
