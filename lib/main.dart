// main.dart
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/authprovider.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:provider/provider.dart';
import 'pages/cartprovider.dart';
import 'pages/theme_provider.dart';
import 'services/app_optimization_service.dart';
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
import 'pages/notification_provider.dart';
import 'services/background_order_checker.dart';

import 'services/order_notification_service.dart';
import 'services/native_notification_service.dart';
import 'services/notification_handler_service.dart';
import 'services/health_tips_service.dart';
import 'services/background_cart_sync_service.dart';
import 'services/background_order_tracking_service.dart';
import 'services/background_store_data_service.dart';
import 'services/background_inventory_monitor_service.dart';
import 'dart:async';

void main() async {
  final appStartTime = DateTime.now();
  debugPrint('🚀 Main: App starting at ${appStartTime.toIso8601String()}');

  WidgetsFlutterBinding.ensureInitialized();

  // Configure image cache for better performance
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // Check if this is a restart (faster path)
  final prefs = await SharedPreferences.getInstance();
  final isRestart = prefs.getBool('app_was_running') ?? false;

  if (isRestart) {
    debugPrint('🚀 Main: App restart detected, using optimized path');
    // For restarts, skip some initialization
    await _fastRestart();
  } else {
    debugPrint('🚀 Main: Cold start detected, full initialization');
    await _coldStart();
  }

  // Mark app as running
  await prefs.setBool('app_was_running', true);

  final totalStartupTime = DateTime.now().difference(appStartTime);
  debugPrint(
      '🚀 Main: Total startup time: ${totalStartupTime.inMilliseconds}ms');

  runApp(const MyApp());
}

// Fast restart path for when app was recently running
Future<void> _fastRestart() async {
  debugPrint('🚀 Main: Fast restart - minimal initialization');

  // Only initialize essential services
  await BannerCacheService().initialize();

  // Start everything else in background
  unawaited(_initializeNonCriticalServices());
  unawaited(_startBackgroundServices());

  debugPrint('🚀 Main: Fast restart completed');
}

// Full cold start path for first launch
Future<void> _coldStart() async {
  debugPrint('🚀 Main: Cold start - full initialization');

  await AuthService.clearAllGuestIds();

  // Initialize critical services first (blocking)
  debugPrint('🚀 Main: Starting critical service initialization...');
  final criticalStartTime = DateTime.now();

  await Future.wait([
    AppOptimizationService().initialize(),
    BannerCacheService().initialize(),
  ]);

  final criticalInitTime = DateTime.now().difference(criticalStartTime);
  debugPrint(
      '🚀 Main: Critical services initialized in ${criticalInitTime.inMilliseconds}ms');

  // Start non-critical services in background (non-blocking)
  unawaited(_initializeNonCriticalServices());

  // Prefetch only essential data (blocking with aggressive timeout)
  debugPrint('🚀 Main: Starting essential data prefetching...');
  final prefetchStartTime = DateTime.now();

  try {
    await Future.wait([
      BannerCacheService().getBanners(),
      HomepageOptimizationService().getPopularProducts(),
    ]).timeout(const Duration(
        milliseconds: 1000)); // Reduced to 1 second for faster startup
  } catch (e) {
    if (e is TimeoutException) {
      debugPrint(
          '⚠️ Main: Essential data prefetching timed out, continuing with app startup');
    } else {
      debugPrint('❌ Main: Error in essential data prefetching: $e');
    }
  }

  final prefetchTime = DateTime.now().difference(prefetchStartTime);
  debugPrint(
      '🚀 Main: Essential data prefetched in ${prefetchTime.inMilliseconds}ms');

  // Start background services immediately (non-blocking)
  unawaited(_startBackgroundServices());

  debugPrint('🚀 Main: Cold start completed');
}

// Initialize non-critical services in background
Future<void> _initializeNonCriticalServices() async {
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

  // Start non-critical data prefetching
  unawaited(HomepageOptimizationService().getCategorizedProducts());
  unawaited(OptimizedHomepageService().getProducts());
  unawaited(BackgroundPrefetchService().smartPrefetch());

  // Initialize auth service
  unawaited(AuthService.init().catchError((e) {
    debugPrint('Background auth initialization error: $e');
  }));
}

