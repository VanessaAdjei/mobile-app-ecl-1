// widgets/clearance_sale_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/clearance_sale_provider.dart';
import '../pages/clearance_homepage.dart';

class ClearanceSaleBanner extends StatefulWidget {
  const ClearanceSaleBanner({super.key});

  @override
  State<ClearanceSaleBanner> createState() => _ClearanceSaleBannerState();
}

class _ClearanceSaleBannerState extends State<ClearanceSaleBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClearanceSaleProvider>(
      builder: (context, clearanceProvider, child) {
        if (!clearanceProvider.isActive) {
          return const SizedBox.shrink();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 140,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: GestureDetector(
                    onTap: _navigateToClearancePage,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background image
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/sale.png'),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: Colors.black.withOpacity(0.3),
                                ),
                                child: CustomPaint(
                                  painter: BannerPatternPainter(),
                                ),
                              ),
                            ),
                          ),

                          // Animated sparkles with better positioning
                          ...List.generate(12, (index) {
                            return Positioned(
                              left: (index * 35.0) % 320,
                              top: (index * 25.0) % 120,
                              child: Animate(
                                effects: [
                                  FadeEffect(
                                      duration: Duration(
                                          milliseconds: 1500 + (index * 200)),
                                      delay:
                                          Duration(milliseconds: index * 300)),
                                  ScaleEffect(
                                      duration: Duration(milliseconds: 2000),
                                      curve: Curves.easeInOut,
                                      begin: const Offset(0.3, 0.3),
                                      end: const Offset(1.0, 1.0)),
                                ],
                                child: Icon(
                                  Icons.star,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 8 + (index % 4) * 2,
                                ),
                              ),
                            );
                          }),

                          // Main content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Center content with enhanced typography
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Sale name with new styling
                                      Text(
                                        '🔥 UP TO ${clearanceProvider.discountPercentage.toInt()}% OFF',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                          shadows: [
                                            Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                              offset: Offset(3, 3),
                                              blurRadius: 6,
                                            ),
                                            Shadow(
                                              color:
                                                  Colors.white.withOpacity(0.3),
                                              offset: Offset(-1, -1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Limited Time Only!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.4),
                                              offset: Offset(2, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'SHOP NOW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.8,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  offset: Offset(1, 1),
                                                  blurRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Animate(
                                            effects: const [
                                              SlideEffect(
                                                  duration: Duration(
                                                      milliseconds: 1200),
                                                  curve: Curves.easeInOut,
                                                  begin: Offset(0, 0),
                                                  end: Offset(8, 0)),
                                            ],
                                            child: const Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Right side - Enhanced discount badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.8),
                                        blurRadius: 8,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'SAVE',
                                        style: TextStyle(
                                          color: const Color(0xFFFF6B6B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${clearanceProvider.discountPercentage.toInt()}%',
                                        style: TextStyle(
                                          color: const Color(0xFFFF6B6B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black12,
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'OFF',
                                        style: TextStyle(
                                          color: const Color(0xFFFF8E53),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    .animate(
                                        onPlay: (controller) =>
                                            controller.repeat())
                                    .scale(
                                        begin: const Offset(1.0, 1.0),
                                        end: const Offset(1.08, 1.08),
                                        duration: 1800.ms)
                                    .then()
                                    .scale(
                                        begin: const Offset(1.08, 1.08),
                                        end: const Offset(1.0, 1.0),
                                        duration: 1800.ms),
                              ],
                            ),
                          ),

                          // Enhanced tap indicator
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'TAP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _navigateToClearancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ClearanceHomePage(),
      ),
    );
  }
}

class BannerPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw decorative circles
    for (int i = 0; i < 8; i++) {
      final x = (i * 60.0) % size.width;
      final y = (i * 40.0) % size.height;
      final radius = 15.0 + (i % 3) * 5.0;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }

    // Draw diagonal lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final startY = i * (size.height / 4);
      canvas.drawLine(
        Offset(0, startY),
        Offset(size.width, startY + size.height / 4),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
