import 'dart:async';

import 'package:eclapp/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spotlight_tour.dart';

/// SharedPreferences key — profile tab coach marks seen once.
const String kProfileTourSeenKey = 'has_seen_profile_tour';

class ProfilePageTourTargets {
  ProfilePageTourTargets({
    required this.headerKey,
    required this.accountKey,
    required this.healthKey,
    required this.supportKey,
    this.preferencesKey,
  });

  final GlobalKey headerKey;
  final GlobalKey accountKey;
  final GlobalKey healthKey;
  final GlobalKey supportKey;
  final GlobalKey? preferencesKey;
}

class ProfilePageTour {
  ProfilePageTour._();

  static bool _isProfileContext(BuildContext context) {
    final element = context as Element?;
    if (element is StatefulElement && element.state is ProfileState) {
      return true;
    }
    return context.findAncestorStateOfType<ProfileState>() != null;
  }

  static bool _targetReady(GlobalKey key) {
    final rect = SpotlightTour.targetRect(key);
    return rect != null && rect.width > 8 && rect.height > 8;
  }

  static List<SpotlightStep> _buildSteps(
    ProfilePageTourTargets targets,
    ScrollController? scrollController,
  ) {
    return [
      SpotlightStep(
        targetKey: targets.headerKey,
        title: 'Your profile',
        body: _targetReady(targets.headerKey)
            ? 'See who is signed in here. Guests can tap Sign in to unlock account features.'
            : 'Manage your account from this screen.',
        align: SpotlightTooltipAlign.below,
        padding: 6,
        beforeShow: () => _scrollToTop(scrollController),
      ),
      if (targets.preferencesKey != null &&
          _targetReady(targets.preferencesKey!))
        SpotlightStep(
          targetKey: targets.preferencesKey!,
          title: 'Preferences',
          body: 'Switch dark mode on or off to match how you like to shop.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollToTop(scrollController),
        ),
      if (_targetReady(targets.accountKey))
        SpotlightStep(
          targetKey: targets.accountKey,
          title: 'Account',
          body:
              'Open profile details, notifications, wishlist, and wallet from here.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.accountKey,
          ),
        ),
      if (_targetReady(targets.healthKey))
        SpotlightStep(
          targetKey: targets.healthKey,
          title: 'Health & orders',
          body:
              'Prescriptions, appointments, refills, and purchase history live in this section.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.healthKey,
          ),
        ),
      if (_targetReady(targets.supportKey))
        SpotlightStep(
          targetKey: targets.supportKey,
          title: 'Support & account actions',
          body:
              'Find policies and help here. Sign in or log out is at the bottom when you need it.',
          align: SpotlightTooltipAlign.above,
          padding: 8,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.supportKey,
            viewportFraction: 0.52,
          ),
        ),
    ];
  }

  /// Returns true if the overlay was shown.
  static Future<bool> maybeStart({
    required BuildContext context,
    required ProfilePageTourTargets targets,
    ScrollController? scrollController,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(kProfileTourSeenKey) ?? false)) {
      debugPrint('ProfilePageTour: skipped — already seen');
      return false;
    }
    if (!(prefs.getBool('hasLaunchedBefore') ?? false)) {
      debugPrint('ProfilePageTour: skipped — onboarding not finished');
      return false;
    }
    if (!context.mounted) return false;
    if (!_isProfileContext(context)) {
      debugPrint('ProfilePageTour: skipped — not on Profile tab');
      return false;
    }

    if (force) {
      await prefs.setBool(kProfileTourSeenKey, false);
    }

    for (var i = 0; i < 80; i++) {
      if (!context.mounted) return false;
      if (_targetReady(targets.headerKey) && _targetReady(targets.accountKey)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!_targetReady(targets.headerKey) || !context.mounted) {
      debugPrint('ProfilePageTour: skipped — header not laid out');
      return false;
    }

    for (var i = 0; i < 80; i++) {
      if (!context.mounted) return false;
      if (_targetReady(targets.healthKey) && _targetReady(targets.supportKey)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final steps = _buildSteps(targets, scrollController);
    if (steps.isEmpty) return false;

    debugPrint('ProfilePageTour: showing ${steps.length} step(s)');
    await SpotlightTour.show(
      context: context,
      steps: steps,
      onFinished: () {
        unawaited(prefs.setBool(kProfileTourSeenKey, true));
      },
    );
    return true;
  }

  static Future<void> _scrollToTop(ScrollController? controller) async {
    if (controller == null || !controller.hasClients) return;
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  static Future<void> _scrollTargetIntoView(
    ScrollController? controller,
    GlobalKey targetKey, {
    double viewportFraction = 0.2,
  }) async {
    if (controller == null || !controller.hasClients) return;

    final rect = SpotlightTour.targetRect(targetKey);
    if (rect == null) {
      await controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return;
    }

    final viewportHeight = controller.position.viewportDimension;
    final targetTop = viewportHeight * viewportFraction;
    final delta = rect.top - targetTop;
    if (delta.abs() < 8) return;

    final newOffset = (controller.offset + delta)
        .clamp(0.0, controller.position.maxScrollExtent);
    await controller.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
