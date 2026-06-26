import 'dart:async';

import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:eclapp/services/native_notification_service.dart';
import 'package:eclapp/widgets/onboarding/onboarding_intro_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_permissions_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_safety_slide.dart';
import 'package:eclapp/widgets/onboarding/onboarding_ui.dart';
import 'package:eclapp/widgets/onboarding/onboarding_welcome_slide.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_error_utils.dart';
import '../utils/home_tour_gate.dart';

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
  bool _isCompletingOnboarding = false;
  bool _finishOnboardingInProgress = false;

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

  void _handleContinueTap() {
    unawaited(_onContinue());
  }

  Future<void> _onContinue() async {
    try {
      if (_currentPage == _permissionsPageIndex) {
        if (!mounted) return;
        try {
          final result =
              await NativeNotificationService.requestOnboardingPermissions(
            context: context,
          );
          if (result.notifications) {
            await NativeNotificationService.setPushNotificationsOptIn(true);
          }
        } catch (e, st) {
          debugPrint('Onboarding: permission request error: $e\n$st');
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
    if (_finishOnboardingInProgress) return;
    _finishOnboardingInProgress = true;
    if (mounted) setState(() => _isCompletingOnboarding = true);

    try {
      final ready = await HomePreloadService.ensureOnboardingReadyForHome(
        maxWait: const Duration(seconds: 90),
      );
      debugPrint('Onboarding: API + section images ready=$ready');
    } finally {
      if (mounted) setState(() => _isCompletingOnboarding = false);
    }
    if (!mounted) return;

    HomeTourGate.arm();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasLaunchedBefore', true);
      await prefs.setBool('just_finished_onboarding', true);
      await prefs.setBool('has_shown_welcome_message', true);
      await prefs.setBool('request_permissions_after_onboarding', true);
    } catch (e, st) {
      debugPrint('Onboarding: persist flags error: $e\n$st');
    }

    if (!mounted) return;
    HomePreloadService.markPermissionsRequestedAfterOnboarding();
    widget.onFinish();
  }

  Future<void> _onSkip() async {
    await _completeOnboarding();
  }

  Widget _buildProgressDots({bool light = false}) {
    return OnboardingProgressDots(
      count: _pageCount,
      current: _currentPage,
      light: light,
    );
  }

  bool get _skipUsesLightStyle => _currentPage == 0;

  @override
  Widget build(BuildContext context) {
    final dots = _buildProgressDots();
    final showSkip = _currentPage != _welcomePageIndex;
    final topInset = MediaQuery.paddingOf(context).top;
    final busy = _isCompletingOnboarding;

    return Scaffold(
      backgroundColor: OnboardingUi.surface,
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: [
              OnboardingIntroSlide(
                progressDots: dots,
                onContinue: _handleContinueTap,
                isLoading: busy,
              ),
              OnboardingSafetySlide(
                progressDots: dots,
                onContinue: _handleContinueTap,
                isLoading: busy,
              ),
              OnboardingPermissionsSlide(
                isLoading: busy,
                onAllow: _handleContinueTap,
                progressDots: dots,
              ),
              OnboardingWelcomeSlide(
                onGetStarted: _handleContinueTap,
                progressDots: dots,
                isLoading: busy,
              ),
            ],
          ),
          if (showSkip)
            Positioned(
              top: topInset + 4,
              right: 8,
              child: TextButton(
                onPressed: busy ? null : _onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: _skipUsesLightStyle
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
                child: Text(
                  'Skip',
                  style: GoogleFonts.poppins(
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
