import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short branded splash shown once before terms on first install.
class BrandLaunchSplashPage extends StatefulWidget {
  const BrandLaunchSplashPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<BrandLaunchSplashPage> createState() => _BrandLaunchSplashPageState();
}

class _BrandLaunchSplashPageState extends State<BrandLaunchSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _exitController;
  late final AnimationController _shimmerController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _exitFade;

  bool _isExiting = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _exitFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _logoController.forward();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _textController.forward();
    });

    _autoTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted && !_isExiting) _finish();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _exitController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isExiting) return;
    _isExiting = true;
    _autoTimer?.cancel();

    await _exitController.forward();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_brand_launch_splash', true);
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isExiting ? null : _finish,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
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
                    stops: [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.95,
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -40,
                top: 80,
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              Positioned(
                right: -30,
                bottom: 120,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _textController,
                    _shimmerController,
                  ]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight
                                      .withValues(alpha: 0.35),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 64,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            child: CircleAvatar(
                              radius: 58,
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
                        ],
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _textOpacity,
                        child: SlideTransition(
                          position: _textSlide,
                          child: Column(
                            children: [
                              Text(
                                'Ernest Chemists Limited',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _shimmerController,
                                builder: (context, _) {
                                  return Container(
                                    width: 120,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      gradient: LinearGradient(
                                        begin: Alignment(
                                          -1 + 2 * _shimmerController.value,
                                          0,
                                        ),
                                        end: Alignment(
                                          _shimmerController.value,
                                          0,
                                        ),
                                        colors: [
                                          Colors.white.withValues(alpha: 0.1),
                                          Colors.white.withValues(alpha: 0.85),
                                          Colors.white.withValues(alpha: 0.1),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _exitController,
                builder: (context, _) {
                  if (_exitFade.value <= 0) return const SizedBox.shrink();
                  return Container(
                    color: Colors.white.withValues(alpha: _exitFade.value),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
