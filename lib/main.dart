// main.dart
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/authprovider.dart';
import 'package:eclapp/pages/categories.dart';
import 'package:eclapp/pages/createaccount.dart';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/cart.dart';
import 'package:eclapp/pages/ProductModel.dart';
import 'package:eclapp/pages/upload_prescription.dart';
import 'package:eclapp/pages/aboutus.dart';
import 'package:eclapp/pages/privacypolicy.dart';
import 'package:eclapp/pages/tandc.dart';
import 'package:provider/provider.dart';
import 'pages/cartprovider.dart';
import 'pages/theme_provider.dart';
import 'services/app_optimization_service.dart';
import 'services/optimized_api_service.dart';
import 'services/banner_cache_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/onboarding_splash_page.dart';
import 'services/homepage_optimization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.clearAllGuestIds(); // Clear all guest IDs on app start
  final prefs = await SharedPreferences.getInstance();
  print('guest_id after clear: \'${prefs.getString('guest_id')}\'');

  // If not previously running, clear guest_id
  final wasRunning = prefs.getBool('was_running') ?? false;
  if (!wasRunning) {
    await prefs.remove('guest_id');
    await prefs.setBool('was_running', true);
  }
  final tutorialShown = prefs.getBool('tutorial_shown') ?? false;
  // Force onboarding to show for testing
  await prefs.setBool('hasLaunchedBefore', false);

  final isFirstLaunch = !(prefs.getBool('hasLaunchedBefore') ?? false);

  // Configure image cache for better performance
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // Initialize optimization service
  await AppOptimizationService().initialize();

  // Initialize optimized API service
  await OptimizedApiService().initialize();

  // Initialize banner cache service
  await BannerCacheService().initialize();

  // Prefetch banners on app start
  BannerCacheService().getBanners();
  // Prefetch products on app start
  HomepageOptimizationService().getProducts();
  // Prefetch categorized products on app start
  HomepageOptimizationService().getCategorizedProducts();
  // Prefetch popular products on app start (as early as possible)
  print('Prefetching popular products as soon as app opens...');
  HomepageOptimizationService().getPopularProducts();

  AuthService.init().catchError((e) {
    print('Background auth initialization error: $e');
  });

  // Print guest id for testing
  await AuthService.getToken();

  runApp(MyApp(tutorialShown: tutorialShown));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.tutorialShown = false});

  final bool tutorialShown;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool? _isFirstLaunch;

  // Global function to refresh auth state
  static void Function()? _refreshAuthStateCallback;

  static void setRefreshAuthStateCallback(void Function() callback) {
    _refreshAuthStateCallback = callback;
  }

  static void refreshAuthState() {
    _refreshAuthStateCallback?.call();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstLaunch();
    _MyAppState.setRefreshAuthStateCallback(_refreshAuthState);
    // Prefetch banners on app start or hot restart
    BannerCacheService().getBanners();
    // Prefetch products on app start or hot restart
    HomepageOptimizationService().getProducts();
    // Prefetch popular products on app start or hot restart
    HomepageOptimizationService().getPopularProducts();
    // Prefetch categorized products on app start or hot restart
    HomepageOptimizationService().getCategorizedProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        AppOptimizationService().onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        AppOptimizationService().onAppForegrounded();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }

    final prefs = await SharedPreferences.getInstance();
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      // App is being killed or backgrounded, reset the flag
      await prefs.setBool('was_running', false);
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = !(prefs.getBool('hasLaunchedBefore') ?? false);
    if (mounted) {
      setState(() {
        _isFirstLaunch = isFirst;
      });
    }
  }

  Future<void> _initializeAuthState() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('Auth check timeout, defaulting to not logged in');
          return false;
        },
      );
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing auth state: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _refreshAuthState() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      print('Error refreshing auth state: $e');
    }
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
            // Initialize the auth provider
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
              debugShowCheckedModeBanner: false,
              title: 'ECL App',
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
                ).copyWith(background: Color(0xFFF8F9FA)),
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
                ).copyWith(background: Colors.grey.shade900),
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
                  : HomePage(),
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
