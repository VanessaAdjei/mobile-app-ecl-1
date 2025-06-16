// pages/aboutus.dart
import 'package:flutter/material.dart';
import 'Cart.dart';
import 'HomePage.dart';
import 'AppBackButton.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.green.shade700,
        elevation: theme.appBarTheme.elevation ?? 0,
        centerTitle: theme.appBarTheme.centerTitle ?? true,
        leading: AppBackButton(
          backgroundColor: theme.primaryColor,
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            }
          },
        ),
        title: Text(
          'About Us',
          style: theme.appBarTheme.titleTextStyle ??
              TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Cart(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Animate(
          effects: [
            FadeEffect(duration: 400.ms),
            SlideEffect(
                duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0)),
          ],
          child: Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.primaryColor, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Who We Are',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Ernest Chemists Limited is a leading pharmaceutical company in Ghana, dedicated to providing quality healthcare products and services. With decades of experience, we are committed to improving lives through innovation, integrity, and excellence. Our mission is to make healthcare accessible and affordable for all.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Our Values',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Customer Focus\n• Quality Assurance\n• Innovation\n• Integrity\n• Teamwork',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
