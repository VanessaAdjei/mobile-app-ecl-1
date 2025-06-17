// main.dart
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/categories.dart';
import 'package:eclapp/pages/createaccount.dart';
import 'package:eclapp/pages/payment_page.dart';
import 'package:eclapp/pages/profile.dart';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:eclapp/pages/splashscreen.dart';
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
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
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
                labelStyle:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
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
                    color: Colors.green.shade200, fontWeight: FontWeight.w500),
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
            initialRoute: '/',
            routes: {
              '/': (context) => SplashScreen(),
              '/home': (context) => HomePage(),
              '/cart': (context) => ProtectedRoute(child: Cart()),
              '/categories': (context) => CategoryPage(),
              '/profile': (context) => Profile(),
              '/aboutus': (context) => AboutUsScreen(),
              '/signin': (context) => SignInScreen(),
              '/signup': (context) => SignUpScreen(),
              '/upload-prescription': (context) => UploadPrescriptionPage(
                    product:
                        ModalRoute.of(context)!.settings.arguments as Product,
                  ),
              '/privacypolicy': (context) => PrivacyPolicyScreen(),
              '/termsandconditions': (context) => TermsAndConditionsScreen(),
              '/settings': (context) => Profile(),
              '/payment': (context) => PaymentPage(),
              '/profile_settings': (context) => Profile(),
            },
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
