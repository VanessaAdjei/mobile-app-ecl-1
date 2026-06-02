// pages/splashscreen.dart
import 'package:flutter/material.dart';
import 'package:eclapp/pages/homepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return child;
            },
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF20AF67),
              const Color(0xFF20AF67).withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/png.png',
            height: 200,
            width: 200,
          ),
        ),
      ),
    );
  }
}