// Start background services
Future<void> _startBackgroundServices() async {
  try {
    debugPrint('🚀 Main: Starting background services...');

    // Start void-returning services first
    BackgroundOrderChecker.startPeriodicChecking();
    HealthTipsService.startBackgroundService();
    BackgroundCartSyncService.startBackgroundSync();
    BackgroundOrderTrackingService.startBackgroundTracking();
    BackgroundStoreDataService.startBackgroundPreloading();
    BackgroundInventoryMonitorService.startBackgroundMonitoring();

    // Start async services in parallel
    await Future.wait([
      OrderNotificationService.initializeNotifications(),
      NativeNotificationService.initialize(),
    ]);

    debugPrint('🚀 Main: All background services started successfully');
  } catch (e) {
    debugPrint('❌ Main: Error starting background services: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _isFirstLaunch;
  bool _isLoggedIn = false;
  String? _pendingNotificationPayload;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Run initialization checks in parallel for faster startup
    _initializeAppState();
  }

  // Initialize app state in parallel
  Future<void> _initializeAppState() async {
    debugPrint('🚀 Main: Starting app state initialization...');
    final startTime = DateTime.now();

    // Run critical checks first (blocking)
    await _checkFirstLaunch();

    // Run non-critical checks in parallel (non-blocking)
    unawaited(_checkAuthStatus());
    unawaited(_handleNotificationPayload());

    final initTime = DateTime.now().difference(startTime);
    debugPrint(
        '🚀 Main: App state initialized in ${initTime.inMilliseconds}ms');
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLaunch = !(prefs.getBool('hasLaunchedBefore') ?? false);
    });
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  /// Handle notification payload when app is opened from notification
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
      // Get the stored prescription data
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

      // Clear the pending prescription flag
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

    // Return empty data if no pending prescription
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
    if (_isFirstLaunch == null) {
      // Still loading - show branded loading screen
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ECL Logo
                Image(
                  image: AssetImage('assets/images/png.png'),
                  width: 150,
                  height: 150,
                ),
                SizedBox(height: 30),
                // Loading indicator with progress
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 4,
                  ),
                ),
                SizedBox(height: 20),
                // Loading text
                Text(
                  'Loading ECL App...',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please wait while we prepare your experience',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return AuthState(
            isLoggedIn: _isLoggedIn,
            refreshAuthState: _refreshAuthState,
            child: MaterialApp(
              title: 'ECL App',
              debugShowCheckedModeBanner: false,
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
              home: _isFirstLaunch == true
                  ? OnboardingSplashPage(
                      onFinish: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hasLaunchedBefore', true);
                        setState(() {
                          _isFirstLaunch = false;
                        });
                      },
                    )
                  : const HomePage(),
              routes: {
                '/profile': (context) => Profile(),
                '/prescription-upload': (context) =>
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getPrescriptionData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasData && snapshot.data != null) {
                          debugPrint(
                              '🔍 Main: Route handler - Creating PrescriptionUploadPage');
                          debugPrint(
                              '🔍 Main: Token: ${snapshot.data!['token']}');
                          debugPrint(
                              '🔍 Main: Item: ${snapshot.data!['item']}');

                          return PrescriptionUploadPage(
                            token: snapshot.data!['token'] ?? '',
                            item: snapshot.data!['item'],
                          );
                        }

                        // Fallback to HomePage if no data
                        return const HomePage();
                      },
                    ),
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
      // Check for notifications when app is resumed
      _handlePendingNotification();
      _checkForNotificationPayload();
    } else if (state == AppLifecycleState.detached) {
      // App is being killed, clear the restart flag
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

      // Use a post-frame callback to ensure the app is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('📱 Main: Processing notification payload: $payload');

          // Handle the notification payload
          NotificationHandlerService.handleNotificationPayload(
            context,
            payload,
          );

          // Clear all pending payloads
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

    // Try to get AuthProvider first
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
      // AuthProvider not available, fall back to AuthState
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
