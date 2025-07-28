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
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.clearAllGuestIds();
  final prefs = await SharedPreferences.getInstance();
  debugPrint('guest_id after clear: \'${prefs.getString('guest_id')}\'');

  // If not previously running, clear guest_id
  final wasRunning = prefs.getBool('was_running') ?? false;
  if (!wasRunning) {
    await prefs.remove('guest_id');
    await prefs.setBool('was_running', true);
  }

  // Configure image cache for better performance
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // Initialize optimization services
  await AppOptimizationService().initialize();
  await OptimizedApiService().initialize();
  await BannerCacheService().initialize();
  await AdvancedPerformanceService().initialize();
  await OptimizedHomepageService().initialize();
  await UniversalPageOptimizationService().initialize();
  await BackgroundPrefetchService().initialize();

  // Prefetch data on app start for better performance
  unawaited(BannerCacheService().getBanners());
  unawaited(HomepageOptimizationService().getProducts());
  unawaited(HomepageOptimizationService().getCategorizedProducts());
  unawaited(HomepageOptimizationService().getPopularProducts());
  unawaited(OptimizedHomepageService().getProducts());
  unawaited(OptimizedHomepageService().getBanners());

  // Start background prefetching for better performance
  unawaited(BackgroundPrefetchService().smartPrefetch());

  AuthService.init().catchError((e) {
    debugPrint('Background auth initialization error: $e');
  });

  // Print guest id for testing
  await AuthService.getToken();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _isFirstLaunch;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    _checkAuthStatus();
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

  Future<Map<String, dynamic>> _getPrescriptionData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPendingPrescription =
        prefs.getBool('has_pending_prescription') ?? false;

    print(
        '🔍 Main: Checking for pending prescription: $hasPendingPrescription');

    if (hasPendingPrescription) {
      // Get the stored prescription data
      final productName = prefs.getString('pending_prescription_product') ?? '';
      final thumbnail = prefs.getString('pending_prescription_thumbnail') ?? '';
      final productId = prefs.getString('pending_prescription_id') ?? '';
      final price = prefs.getString('pending_prescription_price') ?? '';
      final batchNo = prefs.getString('pending_prescription_batch_no') ?? '';

      print('🔍 Main: Retrieved prescription data:');
      print('🔍 Main: Product Name: $productName');
      print('🔍 Main: Product ID: $productId');
      print('🔍 Main: Price: $price');
      print('🔍 Main: Batch No: $batchNo');

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

    print('🔍 Main: No pending prescription found, returning empty data');

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
  Widget build(BuildContext context) {
    if (_isFirstLaunch == null) {
      // Still loading
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
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
                          print(
                              '🔍 Main: Route handler - Creating PrescriptionUploadPage');
                          print('🔍 Main: Token: ${snapshot.data!['token']}');
                          print('🔍 Main: Item: ${snapshot.data!['item']}');

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
