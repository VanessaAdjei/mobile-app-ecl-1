// main.dart
import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/providers/auth_provider.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/wallet_page.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'services/optimized_api_service.dart';
import 'services/banner_cache_service.dart';
import 'services/advanced_performance_service.dart';
import 'services/optimized_homepage_service.dart';
import 'services/universal_page_optimization_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/homepage_optimization_service.dart';
import 'services/background_prefetch_service.dart';
import 'pages/onboarding_splash_page.dart';
import 'pages/prescription.dart';
import 'pages/prescription_upload_standalone.dart';
import 'pages/notification_permission_page.dart';
import 'pages/terms_acceptance_page.dart';
import 'pages/clearance_admin_page.dart';
import 'providers/notification_provider.dart';
import 'services/background_order_checker.dart';

import 'services/order_notification_service.dart';
import 'services/native_notification_service.dart';
import 'services/notification_handler_service.dart';
import 'services/health_tips_service.dart';
import 'services/background_cart_sync_service.dart';
import 'services/background_order_tracking_service.dart';
import 'services/background_store_data_service.dart';
import 'services/background_inventory_monitor_service.dart';
import 'providers/wallet_provider.dart';
import 'providers/promotional_event_provider.dart';
import 'providers/clearance_sale_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'services/http_client_service.dart';
import 'config/app_routes.dart';

bool _isKeychainError(dynamic e) {
  final s = e.toString().toLowerCase();
  return s.contains('34018') ||
      s.contains('entitlement') ||
      s.contains('required entitlement') ||
      s.contains('unexpected security result code') ||
      s.contains('security result code');
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (FlutterErrorDetails d) {
      if (d.exception is PlatformException && _isKeychainError(d.exception)) {
        return const SizedBox.shrink();
      }
      if (_isKeychainError(d.exception.toString())) {
        return const SizedBox.shrink();
      }
      return ErrorWidget(d.exception);
    };

    FlutterError.onError = (FlutterErrorDetails d) {
      if (_isKeychainError(d.exception) ||
          d.stack
                  ?.toString()
                  .toLowerCase()
                  .contains('flutter_secure_storage') ==
              true) {
        return;
      }
      FlutterError.presentError(d);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is PlatformException && _isKeychainError(error)) return true;
      if (_isKeychainError(error.toString())) return true;
      return false;
    };

    // set up http client stuff for ssl certificates i think
    await HttpClientService.initialize();

    // make images cache better so they load faster
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

    await _initializeApp();
    runApp(const MyApp());
  }, (error, stack) {
    if (_isKeychainError(error)) return;
    debugPrint('Unhandled error: $error');
    debugPrint('Stack: $stack');
  });
}

Future<void> _initializeApp() async {
  debugPrint('🚀 Main: Cold start - optimized for fast onboarding');

  await AuthService.clearAllGuestIds();

  // do the important stuff first and wait for it to finish
  debugPrint('🚀 Main: Starting critical service initialization...');
  final criticalStartTime = DateTime.now();

  // only do the bare minimum so onboarding shows up fast
  await Future.wait([
    BannerCacheService().initialize(),
  ]).timeout(
      const Duration(milliseconds: 500)); // Very fast timeout for onboarding

  final criticalInitTime = DateTime.now().difference(criticalStartTime);
  debugPrint(
      '🚀 Main: Critical services initialized in ${criticalInitTime.inMilliseconds}ms');

  // do other stuff in background, dont wait for it
  unawaited(_initBackground());

  debugPrint('Prefetch...');
  final prefetchStartTime = DateTime.now();

  try {
    await Future.wait([
      BannerCacheService().getBanners(),
      // dont fetch popular products here, do it later in background
    ]).timeout(
        const Duration(milliseconds: 300)); // Very fast timeout for onboarding
  } catch (e) {
    if (e is TimeoutException) {
      debugPrint('⚠️ Main: took too long, just continue anyway');
    } else {
      debugPrint('❌ Main: Error in essential data prefetching: $e');
    }
  }

  final prefetchTime = DateTime.now().difference(prefetchStartTime);
  debugPrint(
      '🚀 Main: Essential data prefetched in ${prefetchTime.inMilliseconds}ms');

  debugPrint('🚀 Main: Cold start completed');
}

