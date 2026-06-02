import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:eclapp/services/native_notification_service.dart';
import 'package:eclapp/widgets/onboarding/onboarding_intro_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_permissions_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_safety_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_welcome_slide.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_error_utils.dart';

/// Streamlined first-run onboarding: intro → safety → permissions → welcome.
class OnboardingSplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingSplashPage({required this.onFinish, super.key});

  @override
  State<OnboardingSplashPage> createState() => _OnboardingSplashPageState();
}

class _OnboardingSplashPageState extends State<OnboardingSplashPage> {
  static const int _pageCount = 4;
  static const int _permissionsPageIndex = 2;
  static const int _welcomePageIndex = 3;

  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isRequestingPermissions = false;
  bool _isCompletingOnboarding = false;

  @override
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

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
    unawaited(_onContinue());
  }

  Future<void> _onContinue() async {
    try {
      if (_currentPage == _permissionsPageIndex) {
        setState(() => _isRequestingPermissions = true);
        try {
          await _requestOnboardingPermissions();
        } finally {
          if (mounted) setState(() => _isRequestingPermissions = false);
        }
        if (!mounted) return;
        await _goToPage(_welcomePageIndex);
        return;
      }

      if (_currentPage == _welcomePageIndex) {
        await _completeOnboarding();
        return;
      }

      if (_controller.hasClients) {
        await _controller.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e, st) {
      debugPrint('Onboarding continue error: $e\n$st');
      if (mounted) {
        AppErrorUtils.showSnack(
          context,
          'Could not continue. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _goToPage(int index) async {
    if (!_controller.hasClients) return;
    await _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (!HomePreloadService.isFullyReadyForHome && mounted) {
      setState(() => _isCompletingOnboarding = true);
    }
    var catalogReady = false;
    try {
      catalogReady = await HomePreloadService.ensureReadyForHome(
        maxWait: const Duration(seconds: 30),
      );
    } finally {
      if (mounted) setState(() => _isCompletingOnboarding = false);
    }
    if (!mounted) return;
    if (!catalogReady) {
      AppErrorUtils.showSnack(
        context,
        'Could not load products. Check your connection and try again.',
        isError: true,
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

  Future<void> _onSkip() async {
    if (!HomePreloadService.isFullyReadyForHome && mounted) {
      setState(() => _isCompletingOnboarding = true);
    }
    var catalogReady = false;
    try {
      catalogReady = await HomePreloadService.ensureReadyForHome(
        maxWait: const Duration(seconds: 30),
      );
    } finally {
      if (mounted) setState(() => _isCompletingOnboarding = false);
    }
    if (!mounted) return;
    if (!catalogReady) {
      AppErrorUtils.showSnack(
        context,
        'Check your connection and try again.',
        isError: true,
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunchedBefore', true);
    await prefs.setBool('just_finished_onboarding', true);
    await prefs.setBool('has_shown_welcome_message', true);
    widget.onFinish();
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pageCount,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == i ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: _currentPage == i
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dots = _buildProgressDots();
    final showSkip = _currentPage != _welcomePageIndex;
    final topInset = MediaQuery.paddingOf(context).top;
    final skipOnIntro = _currentPage == 0;
    final useSoftBackground =
        _currentPage == _permissionsPageIndex || _currentPage == _welcomePageIndex;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (useSoftBackground)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            top: _currentPage == 1 || _currentPage == 2,
            child: Column(
              children: [
                if (showSkip && !skipOnIntro)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: TextButton(
                        onPressed:
                            _isCompletingOnboarding ? null : _onSkip,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      OnboardingIntroSlide(
                        progressDots: dots,
                        onContinue: _handleContinueTap,
                        isLoading: _isCompletingOnboarding,
                      ),
                      OnboardingSafetySlide(
                        progressDots: dots,
                        onContinue: _handleContinueTap,
                        isLoading: _isCompletingOnboarding,
                      ),
                      Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: OnboardingPermissionsSlide(
                                isLoading: _isRequestingPermissions,
                                onAllow: _handleContinueTap,
                              ),
                            ),
                          ),
                          dots,
                          const SizedBox(height: 24),
                        ],
                      ),
                      OnboardingWelcomeSlide(
                        onGetStarted: _handleContinueTap,
                        progressDots: dots,
                        isLoading: _isCompletingOnboarding,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showSkip && skipOnIntro)
            Positioned(
              top: topInset + 4,
              right: 8,
              child: TextButton(
                onPressed: _isCompletingOnboarding ? null : _onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
