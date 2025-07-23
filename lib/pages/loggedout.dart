// pages/loggedout.dart
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoggedOutScreen extends StatefulWidget {
  const LoggedOutScreen({super.key});

  @override
  State<LoggedOutScreen> createState() => _LoggedOutScreenState();
}

class _LoggedOutScreenState extends State<LoggedOutScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;
  late AnimationController _featuresController;
  late AnimationController _signInController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textSlide;
  late Animation<double> _buttonSlide;
  late Animation<double> _featuresSlide;
  late Animation<double> _signInFade;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers with faster durations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _featuresController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _signInController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Define animations with simpler curves
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoRotation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _buttonSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );

    _featuresSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _featuresController, curve: Curves.easeOut),
    );

    _signInFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _signInController, curve: Curves.easeIn),
    );

    // Start animations in sequence with shorter delays
    _startAnimations();
  }

  void _startAnimations() async {
    await _logoController.forward();
    await _textController.forward();
    await _buttonController.forward();
    await _featuresController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _signInController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    _featuresController.dispose();
    _signInController.dispose();
    super.dispose();
  }

  Future<void> _ensureLoggedOut() async {
    await AuthService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        const Color(0xFFE8F5E9)
                            .withValues(alpha: _logoController.value),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Animated app logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        child: Transform.rotate(
                          angle: _logoRotation.value,
                          child: Hero(
                            tag: 'appLogo',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 
                                        0.05 * _logoController.value),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/png.png',
                                height: 80,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Animated welcome text
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Opacity(
                          opacity: _textController.value,
                          child: Column(
                            children: [
                              Text(
                                'Welcome to ECLAPP',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Start your shopping experience',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Animated start shopping button
                  AnimatedBuilder(
                    animation: _buttonController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _buttonSlide.value),
                        child: Opacity(
                          opacity: _buttonController.value,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _ensureLoggedOut();
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HomePage(),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF43A047),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Start Shopping',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Animated sign in link
                  AnimatedBuilder(
                    animation: _signInController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _signInFade.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _signInFade.value)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already a user? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignInScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF43A047),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Animated features section
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _featuresController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _featuresSlide.value),
                          child: Opacity(
                            opacity: _featuresController.value,
                            child: _buildFeaturesSection(context),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'Free Delivery',
        'subtitle': 'Orders Over GHS120',
        'color': const Color(0xFF43A047),
      },
      {
        'icon': Icons.replay_outlined,
        'title': 'Easy Returns',
        'subtitle': 'Within 30 Days',
        'color': const Color(0xFF1E88E5),
      },
      {
        'icon': Icons.lock_outline,
        'title': 'Secure Payment',
        'subtitle': '100% Protected Checkout',
        'color': const Color(0xFFE53935),
      },
      {
        'icon': Icons.headset_mic_outlined,
        'title': '24/7 Support',
        'subtitle': 'Dedicated Customer Service',
        'color': const Color(0xFFFFB300),
      },
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 200 + (index * 50)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _buildFeatureCard(
                    features[index]['icon'] as IconData,
                    features[index]['title'] as String,
                    features[index]['subtitle'] as String,
                    features[index]['color'] as Color,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
