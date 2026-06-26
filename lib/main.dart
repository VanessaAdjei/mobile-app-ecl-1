// main.dart
import 'dart:io' show Platform;

import 'package:eclapp/services/auth_service.dart';
import 'package:eclapp/providers/auth_provider.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:eclapp/cache/product_cache.dart';
import 'package:eclapp/utils/catalog_timer.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/main_tab_shell.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/profile_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/banner_cache_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/brand_launch_splash_page.dart';
import 'pages/onboarding_splash_page.dart';
import 'pages/prescription_upload_standalone.dart';
import 'pages/terms_acceptance_page.dart';
import 'pages/clearance_admin_page.dart';
import 'providers/notification_provider.dart';
import 'services/app_background_scheduler.dart';
import 'services/home_preload_service.dart';
import 'services/product_image_preload_service.dart';
import 'services/order_notification_service.dart';
import 'services/native_notification_service.dart';
import 'services/notification_handler_service.dart';
import 'providers/wallet_provider.dart';
import 'providers/promotional_event_provider.dart';
import 'providers/clearance_sale_provider.dart';
import 'services/notification_service.dart';
import 'services/http_client_service.dart';
import 'config/api_config.dart';
import 'config/app_colors.dart';
import 'config/app_routes.dart';
import 'utils/responsive_utils.dart';
import 'utils/non_ui_error_reporter.dart';
import 'utils/flutter_test_env.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

bool _isKeychainError(dynamic e) {
  final s = e.toString().toLowerCase();
  return s.contains('34018') ||
      s.contains('entitlement') ||
      s.contains('required entitlement') ||
      s.contains('unexpected security result code') ||
      s.contains('security result code');
}

/// flutter_typeahead v4 metrics race when leaving a screen with search focused.
bool _isTypeaheadDeactivatedMetricsError(Object error, StackTrace? stack) {
  final message = error.toString();
  if (!message.contains('deactivated widget') &&
      !message.contains('ancestor is unsafe')) {
    return false;
  }
  final trace = stack?.toString() ?? '';
  return trace.contains('flutter_typeahead') &&
      (trace.contains('SuggestionsBox._waitChangeMetrics') ||
          trace.contains('didChangeMetrics'));
}

/// Shown in debug/profile when a widget fails to build. Same details as the red
/// [ErrorWidget], but readable, scrollable, and copy-friendly (also logged via
/// [FlutterError.onError] → [NonUiErrorReporter]).
Widget _buildPhaseErrorPanel(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  final stack = details.stack?.toString() ?? '';
  return Material(
    color: const Color(0xFF18181B),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.orange.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Build failed',
                    style: TextStyle(
                      color: Colors.grey.shade100,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              '$message\n\n$stack',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _configureAndroidImagePicker() {
  if (kIsWeb || !Platform.isAndroid) return;
  final impl = ImagePickerPlatform.instance;
  if (impl is ImagePickerAndroid) {
    impl.useAndroidPhotoPicker = true;
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _configureAndroidImagePicker();

    ErrorWidget.builder = (FlutterErrorDetails d) {
      if (d.exception is PlatformException && _isKeychainError(d.exception)) {
        return const SizedBox.shrink();
      }
      if (_isKeychainError(d.exception.toString())) {
        return const SizedBox.shrink();
      }
      // In debug/profile, keep Flutter's default error widget so failures are obvious.
      // In release, avoid flashing the technical error UI; still report for diagnostics.
      if (kReleaseMode) {
        NonUiErrorReporter.report(
          'ErrorWidget.builder',
          d.exception,
          d.stack,
        );
        return const Material(
          color: Color(0xFFF4F4F5),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Something went wrong loading this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF52525B),
                ),
              ),
            ),
          ),
        );
      }
      // Debug / profile: avoid default red [ErrorWidget]; same info, easier to read and copy.
      // (Already reported in [FlutterError.onError].)
      return _buildPhaseErrorPanel(d);
    };

    FlutterError.onError = (FlutterErrorDetails d) {
      if (_isKeychainError(d.exception) ||
          d.stack
                  ?.toString()
                  .toLowerCase()
                  .contains('flutter_secure_storage') ==
              true ||
          _isTypeaheadDeactivatedMetricsError(
            d.exception,
            d.stack,
          )) {
        return;
      }
      NonUiErrorReporter.report(
        'FlutterError.onError',
        d.exception,
        d.stack,
      );
      // In debug/profile, [presentError] adds a second red fullscreen layer on top of
      // [ErrorWidget]. Console dump + our [ErrorWidget.builder] panel is enough.
      if (kReleaseMode) {
        FlutterError.presentError(d);
      } else {
        FlutterError.dumpErrorToConsole(d);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is PlatformException && _isKeychainError(error)) return true;
      if (_isKeychainError(error.toString())) return true;
      return false;
    };

    // Prefs + routing in parallel with HTTP/catalog so runApp is not blocked twice.
    final launchFlagsFuture = resolveAppLaunchFlags();

    // Start disk catalog read immediately (no HTTP) so warm launches beat network.
    CatalogTimer.mark('app_open');
    unawaited(ProductCache.loadFromStorage());

    // HTTP/maps are not needed to choose the first screen — init after first frame.
    if (!isFlutterTest) {
      unawaited(HttpClientService.initialize());
      unawaited(ApiConfig.initializeMapsApiKey());

      // Full catalog download as soon as HTTP is ready (not on Get Started).
      unawaited(ProductCache.prefetchPriorityFromNetwork());
      unawaited(ProductCache.prefetchFromNetwork());
      debugPrint('🚀 Main: priority + get-all-products started at app open');
    }

    // make images cache better so they load faster
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

    unawaited(_initializeApp());

    // First Flutter frame immediately — no white logo screen while prefs load.
    runApp(EclAppRoot(flagsFuture: launchFlagsFuture));
  }, (error, stack) {
    if (_isKeychainError(error)) return;
    if (_isTypeaheadDeactivatedMetricsError(error, stack)) return;
    debugPrint('Unhandled error: $error');
    debugPrint('Stack: $stack');
  });
}