Future<void> _initBackground() async {
  debugPrint('🚀 Main: Starting non-critical service initialization...');
  final startTime = DateTime.now();

  await Future.wait([
    OptimizedApiService().initialize(),
    AdvancedPerformanceService().initialize(),
    OptimizedHomepageService().initialize(),
    UniversalPageOptimizationService().initialize(),
    BackgroundPrefetchService().initialize(),
  ]);

  final initTime = DateTime.now().difference(startTime);
  debugPrint(
      '🚀 Main: Non-critical services initialized in ${initTime.inMilliseconds}ms');

  // get some data ready in the background
  unawaited(HomepageOptimizationService()
      .getPopularProductsUltraFast()); // use the super fast method
  unawaited(HomepageOptimizationService().getCategorizedProducts());
  unawaited(OptimizedHomepageService().getProducts());
  unawaited(BackgroundPrefetchService().smartPrefetch());

  // set up auth stuff
  unawaited(AuthService.init().catchError((e) {
    debugPrint('Background auth initialization error: $e');
  }));

  BackgroundOrderChecker.startPeriodicChecking();
  HealthTipsService.startBackgroundService();
  BackgroundCartSyncService.startBackgroundSync();
  BackgroundOrderTrackingService.startBackgroundTracking();
  BackgroundStoreDataService.startBackgroundPreloading();
  BackgroundInventoryMonitorService.startBackgroundMonitoring();

  await Future.wait([
    OrderNotificationService.initializeNotifications(),
    NativeNotificationService.initialize(),
  ]);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _isFirstLaunch;
  bool? _termsAccepted;
  bool _isLoggedIn = false;
  String? _pendingNotificationPayload;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // do initialization stuff at the same time to make it faster
    _initializeAppState();
  }

  // set up app state, do multiple things at once
  Future<void> _initializeAppState() async {
    debugPrint('🚀 Main: Starting app state initialization...');
    final startTime = DateTime.now();

    // do the important checks first (wait for them)
    await _checkFirstLaunch();
    await _checkTermsAcceptance();

    // do the less important checks at the same time (dont wait)
    unawaited(_checkAuthStatus());
    unawaited(_handleNotificationPayload());

    final initTime = DateTime.now().difference(startTime);
    debugPrint(
        '🚀 Main: App state initialized in ${initTime.inMilliseconds}ms');
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();

    // check if this is the first time opening the app
    final appInstallDate = prefs.getString('app_install_date');
    final currentDate = DateTime.now().toIso8601String();

    if (appInstallDate == null) {
      // first time opening, set the date and show onboarding
      await prefs.setString('app_install_date', currentDate);
      if (!mounted) return;
      setState(() {
        _isFirstLaunch = true;
      });
      debugPrint('🚀 Main: Fresh install detected - showing onboarding');
    } else {
      // check if they uninstalled and reinstalled the app
      // if the install date is really old (over 30 days), treat it as a fresh install
      try {
        final installDate = DateTime.parse(appInstallDate);
        final daysSinceInstall = DateTime.now().difference(installDate).inDays;

        if (daysSinceInstall > 30) {
          // probably uninstalled and reinstalled, show onboarding again
          await prefs.setString('app_install_date', currentDate);
          if (!mounted) return;
          setState(() {
            _isFirstLaunch = true;
          });
          debugPrint(
              '🚀 Main: App reinstall detected (${daysSinceInstall} days old) - showing onboarding');
        } else {
          // normal launch, skip onboarding
          if (!mounted) return;
          setState(() {
            _isFirstLaunch = false;
          });
          debugPrint('🚀 Main: Normal app launch - skipping onboarding');
        }
      } catch (e) {
        // if we cant parse the date, just treat it as a fresh install
        await prefs.setString('app_install_date', currentDate);
        if (!mounted) return;
        setState(() {
          _isFirstLaunch = true;
        });
        debugPrint('🚀 Main: Date parsing error - treating as fresh install');
      }
    }
  }

  Future<void> _checkTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final termsAccepted = prefs.getBool('terms_accepted') ?? false;

    if (!mounted) return;
    setState(() {
      _termsAccepted = termsAccepted;
    });

    if (termsAccepted) {
      debugPrint('🚀 Main: Terms already accepted');
    } else {
      debugPrint('🚀 Main: Terms not accepted yet - will show acceptance page');
    }
  }

  // reset onboarding state (for testing)
  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_install_date');
    setState(() {
      _isFirstLaunch = true;
    });
    debugPrint('🚀 Main: Onboarding reset manually for testing');
  }

  // check if the app was installed recently (within 24 hours)
  Future<bool> _isRecentlyInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appInstallDate = prefs.getString('app_install_date');

      if (appInstallDate == null) return true;

      final installDate = DateTime.parse(appInstallDate);
      final hoursSinceInstall = DateTime.now().difference(installDate).inHours;

      return hoursSinceInstall < 24;
    } catch (e) {
      return true; // If there's an error, treat as recently installed
    }
  }

  // public method to reset onboarding (for testing, can call from ui)
  void resetOnboardingForTesting() {
    _resetOnboarding();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  // handle notification data when they open the app from a notification
  Future<void> _handleNotificationPayload() async {
    try {
      debugPrint('📱 Main: Checking for notification payload...');
      final payload = await NativeNotificationService.getNotificationPayload();

      if (payload != null && payload.isNotEmpty) {
        debugPrint('📱 Main: Found notification payload: $payload');

        _pendingNotificationPayload = payload;
      } else {
        debugPrint('📱 Main: No notification payload found');
      }
    } catch (e) {
      debugPrint('📱 Main: Error checking notification payload: $e');
    }
  }

  Future<Map<String, dynamic>> _getPrescriptionData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPendingPrescription =
        prefs.getBool('has_pending_prescription') ?? false;

    debugPrint(
        '🔍 Main: Checking for pending prescription: $hasPendingPrescription');

    if (hasPendingPrescription) {
      // get the prescription data we saved
      final productName = prefs.getString('pending_prescription_product') ?? '';
      final thumbnail = prefs.getString('pending_prescription_thumbnail') ?? '';
      final productId = prefs.getString('pending_prescription_id') ?? '';
      final price = prefs.getString('pending_prescription_price') ?? '';
      final batchNo = prefs.getString('pending_prescription_batch_no') ?? '';

      debugPrint('🔍 Main: Retrieved prescription data:');
      debugPrint('🔍 Main: Product Name: $productName');
      debugPrint('🔍 Main: Product ID: $productId');
      debugPrint('🔍 Main: Price: $price');
      debugPrint('🔍 Main: Batch No: $batchNo');

      // clear the flag so we dont do this again
      await prefs.setBool('has_pending_prescription', false);

      return {
        'token': await AuthService.getToken() ?? '',
        'item': {
          'product': {
            'name': productName,
            'thumbnail': thumbnail,
            'id': productId,
          },
          'price': price,
          'batch_no': batchNo,
        },
      };
    }

    debugPrint('🔍 Main: No pending prescription found, returning empty data');

    // if theres no pending prescription, return empty data
    return {
      'token': '',
      'item': {
        'product': {
          'name': '',
          'thumbnail': '',
          'id': '',
        },
        'price': '',
        'batch_no': '',
      },
    };
  }

  void _refreshAuthState() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _clearRestartFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_was_running', false);
    debugPrint('🚀 Main: App lifecycle: App killed, restart flag cleared');
  }

  @override
  Widget build(BuildContext context) {
    // if we're still loading, show loading screen or go to onboarding
    if (_isFirstLaunch == null || _termsAccepted == null) {
      // show a simple loading screen or just go straight to onboarding
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // show the app logo
                Image(
                  image: AssetImage('assets/images/png.png'),
                  width: 120,
                  height: 120,
                ),
                SizedBox(height: 20),
                // spinning loading circle
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final notificationProvider = NotificationProvider();
            notificationProvider.initialize();

            OrderNotificationService.setBadgeUpdateCallback((count) {
              notificationProvider.updateBadgeCount(count);
              // also check if its a new order notification
              notificationProvider.notifyNewOrderNotification();
            });

            return notificationProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider();
            authProvider.initialize();
            return authProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final walletProvider = WalletProvider();
            walletProvider.initialize();
            return walletProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final promotionalProvider = PromotionalEventProvider();
            promotionalProvider.initialize();
            return promotionalProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final clearanceProvider = ClearanceSaleProvider();
            clearanceProvider.initialize();
            return clearanceProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return AuthState(
            isLoggedIn: _isLoggedIn,
            refreshAuthState: _refreshAuthState,
            child: MaterialApp(
              title: 'ECL App',
              debugShowCheckedModeBanner: false,
              // hide keychain errors here too
              builder: (context, widget) {
                // Wrap widget to catch and suppress errors
                return widget ?? const SizedBox.shrink();
              },
              themeMode:
                  themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(
                fontFamily: 'Poppins',
                brightness: Brightness.light,
                primaryColor: Colors.green.shade700,
                secondaryHeaderColor: Colors.green.shade400,
                scaffoldBackgroundColor: Color(0xFFF8F9FA),
                cardColor: Colors.white,
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.green.shade700,
                  elevation: 2,
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Colors.white),
                  titleTextStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                  labelStyle: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w500),
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    elevation: 2,
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                colorScheme: ColorScheme.fromSwatch(
                  primarySwatch: Colors.green,
                  brightness: Brightness.light,
                ).copyWith(surface: Color(0xFFF8F9FA)),
              ),
              darkTheme: ThemeData(
                fontFamily: 'Poppins',
                brightness: Brightness.dark,
                primaryColor: Colors.green.shade400,
                secondaryHeaderColor: Colors.green.shade200,
                scaffoldBackgroundColor: Colors.grey.shade900,
                cardColor: Colors.grey.shade800,
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.green.shade400,
                  elevation: 2,
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Colors.white),
                  titleTextStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.green.shade400, width: 2),
                  ),
                  labelStyle: TextStyle(
                      color: Colors.green.shade200,
                      fontWeight: FontWeight.w500),
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    elevation: 2,
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade200,
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                colorScheme: ColorScheme.fromSwatch(
                  primarySwatch: Colors.green,
                  brightness: Brightness.dark,
                ).copyWith(surface: Colors.grey.shade900),
              ),
              navigatorKey: NativeNotificationService.globalNavigatorKey,
              scaffoldMessengerKey: NotificationService.messengerKey,
              home: _termsAccepted == false
                  ? _TermsWrapper(
                      onAccepted: () {
                        setState(() {
                          _termsAccepted = true;
                        });
                      },
                    )
                  : _isFirstLaunch == true
                      ? OnboardingSplashPage(
                          onFinish: () async {
                            if (!mounted) return;
                            setState(() {
                              _isFirstLaunch = false;
                            });

                            // Show notification permission request after onboarding
                            // Use Future.microtask to defer to next event loop tick
                            Future.microtask(() {
                              if (!mounted) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _showNotificationPermissionIfNeeded();
                              });
                            });
                          },
                        )
                      : const HomePage(),
              onGenerateRoute: (settings) =>
                  AppRouteGenerator.generate(settings) ??
                  MaterialPageRoute(
                    builder: (_) => const HomePage(),
                  ),
              routes: {
                '/clearance-admin': (context) => const ClearanceAdminPage(),
                '/prescription-upload': (context) =>
                    const PrescriptionUploadStandalone(),
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handlePendingNotification();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // check for notifications when they come back to the app
      _handlePendingNotification();
      _checkForNotificationPayload();
    } else if (state == AppLifecycleState.detached) {
      // app is closing, clear the restart flag
      _clearRestartFlag();
    }
  }

  /// Handle pending notification payload after app is fully loaded
  void _handlePendingNotification() {
    // Check both local and native pending notifications
    final localPayload = _pendingNotificationPayload;
    final nativePayload = NativeNotificationService.pendingNotificationPayload;

    final payload = localPayload ?? nativePayload;

    if (payload != null) {
      debugPrint('📱 Main: Handling pending notification payload');

      // wait for the app to finish building before handling it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('📱 Main: Processing notification payload: $payload');

          // handle the notification data
          NotificationHandlerService.handleNotificationPayload(
            context,
            payload,
          );

          // clear all the pending notification data
          _pendingNotificationPayload = null;
          NativeNotificationService.clearPendingNotificationPayload();
        }
      });
    }
  }

  /// Show notification permission request if needed
  Future<void> _showNotificationPermissionIfNeeded() async {
    try {
      if (!mounted) return;

      final permission = Permission.notification;
      final status = await permission.status;

      if (!mounted) return;

      // only show if we dont have permission and they havent permanently denied it
      if (!status.isGranted && !status.isPermanentlyDenied) {
        final context =
            NativeNotificationService.globalNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NotificationPermissionPage(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error showing notification permission: $e');
    }
  }

  /// Check for notification payload when app is resumed
  Future<void> _checkForNotificationPayload() async {
    try {
      debugPrint('📱 Main: Checking for notification payload on resume...');
      final payload = await NativeNotificationService.getNotificationPayload();

      if (payload != null && payload.isNotEmpty) {
        debugPrint('📱 Main: Found notification payload on resume: $payload');
        _pendingNotificationPayload = payload;
        _handlePendingNotification();
      }
    } catch (e) {
      debugPrint('📱 Main: Error checking notification payload on resume: $e');
    }
  }
}

class ProtectedRoute extends StatelessWidget {
  final Widget child;

  const ProtectedRoute({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final authState = AuthState.of(context);

    // try to get the auth provider first
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isInitialized) {
        if (authProvider.isLoggedIn) {
          return child;
        } else {
          return SignInScreen(
            returnTo: ModalRoute.of(context)?.settings.name,
          );
        }
      }
    } catch (e) {
      // auth provider not available, use auth state instead
    }

    if (authState == null) {
      return FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          if (!snapshot.hasData || !snapshot.data!) {
            return SignInScreen(
              returnTo: ModalRoute.of(context)?.settings.name,
            );
          }

          return child;
        },
      );
    }

    if (!authState.isLoggedIn) {
      return SignInScreen(
        returnTo: ModalRoute.of(context)?.settings.name,
      );
    }

    return child;
  }
}

