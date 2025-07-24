// pages/onboarding_splash_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  bool _videoInitFailed = false;

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

    _videoController =
        VideoPlayerController.asset('assets/images/Mobile browsers.mp4');
    _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
      _videoController!.setLooping(true);
      _videoController!.setVolume(0);
      _videoController!.play();
      setState(() {});
    }).catchError((e) {
      _videoInitFailed = true;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoController?.dispose();
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
      'iconColor': null,
    },
    {
      'icon': Icons.delivery_dining,
      'title': 'Fast Delivery, Anytime',
      'desc':
          'Get your medicines and essentials delivered to your door, fast and reliably.',
      'button': 'Next',
      'iconColor': Colors.green,
    },
    {
      'icon': Icons.shopping_cart,
      'title': 'All Your Health Needs, One App',
      'desc':
          'Order prescriptions, wellness products, and more—all in one place.',
      'button': 'Next',
      'iconColor': Colors.orange,
    },
    {
      'icon': Icons.support_agent,
      'title': 'Speak to a Pharmacist',
      'desc':
          'Chat with a licensed pharmacist about your health concerns, anytime.',
      'button': 'Next',
      'iconColor': Colors.teal,
    },
    {
      'icon': Icons.warning_amber,
      'title': 'Important Safety Information',
      'desc': 'Please read carefully before using our services.',
      'button': 'Next',
      'iconColor': Colors.orange,
    },
    {
      'icon': Icons.verified_user,
      'title': 'Why Sign Up?',
      'desc': '',
      'button': 'Get Started',
      'iconColor': Colors.green,
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
    debugPrint('Onboarding: Skip button pressed');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunchedBefore', true);
    debugPrint('Onboarding: Calling widget.onFinish()');
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image (no padding, outside SafeArea)
          if (_currentPage == 0 ||
              _currentPage == 1 ||
              _currentPage == 3 ||
              _currentPage == 4)
            Positioned.fill(
              child: Opacity(
                opacity: 0.60,
                child: Image.asset(
                  'assets/images/onboarding2.png',
                  fit: BoxFit.cover,
                ),
              ),
            )
          else if (_currentPage == 2)
            Positioned.fill(
              child: Opacity(
                opacity: 0.60,
                child: Image.asset(
                  'assets/images/onboarding3.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          // Gradient overlay for readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Color(0xCCF8F9FA),
                      Color(0xB0E0F2F1),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Foreground content inside SafeArea
          SafeArea(
            child: Stack(
              children: [
                // Main onboarding content
                PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return SingleChildScrollView(
                      key: ValueKey(_currentPage),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 64),
                            // Add semantic label for illustration
                            Semantics(
                              label: _getHeadlineForIndex(index, page),
                              child: _getPlaceholderIconForIndex(index),
                            ),
                            SizedBox(height: 16),
                            // Headline (skip on last page, index 4)
                            if (index != 4) ...[
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _getHeadlineForIndex(index, page),
                                  style: const TextStyle(
                                    fontSize: 28, // increased for accessibility
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            // Subtitle
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                _getSubtitleForIndex(index, page),
                                style: const TextStyle(
                                  fontSize: 18, // increased for accessibility
                                  color: Colors.black87, // improved contrast
                                ),
                                textAlign: TextAlign.center,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Spacer replaced with a SizedBox for scrollable layout
                            // Progress dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _pages.length,
                                (dotIndex) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: _currentPage == dotIndex ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == dotIndex
                                        ? Colors.teal[700] // improved contrast
                                        : Colors.teal[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Animated FloatingActionButton for Next/Get Started
                            Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1.0, end: 1.0),
                                duration: const Duration(milliseconds: 200),
                                builder: (context, scale, child) {
                                  return GestureDetector(
                                    onTapDown: (_) => setState(() {}),
                                    onTapUp: (_) => setState(() {}),
                                    child: AnimatedScale(
                                      scale: 1.0,
                                      duration:
                                          const Duration(milliseconds: 100),
                                      child: Semantics(
                                        button: true,
                                        label: _currentPage == _pages.length - 1
                                            ? 'Get Started'
                                            : 'Next',
                                        child: SizedBox(
                                          width: 220,
                                          height: 52,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal[700],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                              elevation: 2,
                                            ),
                                            onPressed: _onNext,
                                            child: _currentPage ==
                                                    _pages.length - 1
                                                ? Text(
                                                    'Get Started',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Add friendly microcopy on last page
                            if (_currentPage == _pages.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 14.0),
                                child: Text(
                                  "Let's get started on your health journey!",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Skip button at top right (move to end so it's on top)
                Positioned(
                  top: 16,
                  right: 16,
                  child: (_currentPage != _pages.length - 1)
                      ? TextButton(
                          onPressed: _onSkip,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get headline for each page
  String _getHeadlineForIndex(int index, Map<String, dynamic> page) {
    switch (index) {
      case 0:
        return 'Welcome to Enerst Chemists E-Pharmacy!';
      case 1:
        return 'Easy to buy your pharmacy products';
      case 2:
        return 'All your health needs, one app';
      case 3:
        return 'Speak to a pharmacist about your concerns';
      case 4:
        return 'Important Safety Information';
      case 5:
        return 'Why Sign Up?';
      default:
        return page['title'] ?? '';
    }
  }

  // Helper to get subtitle for each page
  String _getSubtitleForIndex(int index, Map<String, dynamic> page) {
    switch (index) {
      case 0:
        return 'Your trusted partner for health and wellness.';
      case 1:
        return 'Browse and buy pharmacy products with a few taps.';
      case 2:
        return 'Prescriptions, wellness, and more—all in one place.';
      case 3:
        return 'Chat with a licensed pharmacist anytime.';
      case 4:
        return 'Please read carefully before using our services.';
      case 5:
        return '';
      default:
        return page['desc'] ?? '';
    }
  }

  // Helper to get placeholder icon/illustration for each page
  Widget _getPlaceholderIconForIndex(int index) {
    switch (index) {
      case 0:
        return Center(
          child: Image.asset(
            'assets/images/png.png',
            height: 120,
            fit: BoxFit.contain,
          ),
        );
      case 1:
        return _videoInitFailed ||
                _videoController == null ||
                !_videoController!.value.isInitialized
            ? SvgPicture.asset(
                'assets/images/Mobile browsers-amico.svg',
                height: 180,
                fit: BoxFit.contain,
              )
            : AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VideoPlayer(_videoController!),
                ),
              );
      case 2:
        return Center(
          child: SvgPicture.asset(
            'assets/images/Add to Cart-bro.svg',
            height: 180,
            fit: BoxFit.contain,
          ),
        );
      case 3:
        return SvgPicture.asset(
          'assets/images/Medical prescription-bro.svg',
          height: 180,
          fit: BoxFit.contain,
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Warning icon
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            // Disclaimer content
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade100,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _disclaimerItem(
                    Icons.warning,
                    'Know Your Allergies',
                    'Always keep in mind any allergies or adverse reactions you\'ve had to medications before purchasing.',
                    Colors.red.shade600,
                  ),
                  SizedBox(height: 12),
                  _disclaimerItem(
                    Icons.medical_services,
                    'Consult Healthcare Providers',
                    'Consult your doctor or pharmacist before starting new medications, especially if you have existing conditions.',
                    Colors.blue.shade600,
                  ),
                  SizedBox(height: 12),
                  _disclaimerItem(
                    Icons.block,
                    'No Drug Abuse',
                    'Medications are for legitimate medical use only. Misuse can be harmful and illegal.',
                    Colors.purple.shade600,
                  ),
                  SizedBox(height: 12),
                  _disclaimerItem(
                    Icons.info_outline,
                    'Read Instructions',
                    'Always read medication labels, instructions, and warnings before use.',
                    Colors.green.shade600,
                  ),
                  SizedBox(height: 12),
                  _disclaimerItem(
                    Icons.storage,
                    'Proper Storage',
                    'Store medications as directed, away from children and pets.',
                    Colors.teal.shade600,
                  ),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Headline on top for 'Why Sign Up?'
            SizedBox(
              width: double.infinity,
              child: Text(
                'Why Sign Up?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
            const SizedBox(height: 8),
            SvgPicture.asset(
              'assets/images/signin.svg',
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _benefitRow(
                    Icons.medical_services, 'Order prescriptions easily',
                    center: true, iconColor: Colors.blue, dense: true),
                _benefitRow(Icons.local_shipping, 'Track your orders',
                    center: true, iconColor: Colors.green, dense: true),
                _benefitRow(Icons.flash_on, 'Faster checkout',
                    center: true, iconColor: Colors.amber, dense: true),
                _benefitRow(Icons.card_giftcard, 'Exclusive offers & rewards',
                    center: true, iconColor: Colors.orange, dense: true),
              ],
            ),
            const SizedBox(height: 10),
            Divider(thickness: 1, height: 24, color: Colors.tealAccent),
            const SizedBox(height: 10),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _benefitRow(IconData icon, String text,
      {bool center = false, Color? iconColor, bool dense = false}) {
    if (center) {
      return Padding(
        padding:
            EdgeInsets.symmetric(vertical: dense ? 4.0 : 8.0, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? Colors.green[700], size: 28),
            SizedBox(height: dense ? 3 : 6),
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

  Widget _disclaimerItem(
      IconData icon, String title, String description, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