Future<void> _initializeApp() async {
  if (isFlutterTest) return;

  debugPrint('🚀 Main: Cold start - deferred (non-blocking for first frame)');

  unawaited(_ensureGuestIdForAnonymousSession());
  unawaited(BannerCacheService().initialize());
  unawaited(_warmCatalogFromDisk());
  unawaited(_initBackground());
  unawaited(BannerCacheService().getBanners());

  debugPrint('🚀 Main: Cold start work scheduled');
}

/// Keeps the same [guest_id] across app restarts for users who never sign in.
Future<void> _ensureGuestIdForAnonymousSession() async {
  if (await AuthService.isLoggedIn()) return;
  try {
    await AuthService.generateGuestId();
  } catch (e) {
    debugPrint('🚀 Main: guest_id ensure failed: $e');
  }
}

/// Launch routing flags read once before [runApp] so the white bootstrap screen is skipped.
class AppLaunchFlags {
  const AppLaunchFlags({
    required this.isFirstLaunch,
    required this.termsAccepted,
    required this.hasSeenBrandSplash,
  });

  final bool isFirstLaunch;
  final bool termsAccepted;
  final bool hasSeenBrandSplash;
}

Future<AppLaunchFlags> resolveAppLaunchFlags() async {
  final prefs = await SharedPreferences.getInstance();
  final currentDate = DateTime.now().toIso8601String();
  final appInstallDate = prefs.getString('app_install_date');

  bool isFirstLaunch;
  if (appInstallDate == null) {
    unawaited(prefs.setString('app_install_date', currentDate));
    isFirstLaunch = true;
    debugPrint('🚀 Main: Fresh install detected - showing onboarding');
  } else {
    try {
      final installDate = DateTime.parse(appInstallDate);
      final daysSinceInstall = DateTime.now().difference(installDate).inDays;
      if (daysSinceInstall > 30) {
        unawaited(prefs.setString('app_install_date', currentDate));
        isFirstLaunch = true;
        debugPrint(
          '🚀 Main: App reinstall detected ($daysSinceInstall days old) - showing onboarding',
        );
      } else {
        isFirstLaunch = false;
        debugPrint('🚀 Main: Normal app launch - skipping onboarding');
      }
    } catch (e) {
      unawaited(prefs.setString('app_install_date', currentDate));
      isFirstLaunch = true;
      debugPrint('🚀 Main: Date parsing error - treating as fresh install');
    }
  }

  final termsAccepted = prefs.getBool('terms_accepted') ?? false;
  final hasSeenBrandSplash =
      prefs.getBool('has_seen_brand_launch_splash') ?? false;

  if (termsAccepted) {
    debugPrint('🚀 Main: Terms already accepted');
  } else {
    debugPrint('🚀 Main: Terms not accepted yet - will show acceptance page');
  }

  return AppLaunchFlags(
    isFirstLaunch: isFirstLaunch,
    termsAccepted: termsAccepted,
    hasSeenBrandSplash: hasSeenBrandSplash,
  );
}

Future<void> _warmCatalogFromDisk() async {
  try {
    await ProductCache.loadFromStorage();
    CatalogTimer.mark('disk_loaded');
    if (ProductCache.hasProductsInMemory) {
      ProductCache.warmPopularFromCatalog();
      HomePreloadService.publishCatalogToHomeServices();
      unawaited(
        ProductImagePreloadService.warmPriorityHomeImages(
          catalog: ProductCache.cachedProducts,
          maxWait: const Duration(seconds: 12),
          maxConcurrent: 8,
        ),
      );
      debugPrint(
        'Main: catalog ready from disk (${ProductCache.catalogProductCount} products)',
      );
    } else if (ProductCache.hasPriorityProducts) {
      unawaited(
        ProductImagePreloadService.warmPriorityHomeImages(
          catalog: ProductCache.cachedPriorityProducts,
          maxWait: const Duration(seconds: 10),
          maxConcurrent: 8,
        ),
      );
    }
  } catch (e) {
    debugPrint('Main: catalog disk load error: $e');
  }
}

Future<void> _initBackground() async {
  await AppBackgroundScheduler.startDeferred();
}

