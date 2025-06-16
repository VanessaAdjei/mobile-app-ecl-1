// pages/loggedout.dart
import 'package:eclapp/pages/homepage.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoggedOutScreen extends StatelessWidget {
  const LoggedOutScreen({super.key});
  Future<void> _ensureLoggedOut() async {
    await AuthService.logout();
    print("Cleared auth state for guest browsing");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Background gradient and pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, const Color(0xFFE8F5E9)],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // App logo with hero animation
                  Hero(
                    tag: 'appLogo',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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

                  const SizedBox(height: 30),

                  // Welcome text with animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'Welcome to ECLAPP',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Start your shopping experience',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),


                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: ElevatedButton(
                      onPressed: () async {
                        await _ensureLoggedOut();

                        // Navigate to home page as a non-logged in user
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



                  const SizedBox(height: 20),

                  // Features section
                  Expanded(
                    child: _buildFeaturesSection(context),
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
    // List of features with icons, titles and descriptions
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
              // Calculate a staggered animation delay for each item
              final delay = Duration(milliseconds: 200 * index);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
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

  Widget _buildFeatureCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.1),
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