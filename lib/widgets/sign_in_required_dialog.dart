import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../utils/app_theme_colors.dart';

/// Branded dialog when a signed-in user is required to continue.
class SignInRequiredDialog extends StatelessWidget {
  const SignInRequiredDialog({
    super.key,
    this.feature,
    this.message,
    this.returnTo,
  });

  final String? feature;
  final String? message;
  final String? returnTo;

  static Future<bool?> show(
    BuildContext context, {
    String? feature,
    String? message,
    String? returnTo,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => SignInRequiredDialog(
        feature: feature,
        message: message,
        returnTo: returnTo,
      ),
    );
  }

  static Future<bool?> showAndNavigate(
    BuildContext context, {
    String? feature,
    String? message,
    String? returnTo,
    bool barrierDismissible = true,
  }) async {
    final signIn = await show(
      context,
      feature: feature,
      message: message,
      returnTo: returnTo,
      barrierDismissible: barrierDismissible,
    );
    if (signIn == true && context.mounted) {
      await Navigator.pushNamed(
        context,
        AppRoutes.signIn,
        arguments: returnTo != null ? {'returnTo': returnTo} : null,
      );
    }
    return signIn;
  }

  String _resolveMessage() {
    if (message != null && message!.trim().isNotEmpty) {
      return message!.trim();
    }
    if (feature != null && feature!.trim().isNotEmpty) {
      return 'Sign in to access ${feature!.trim()} and keep your orders, '
          'wishlist, and saved details in sync.';
    }
    return 'Sign in to upload prescriptions, manage appointments, track orders, '
        'and save products to your wishlist.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appColors;
    final isDark = theme.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryLight,
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.primaryDark.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primaryDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resolveMessage(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        height: 1.5,
                        color: theme.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white : AppColors.primaryDark,
                          side: BorderSide(
                            color: AppColors.primary.withValues(
                              alpha: isDark ? 0.35 : 0.28,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Not now',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