/// Shows a plain brand-colored placeholder until [resolveAppLaunchFlags] completes.
class EclAppRoot extends StatefulWidget {
  const EclAppRoot({super.key, required this.flagsFuture});

  final Future<AppLaunchFlags> flagsFuture;

  @override
  State<EclAppRoot> createState() => _EclAppRootState();
}

class _EclAppRootState extends State<EclAppRoot> {
  AppLaunchFlags? _flags;

  @override
  void initState() {
    super.initState();
    widget.flagsFuture.then((flags) {
      if (mounted) setState(() => _flags = flags);
    });
  }

  @override
  Widget build(BuildContext context) {
    final flags = _flags;
    if (flags == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: Color(0xFF1B5E32),
          child: SizedBox.expand(),
        ),
      );
    }
    return MyApp(launchFlags: flags);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.launchFlags});

  final AppLaunchFlags launchFlags;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _isFirstLaunch;
  late bool _termsAccepted;
  late bool _hasSeenBrandSplash;
  bool _isLoggedIn = false;
  String? _pendingNotificationPayload;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isFirstLaunch = widget.launchFlags.isFirstLaunch;
    _termsAccepted = widget.launchFlags.termsAccepted;
    _hasSeenBrandSplash = widget.launchFlags.hasSeenBrandSplash;

    HomePreloadService.startOnboardingPreload();
    unawaited(_checkAuthStatus());
    unawaited(_handleNotificationPayload());
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ProfileSettingsProvider()),
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
              title: 'Ernest Chemists Ltd',
              debugShowCheckedModeBanner: false,
              // hide keychain errors here too; tablet/desktop: centered max-width column
              builder: (context, widget) {
                final framed = ResponsiveUtils.appFrame(
                  context,
                  widget ?? const SizedBox.shrink(),
                );
                return ResponsiveUtils.applyResponsiveTheme(context, framed);
              },
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                fontFamily: 'Poppins',
                brightness: Brightness.light,
                primaryColor: Colors.green.shade700,
                secondaryHeaderColor: Colors.green.shade400,
                scaffoldBackgroundColor: Color(0xFFF8F9FA),
                cardColor: Colors.white,
                snackBarTheme: const SnackBarThemeData(
                  behavior: SnackBarBehavior.floating,
                  dismissDirection: DismissDirection.down,
                  showCloseIcon: true,
                ),
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
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    return Colors.white;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return Colors.grey.shade600;
                  }),
                ),
              ),
              darkTheme: ThemeData(
                fontFamily: 'Poppins',
                brightness: Brightness.dark,
                primaryColor: Colors.green.shade700,
                secondaryHeaderColor: Colors.green.shade400,
                scaffoldBackgroundColor: const Color(0xFF0F172A),
                cardColor: const Color(0xFF1E293B),
                snackBarTheme: const SnackBarThemeData(
                  behavior: SnackBarBehavior.floating,
                  dismissDirection: DismissDirection.down,
                  showCloseIcon: true,
                ),
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
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade600),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.green.shade500, width: 2),
                  ),
                  labelStyle: TextStyle(
                      color: Colors.green.shade300,
                      fontWeight: FontWeight.w500),
                  hintStyle:
                      TextStyle(color: Colors.white54, fontSize: 15),
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
                ).copyWith(
                  surface: const Color(0xFF0F172A),
                  onSurface: Colors.white,
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.white),
                  bodyMedium: TextStyle(color: Colors.white70),
                  titleMedium: TextStyle(color: Colors.white),
                  titleSmall: TextStyle(color: Colors.white),
                  labelLarge: TextStyle(color: Colors.white),
                ),
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    return Colors.white;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return const Color(0xFF475569);
                  }),
                ),
              ),
              navigatorKey: NativeNotificationService.globalNavigatorKey,
              scaffoldMessengerKey: NotificationService.messengerKey,
              home: _termsAccepted == false
                  ? (_hasSeenBrandSplash == false
                      ? BrandLaunchSplashPage(
                          onComplete: () {
                            if (!mounted) return;
                            setState(() => _hasSeenBrandSplash = true);
                          },
                        )
                      : _TermsWrapper(
                          onAccepted: () {
                            setState(() => _termsAccepted = true);
                          },
                        ))
                  : _isFirstLaunch == true
                      ? OnboardingSplashPage(
                          onFinish: () {
                            if (!mounted) return;
                            setState(() => _isFirstLaunch = false);
                          },
                        )
                      : const MainTabShell(),
              onGenerateRoute: (settings) =>
                  AppRouteGenerator.generate(settings) ??
                  MaterialPageRoute(
                    builder: (_) => const MainTabShell(),
                  ),
              routes: {
                '/clearance-admin': (context) => const ClearanceAdminPage(),
                '/prescription-upload': (context) =>
                    const PrescriptionUploadStandalone(),
                '/signin': (context) => const SignInScreen(),
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
    AppBackgroundScheduler.onAppLifecycleState(state);
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
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();
  }

  @override
  Widget build(BuildContext context) {
    return TermsAcceptancePage(onAccepted: widget.onAccepted);
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