// Wrapper widget for terms acceptance
class _TermsWrapper extends StatefulWidget {
  final VoidCallback onAccepted;

  const _TermsWrapper({required this.onAccepted});

  @override
  State<_TermsWrapper> createState() => _TermsWrapperState();
}

class _TermsWrapperState extends State<_TermsWrapper> {
  @override
  Widget build(BuildContext context) {
    return TermsAcceptancePage();
  }

  @override
  void initState() {
    super.initState();
    // Listen for when terms are accepted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAcceptance();
    });
  }

  void _checkForAcceptance() async {
    // Wait a bit and check if terms were accepted
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('terms_accepted') ?? false;

    if (accepted && mounted) {
      widget.onAccepted();
    } else {
      // Check again after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkForAcceptance();
      });
    }
  }
}

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userAddress => _userAddress;

  void setUserData({
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userAddress,
  }) {
    _userId = userId;
    _userName = userName;
    _userEmail = userEmail;
    _userPhone = userPhone;
    _userAddress = userAddress;
    notifyListeners();
  }

  void clearUserData() {
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    _userAddress = null;
    notifyListeners();
  }
}

class AuthState extends InheritedWidget {
  static AuthState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthState>();
  }

  final bool isLoggedIn;
  final VoidCallback refreshAuthState;

  const AuthState({
    required this.isLoggedIn,
    required this.refreshAuthState,
    required super.child,
    super.key,
  });

  @override
  bool updateShouldNotify(AuthState oldWidget) {
    return isLoggedIn != oldWidget.isLoggedIn;
  }
}
