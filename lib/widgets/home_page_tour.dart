import 'dart:async';

import 'package:eclapp/pages/homepage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spotlight_tour.dart';

/// GlobalKeys for home-screen coach marks — attach to matching widgets.
class HomePageTourTargets {
  HomePageTourTargets({
    required this.searchKey,
    required this.cartKey,
    required this.categoriesKey,
    this.menuKey,
  });

  final GlobalKey searchKey;
  final GlobalKey cartKey;
  final GlobalKey categoriesKey;
  final GlobalKey? menuKey;
}

class HomePageTour {
  HomePageTour._();

  /// [HomePageState]'s own [BuildContext] is not an *ancestor* of [HomePage],
  /// so we must accept the state's element directly.
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

    for (var i = 0; i < 80; i++) {
      if (!context.mounted) return false;
      if (_minimumTargetsReady(targets)) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!_minimumTargetsReady(targets) || !context.mounted) {
      debugPrint('HomePageTour: skipped — search/cart not laid out');
      return false;
    }

    final steps = <SpotlightStep>[
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
          body:
              'Swipe the chips to explore departments. Tap Shop → See all for the full catalog.',
          align: SpotlightTooltipAlign.below,
          padding: 6,
          beforeShow: () => _scrollCategoriesIntoView(
            scrollController,
            targets.categoriesKey,
          ),
        ),
      if (targets.menuKey != null && _targetReady(targets.menuKey!))
        SpotlightStep(
          targetKey: targets.menuKey!,
          title: 'Quick actions',
          body:
              'Open the menu for pharmacist chat, prescriptions, and more.',
          align: SpotlightTooltipAlign.above,
          beforeShow: () => _scrollToTop(scrollController),
        ),
    ];

    if (steps.isEmpty) return false;

    debugPrint('HomePageTour: showing ${steps.length} step(s)');
    await SpotlightTour.show(
      context: context,
      steps: steps,
      onFinished: () {
        unawaited(prefs.setBool('has_seen_smart_tips', true));
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

  /// Scroll so category chips sit in the upper third; tooltip goes below them.
  static Future<void> _scrollCategoriesIntoView(
    ScrollController? controller,
    GlobalKey categoriesKey,
  ) async {
    if (controller == null || !controller.hasClients) return;

    final rect = SpotlightTour.targetRect(categoriesKey);
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
    final targetTop = viewportHeight * 0.22;
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
