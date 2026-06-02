// pages/app_back_button.dart
// custom back button widget
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
        splashColor: iconColor.withValues(alpha: 0.2),
        onTap: onPressed ?? () => _handleBackNavigation(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
    BackButtonUtils.popOrGoHome(
      context,
      showConfirmation: showConfirmation,
      title: confirmationTitle,
      message: confirmationMessage,
      fallbackPage: fallbackPage,
    );
  }
}

void _showBackToHomeDialog(
  BuildContext context, {
  String? title,
  String? message,
  Widget fallbackPage = const HomePage(),
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
              color: Theme.of(dialogContext)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.home,
              color: Theme.of(dialogContext).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? 'Go to Home',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message ?? 'Would you like to go back to the home page?',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Theme.of(dialogContext)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => fallbackPage),
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

// utility class for making different types of back buttons
class BackButtonUtils {
  // standard back button with confirmation
  static AppBackButton withConfirmation({
    Color? backgroundColor,
    Color? iconColor,
    String? title,
    String? message,
    Widget fallbackPage = const HomePage(),
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      iconColor: iconColor ?? Colors.white,
      showConfirmation: true,
      confirmationTitle: title,
      confirmationMessage: message,
      fallbackPage: fallbackPage,
    );
  }

  // simple back button without confirmation
  static AppBackButton simple({
    Color? backgroundColor,
    Color? iconColor,
    Widget fallbackPage = const HomePage(),
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      iconColor: iconColor ?? Colors.white,
      showConfirmation: false,
      fallbackPage: fallbackPage,
    );
  }

  // custom back button with specific onPressed
  static AppBackButton custom({
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return AppBackButton(
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      iconColor: iconColor ?? Colors.white,
      onPressed: onPressed,
    );
  }

  /// Pop to the previous route when possible; otherwise go home.
  static void popOrGoHome(
    BuildContext context, {
    bool showConfirmation = false,
    String? title,
    String? message,
    Widget fallbackPage = const HomePage(),
  }) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (showConfirmation) {
      _showBackToHomeDialog(
        context,
        title: title,
        message: message,
        fallbackPage: fallbackPage,
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => fallbackPage),
      (route) => false,
    );
  }

  /// Default app back control: pop stack, confirm before home when at root.
  static AppBackButton standard({
    Color? backgroundColor,
    Color? iconColor,
    String? title,
    String? message,
    Widget fallbackPage = const HomePage(),
  }) =>
      withConfirmation(
        backgroundColor: backgroundColor,
        iconColor: iconColor,
        title: title,
        message: message,
        fallbackPage: fallbackPage,
      );
}
