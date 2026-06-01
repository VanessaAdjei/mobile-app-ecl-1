// pages/onboarding_splash_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:eclapp/services/native_notification_service.dart';
import 'package:eclapp/widgets/onboarding/onboarding_permissions_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_welcome_slide.dart';
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
  bool _isRequestingPermissions = false;

  static const int _permissionsPageIndex = 5;
  static const int _welcomePageIndex = 6;

  late AnimationController _animController;
  VideoPlayerController? _videoController;
  bool _videoInitFailed = false;

  bool _isCompletingOnboarding = false;

  @override
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();

    try {
      _videoController =
          VideoPlayerController.asset('assets/images/mobile_browsers.mp4');
      _videoController!.initialize().then((_) {
        if (mounted) {
          _videoController!.setLooping(true);
          _videoController!.setVolume(0);
          _videoController!.play();
          setState(() {});
        }
      }).catchError((e) {
        debugPrint('Video initialization error: $e');
        if (mounted) {
          _videoInitFailed = true;
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('Video controller creation error: $e');
      if (mounted) {
        _videoInitFailed = true;
        setState(() {});
      }
    }
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
      'iconColor': AppColors.primary, // Base green
    },
    {
      'icon': Icons.delivery_dining,
      'title': 'Fast Delivery, Anytime',
      'desc':
          'Get your medicines and essentials delivered to your door, fast and reliably.',
      'button': 'Next',
      'iconColor': const Color(0xFF1A8F55), // Darker green
    },
    {
      'icon': Icons.shopping_cart,
      'title': 'All Your Health Needs, One App',
      'desc':
          'Order prescriptions, wellness products, and more—all in one place.',
      'button': 'Next',
      'iconColor': const Color(0xFF4BCF8F), // Lighter green
    },
    {
      'icon': Icons.support_agent,
      'title': 'Speak to a Pharmacist',
      'desc':
          'Chat with a licensed pharmacist about your health concerns, anytime.',
      'button': 'Next',
      'iconColor': const Color(0xFF159A5F), // Dark green
    },
    {
      'icon': Icons.warning_amber,
      'title': 'Important Safety Information',
      'desc': 'Please read carefully before using our services.',
      'button': 'Next',
      'iconColor': Colors.amber.shade700,
    },
    {
      'icon': Icons.notifications_active_outlined,
      'title': 'Permissions',
      'desc': '',
      'button': 'Continue',
      'iconColor': AppColors.primary,
      'isPermissions': true,
    },
    {
      'icon': Icons.favorite_outline,
      'title': 'Welcome',
      'desc': '',
      'button': 'Get Started',
      'iconColor': AppColors.primary,
      'isWelcome': true,
    },
  ];

  Future<void> _requestOnboardingPermissions() async {
    if (!mounted) return;
    try {
      await NativeNotificationService.requestOnboardingPermissions(
        context: context,
      ).timeout(const Duration(seconds: 45));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_prompt_attempted', true);
    } on TimeoutException {
      debugPrint('Onboarding: permission request timed out');
    } catch (e, st) {
      debugPrint('Onboarding: permission request error: $e\n$st');
    }
  }

  void _handleContinueTap() {
    unawaited(_onNextImpl());
  }

  Future<void> _completeOnboarding() async {
    if (mounted) setState(() => _isCompletingOnboarding = true);
    var catalogReady = false;
    try {
      catalogReady = await HomePreloadService.ensureReadyForHome(
        maxWait: const Duration(seconds: 25),
      );
    } finally {
      if (mounted) setState(() => _isCompletingOnboarding = false);
    }
    if (!mounted) return;
    if (!catalogReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load products. Check your connection and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunchedBefore', true);
    await prefs.setBool('just_finished_onboarding', true);
    await prefs.setBool('has_shown_welcome_message', true);
    if (!mounted) return;
    widget.onFinish();
  }

  Future<void> _onNextImpl() async {
    try {
      if (_currentPage == _permissionsPageIndex) {
        setState(() => _isRequestingPermissions = true);
        try {
          await _requestOnboardingPermissions();
        } finally {
          if (mounted) setState(() => _isRequestingPermissions = false);
        }
        if (!mounted) return;
        if (_controller.hasClients) {
          await _controller.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
        return;
      }

      if (_currentPage == _welcomePageIndex) {
        await _completeOnboarding();
        return;
      }

      if (_controller.hasClients) {
        await _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } catch (e, st) {
      debugPrint('Onboarding continue error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not continue. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onSkip() async {
    debugPrint('Onboarding: Skip button pressed');
    if (mounted) setState(() => _isCompletingOnboarding = true);
    var catalogReady = false;
    try {
      catalogReady = await HomePreloadService.ensureReadyForHome(
        maxWait: const Duration(seconds: 25),
      );
    } finally {
      if (mounted) setState(() => _isCompletingOnboarding = false);
    }
    if (!mounted) return;
    if (!catalogReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load products. Check your connection and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunchedBefore', true);
    await prefs.setBool('just_finished_onboarding', true);
    await prefs.setBool('has_shown_welcome_message', true);
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
          if (_currentPage == _permissionsPageIndex ||
              _currentPage == _welcomePageIndex)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      AppColors.primary.withValues(alpha: 0.06),
                      const Color(0xFF0D9488).withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            )
          else if (_currentPage == 0 ||
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
                    final isPermissions = index == _permissionsPageIndex;
                    final isWelcome = index == _welcomePageIndex;

                    if (isPermissions) {
                      return SingleChildScrollView(
                        key: const ValueKey('permissions_slide'),
                        child: Column(
                          children: [
                            OnboardingPermissionsSlide(
                              isLoading: _isRequestingPermissions,
                              onAllow: _handleContinueTap,
                            ),
                            _buildProgressDots(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    }

                    if (isWelcome) {
                      return OnboardingWelcomeSlide(
                        key: const ValueKey('welcome_slide'),
                        onGetStarted: _handleContinueTap,
                        progressDots: _buildProgressDots(),
                        isLoading: _isCompletingOnboarding,
                      );
                    }

                    return SingleChildScrollView(
                      key: ValueKey(_currentPage),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 64),
                            Semantics(
                              label: _getHeadlineForIndex(index, page),
                              child: _getPlaceholderIconForIndex(index),
                            ),
                            const SizedBox(height: 16),
                            if (index != 4) ...[
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _getHeadlineForIndex(index, page),
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
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                _getSubtitleForIndex(index, page),
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildProgressDots(),
                            const SizedBox(height: 18),
                            Center(
                              child: SizedBox(
                                width: 220,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _isRequestingPermissions
                                      ? null
                                      : _handleContinueTap,
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
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
                  child: TextButton(
                    onPressed: _isCompletingOnboarding ? null : _onSkip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
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
        return 'All your health needs, One app';
      case 3:
        return 'Speak to a pharmacist about your concerns';
      case 4:
        return 'Important Safety Information';
      case 5:
        return 'Permissions';
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Image.asset(
                'assets/images/png.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 36),
          ],
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
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 20),
            // Disclaimer content
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade100,
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
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressDots() {
    return Row(
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
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _disclaimerItem(
      IconData icon, String title, String description, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 12),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
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
