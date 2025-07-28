// pages/app_back_button.dart
// pages/app_back_button.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'homepage.dart';

class AppBackButton extends StatelessWidget {
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool showConfirmation;
  final String? confirmationTitle;
  final String? confirmationMessage;
  final Widget fallbackPage;

  const AppBackButton({
    super.key,
    this.backgroundColor = const Color(0xFF43A047), // green[600]
    this.iconColor = Colors.white,
    this.onPressed,
    this.showConfirmation = false,
    this.confirmationTitle,
    this.confirmationMessage,
    this.fallbackPage = const HomePage(),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        splashColor: iconColor.withOpacity(0.2),
        onTap: onPressed ?? () => _handleBackNavigation(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      if (showConfirmation) {
        _showBackToHomeDialog(context);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => fallbackPage),
          (route) => false,
        );
      }
    }
  }

  void _showBackToHomeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              confirmationTitle ?? 'Go to Home',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          confirmationMessage ?? 'Would you like to go back to the home page?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => fallbackPage),
                (route) => false,
              );
            },
            child: Text(
              'Go Home',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Utility class for creating different types of back buttons
class BackButtonUtils {
  // Standard back button with confirmation
  static AppBackButton withConfirmation({
    Color? backgroundColor,
    Color? iconColor,
    String? title,
    String? message,
    Widget fallbackPage = const HomePage(),
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.2),
      iconColor: iconColor ?? Colors.white,
      showConfirmation: true,
      confirmationTitle: title,
      confirmationMessage: message,
      fallbackPage: fallbackPage,
    );
  }

  // Simple back button without confirmation
  static AppBackButton simple({
    Color? backgroundColor,
    Color? iconColor,
    Widget fallbackPage = const HomePage(),
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.2),
      iconColor: iconColor ?? Colors.white,
      showConfirmation: false,
      fallbackPage: fallbackPage,
    );
  }

  // Custom back button with specific onPressed
  static AppBackButton custom({
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.2),
      iconColor: iconColor ?? Colors.white,
      onPressed: onPressed,
    );
  }
}
