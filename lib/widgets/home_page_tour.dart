import 'dart:async';
import 'package:eclapp/pages/homepage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/home_tour_gate.dart';
import 'spotlight_tour.dart';

/// GlobalKeys for home-screen coach marks — attach to matching widgets.
class HomePageTourTargets {
  HomePageTourTargets({
    required this.searchKey,
    required this.cartKey,
    required this.categoriesKey,
    this.shopKey,
    this.menuKey,
    this.medicationKey,
    this.popularKey,
  });

  final GlobalKey searchKey;
  final GlobalKey cartKey;
  final GlobalKey categoriesKey;
  final GlobalKey? shopKey;
  final GlobalKey? menuKey;
  final GlobalKey? medicationKey;
  final GlobalKey? popularKey;
}

class HomePageTour {
  HomePageTour._();


  static bool _isHomePageContext(BuildContext context) {
    final element = context as Element?;
    if (element is StatefulElement && element.state is HomePageState) {
      return true;
    }
    return context.findAncestorStateOfType<HomePageState>() != null;
  }

  static bool _targetReady(GlobalKey key) {
    final rect = SpotlightTour.targetRect(key);
    return rect != null && rect.width > 8 && rect.height > 8;
  }

  /// Minimum targets to start the tour (search + cart are always on screen).
  static bool _minimumTargetsReady(HomePageTourTargets targets) {
    return _targetReady(targets.searchKey) && _targetReady(targets.cartKey);
  }

  /// Bottom-nav targets live on [MainTabShell]; wait for them before starting.
  static bool _bottomNavTourTargetsReady(HomePageTourTargets targets) {
    if (targets.shopKey != null && !_targetReady(targets.shopKey!)) {
      return false;
    }
    if (targets.menuKey != null && !_targetReady(targets.menuKey!)) {
      return false;
    }
    return true;
  }

  static List<SpotlightStep> _buildSteps(
    HomePageTourTargets targets,
    ScrollController? scrollController,
  ) {
    return [
      SpotlightStep(
        targetKey: targets.searchKey,
        title: 'Search products',
        body: 'Type a medicine or wellness item name to find it quickly.',
        align: SpotlightTooltipAlign.below,
        beforeShow: () => _scrollToTop(scrollController),
      ),
      SpotlightStep(
        targetKey: targets.cartKey,
        title: 'Your cart',
        body: 'See items you\'ve added and continue to checkout from here.',
        align: SpotlightTooltipAlign.below,
        beforeShow: () => _scrollToTop(scrollController),
      ),
      if (_targetReady(targets.categoriesKey))
        SpotlightStep(
          targetKey: targets.categoriesKey,
          title: 'Browse categories',
          body: 'Swipe the chips to explore categories on your home feed.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.categoriesKey,
          ),
        ),
      if (targets.medicationKey != null && _targetReady(targets.medicationKey!))
        SpotlightStep(
          targetKey: targets.medicationKey!,
          title: 'Shop medications',
          body:
              'Browse medicines by section. Tap See More to open the full catalog.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.medicationKey!,
          ),
        ),
      if (targets.popularKey != null && _targetReady(targets.popularKey!))
        SpotlightStep(
          targetKey: targets.popularKey!,
          title: 'Popular right now',
          body: 'See trending products—swipe sideways to browse more picks.',
          align: SpotlightTooltipAlign.below,
          padding: 8,
          beforeShow: () => _scrollTargetIntoView(
            scrollController,
            targets.popularKey!,
          ),
        ),
      if (targets.shopKey != null && _targetReady(targets.shopKey!))
        SpotlightStep(
          targetKey: targets.shopKey!,
          title: 'Shop',
          body: 'Open the full catalog and browse every category in one place.',
          align: SpotlightTooltipAlign.above,
          padding: 6,
          beforeShow: () => _scrollToTop(scrollController),
        ),
      if (targets.menuKey != null && _targetReady(targets.menuKey!))
        SpotlightStep(
          targetKey: targets.menuKey!,
          title: 'Quick actions',
          body: 'Open the menu for pharmacist chat, prescriptions, and more.',
          align: SpotlightTooltipAlign.above,
          beforeShow: () => _scrollToTop(scrollController),
        ),
    ];
  }

  /// Returns true if the overlay was shown.
  static Future<bool> maybeStart({
    required BuildContext context,
    required HomePageTourTargets targets,
    ScrollController? scrollController,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool('has_seen_smart_tips') ?? false)) {
      debugPrint('HomePageTour: skipped — already seen');
      return false;
    }
    if (!(prefs.getBool('hasLaunchedBefore') ?? false)) {
      debugPrint('HomePageTour: skipped — onboarding not finished');
      return false;
    }
    if (!context.mounted) return false;
    if (!_isHomePageContext(context)) {
      debugPrint('HomePageTour: skipped — not on HomePage');
      return false;
    }

    if (force) {
      await prefs.setBool('has_seen_smart_tips', false);
    }

    for (var i = 0; i < 100; i++) {
      if (!context.mounted) return false;
      if (_minimumTargetsReady(targets) &&
          _bottomNavTourTargetsReady(targets)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!_minimumTargetsReady(targets) || !context.mounted) {
      debugPrint('HomePageTour: skipped — search/cart not laid out');
      return false;
    }

    final needsBottomNav = targets.shopKey != null || targets.menuKey != null;
    if (needsBottomNav && !_bottomNavTourTargetsReady(targets)) {
      debugPrint('HomePageTour: skipped — shop/menu not laid out');
      return false;
    }

    if (targets.medicationKey != null || targets.popularKey != null) {
      for (var i = 0; i < 80; i++) {
        if (!context.mounted) return false;
        final medReady = targets.medicationKey == null ||
            _targetReady(targets.medicationKey!);
        final popReady =
            targets.popularKey == null || _targetReady(targets.popularKey!);
        if (medReady && popReady) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    final steps = _buildSteps(targets, scrollController);

    if (steps.isEmpty) return false;

    debugPrint(
      'HomePageTour: showing ${steps.length} step(s) — '
      'categories=${_targetReady(targets.categoriesKey)}, '
      'medication=${targets.medicationKey != null && _targetReady(targets.medicationKey!)}, '
      'popular=${targets.popularKey != null && _targetReady(targets.popularKey!)}, '
      'shop=${targets.shopKey != null && _targetReady(targets.shopKey!)}, '
      'menu=${targets.menuKey != null && _targetReady(targets.menuKey!)}',
    );
    await SpotlightTour.show(
      context: context,
      steps: steps,
      onFinished: () {
        unawaited(prefs.setBool('has_seen_smart_tips', true));
        HomeTourGate.release();
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

  /// Scroll so the target sits in the upper third; tooltip goes below it.
  static Future<void> _scrollTargetIntoView(
    ScrollController? controller,
    GlobalKey targetKey, {
    double viewportFraction = 0.22,
  }) async {
    if (controller == null || !controller.hasClients) return;

    final rect = SpotlightTour.targetRect(targetKey);
    if (rect == null) {
      final fallback = controller.position.maxScrollExtent > 320
          ? 280.0
          : controller.position.maxScrollExtent * 0.35;
      await controller.animateTo(
        fallback,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
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
