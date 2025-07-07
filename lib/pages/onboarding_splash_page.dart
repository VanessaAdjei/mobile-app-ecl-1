// pages/onboarding_splash_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add a custom clipper for the green curve at the top level
class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class OnboardingSplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingSplashPage({required this.onFinish, super.key});

  @override
  State<OnboardingSplashPage> createState() => _OnboardingSplashPageState();
}

class _OnboardingSplashPageState extends State<OnboardingSplashPage>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;

  late AnimationController _animController;
  Animation<double>? _iconScaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScaleAnim =
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _animController.reset();
    _animController.forward();
  }

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.local_pharmacy,
      'title': 'Welcome to Enerst Chemists',
      'desc': 'Your trusted pharmacy for health, wellness, and convenience.',
      'button': 'Continue',
    },
    {
      'icon': Icons.delivery_dining,
      'title': 'Fast Delivery, Anytime',
      'desc':
          'Get your medicines and essentials delivered to your door, fast and reliably.',
      'button': 'Next',
    },
    {
      'icon': Icons.shopping_cart,
      'title': 'All Your Health Needs, One App',
      'desc':
          'Order prescriptions, wellness products, and more—all in one place.',
      'button': 'Next',
    },
    {
      'icon': Icons.verified_user,
      'title': 'Why Sign Up?',
      'desc': '',
      'button': 'Get Started',
    },
  ];

  void _onNext() async {
    if (_currentPage == _pages.length - 1) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasLaunchedBefore', true);
      widget.onFinish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunchedBefore', true);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF43E97B), Color(0xFFd3f9e5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (index == 0) ...[
                        Image.asset(
                          'assets/images/png.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Welcome to Enerst Chemists E-Pharmacy!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your trusted partner for health and wellness.',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (index == 1) ...[
                        Icon(
                          Icons.local_shipping,
                          size: 100,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page['title'],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page['desc'],
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (index == 2) ...[
                        Icon(
                          Icons.shopping_cart,
                          size: 100,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page['title'],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page['desc'],
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 100,
                              color: Colors.green[700],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Why Sign Up?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            // Centered bulleted list of benefits
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _benefitRow(Icons.medical_services,
                                    'Order prescriptions easily',
                                    center: true, iconColor: Colors.blue),
                                _benefitRow(
                                    Icons.local_shipping, 'Track your orders',
                                    center: true, iconColor: Colors.green),
                                _benefitRow(
                                    Icons.location_on, 'Save your addresses',
                                    center: true, iconColor: Colors.purple),
                                _benefitRow(Icons.flash_on, 'Faster checkout',
                                    center: true, iconColor: Colors.amber),
                                _benefitRow(Icons.card_giftcard,
                                    'Exclusive offers & rewards',
                                    center: true, iconColor: Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 48),
                      // Progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (dotIndex) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == dotIndex ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == dotIndex
                                  ? Colors.green[700]
                                  : Colors.green[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage != 0)
                            TextButton(
                              onPressed: _onSkip,
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 64),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ElevatedButton(
                                onPressed: _onNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  shape: const StadiumBorder(),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  _currentPage == _pages.length - 1
                                      ? 'Get Started'
                                      : _pages[_currentPage]['button']!,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text,
      {bool center = false, Color? iconColor}) {
    if (center) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? Colors.green[700], size: 28),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? Colors.green[700], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      );
    }
  }
}
