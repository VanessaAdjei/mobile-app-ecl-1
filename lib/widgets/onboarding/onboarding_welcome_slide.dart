import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Final onboarding step — thank-you message before first home visit.
class OnboardingWelcomeSlide extends StatelessWidget {
  const OnboardingWelcomeSlide({
    super.key,
    required this.onGetStarted,
    required this.progressDots,
    this.isLoading = false,
  });

  final VoidCallback onGetStarted;
  final Widget progressDots;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight =
        (size.height * 0.32).clamp(240.0, 300.0) + topInset;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: SizedBox(
        height: size.height,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipPath(
                      clipper: _WaveHeaderClipper(),
                      child: SizedBox(
                        height: headerHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF062A12),
                                  Color(0xFF0D3D18),
                                  AppColors.accent,
                                  Color(0xFF2E7D32),
                                ],
                                stops: [0.0, 0.28, 0.62, 1.0],
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.85, -0.35),
                                radius: 1.1,
                                colors: [
                                  AppColors.primaryLight.withValues(alpha: 0.28),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.75, 0.9),
                                radius: 0.85,
                                colors: [
                                  Colors.white.withValues(alpha: 0.07),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: -36,
                            top: topInset + 8,
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          Positioned(
                            left: -28,
                            bottom: 36,
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          Positioned(
                            right: 48,
                            bottom: 52,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primaryLight.withValues(alpha: 0.14),
                            ),
                          ),
                          Center(
                            child: _WelcomeLogo(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                    child: Column(
                      children: [
                        Text(
                          'We appreciate you choosing us for your health and wellness essentials.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.55,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Thank you. We are always ready to assist you the best way we can.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your health, our priority',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          progressDots,
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 28, 20 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : onGetStarted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Get Started',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

class _WelcomeLogo extends StatefulWidget {
  const _WelcomeLogo();

  static const double _outerRadius = 72;
  static const double _innerRadius = 66;

  @override
  State<_WelcomeLogo> createState() => _WelcomeLogoState();
}

class _WelcomeLogoState extends State<_WelcomeLogo>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterOpacity;
  late final Animation<double> _pulseScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _enterScale = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );
    _enterOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _pulseScale = Tween<double>(begin: 1, end: 1.045).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _enterController.forward();
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _enterController,
        _pulseController,
        _glowController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _enterOpacity.value,
          child: Transform.scale(
            scale: _enterScale.value * _pulseScale.value,
            child: child,
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _WelcomeLogo._outerRadius * 2 + 28,
            height: _WelcomeLogo._outerRadius * 2 + 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: _glowOpacity.value),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: _WelcomeLogo._outerRadius,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              child: CircleAvatar(
                radius: _WelcomeLogo._innerRadius,
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/png.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 10,
      size.width,
      size.height - 24,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
