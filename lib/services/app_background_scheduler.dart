import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'advanced_performance_service.dart';
import 'auth_service.dart';
import 'background_inventory_monitor_service.dart';
import 'background_order_checker.dart';
import 'background_order_tracking_service.dart';
import 'background_prefetch_service.dart';
import 'background_store_data_service.dart';
import 'health_tips_service.dart';
import 'home_preload_service.dart';
import 'homepage_optimization_service.dart';
import 'native_notification_service.dart';
import 'optimized_api_service.dart';
import 'optimized_homepage_service.dart';
import 'order_notification_service.dart';
import 'realtime_cart_sync_service.dart';
import 'universal_page_optimization_service.dart';

/// Coordinates non-critical background work so startup and idle periods stay fast.
///
/// Goals:
/// - Stagger timers/API prefetch instead of firing everything at cold start.
/// - Cart server sync: [RealtimeCartSyncService] (started from [CartProvider]).
/// - Pause low-priority work while the app is in the background.
class AppBackgroundScheduler {
  AppBackgroundScheduler._();

  static bool _started = false;
  static bool _paused = false;
  static final List<Timer> _timers = [];

  static bool get isPaused => _paused;

  /// Called once from [main] after the first frame path is ready.
  static Future<void> startDeferred() async {
    if (_started) return;
    _started = true;

    debugPrint('⏱️ AppBackgroundScheduler: starting deferred background work');

    try {
      await Future.wait([
        OptimizedApiService().initialize(),
        AdvancedPerformanceService().initialize(),
        OptimizedHomepageService().initialize(),
        UniversalPageOptimizationService().initialize(),
        BackgroundPrefetchService().initialize(),
      ]).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint(
          '⏱️ AppBackgroundScheduler: light init timed out, continuing');
    } catch (e) {
      debugPrint('⏱️ AppBackgroundScheduler: light init error: $e');
    }

    unawaited(AuthService.init().catchError((Object e) {
      debugPrint('⏱️ AppBackgroundScheduler: auth init error: $e');
    }));

    // Notifications: needed early but not blocking UI paint.
    unawaited(() async {
      try {
        await Future.wait([
          OrderNotificationService.initializeNotifications(),
          NativeNotificationService.initialize(),
        ]);
      } catch (e) {
        debugPrint('⏱️ AppBackgroundScheduler: notification init error: $e');
      }
    }());

    // Homepage data — skip if onboarding preload already filled ProductCache.
    _schedule(const Duration(seconds: 6), () {
      if (_paused) return;
      if (HomePreloadService.isCatalogReady) {
        HomePreloadService.publishCatalogToHomeServices();
        return;
      }
      unawaited(
        HomepageOptimizationService().getPopularProductsUltraFast(),
      );
    });

    // Categories — lower priority (~20s).
    _schedule(const Duration(seconds: 20), () {
      if (_paused) return;
      if (HomePreloadService.isCatalogReady) return;
      unawaited(HomepageOptimizationService().getCategorizedProducts());
    });

    // Generic prefetch cache — lowest priority (~35s).
    _schedule(const Duration(seconds: 35), () {
      if (_paused) return;
      unawaited(BackgroundPrefetchService().smartPrefetch());
    });

    // Order + cart polling — after home has had time to load (~12s).
    _schedule(const Duration(seconds: 12), () {
      if (_paused) return;
      BackgroundOrderChecker.startPeriodicChecking();
      BackgroundOrderTrackingService.startBackgroundTracking();
      unawaited(RealtimeCartSyncService.checkNow());
    });

    // Store/inventory/tips — defer heavy/low-value work (~60s).
    _schedule(const Duration(seconds: 60), () {
      if (_paused) return;
      HealthTipsService.startBackgroundService();
      BackgroundStoreDataService.startBackgroundPreloading();
      BackgroundInventoryMonitorService.startBackgroundMonitoring();
    });
  }

  static void onAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _paused = false;
        unawaited(BackgroundOrderChecker.checkNow());
        unawaited(RealtimeCartSyncService.checkNow());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _paused = true;
        break;
    }
  }

  static void _schedule(Duration delay, VoidCallback action) {
    _timers.add(Timer(delay, action));
  }

  /// For tests or logout flows that need a clean slate.
  static void resetForTesting() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _started = false;
    _paused = false;
  }
}
