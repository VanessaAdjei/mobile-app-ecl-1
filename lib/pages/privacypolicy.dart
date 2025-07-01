// pages/privacypolicy.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Cart.dart';
import 'HomePage.dart';
import 'AppBackButton.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
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
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Animate(
            effects: [
              FadeEffect(duration: 400.ms),
              SlideEffect(
                  duration: 400.ms, begin: Offset(0, 0.1), end: Offset(0, 0)),
            ],
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.privacy_tip_outlined,
                            color: theme.primaryColor, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Privacy Policy',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    Text(
                      'We value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, and disclose information about you when you use our services.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Data Collection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We collect personal information such as your name, email address, and payment details when you register with us or use our services.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Data Use',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The data we collect is used to provide you with our services, improve our offerings, and communicate with you.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Third-Party Sharing',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We do not share your personal information with third parties without your consent, except as required by law.',
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
      ),
    );
  }
}
