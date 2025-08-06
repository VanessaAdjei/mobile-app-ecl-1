// widgets/error_display.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorDisplay extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const ErrorDisplay({
    super.key,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon,
    this.showRetry = false,
    this.onRetry,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isFullScreen) {
      return Scaffold(
        body: _buildErrorContent(context, theme),
      );
    }

    return _buildErrorContent(context, theme);
  }

  Widget _buildErrorContent(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.error_outline,
                size: 40,
                color: Colors.red.shade600,
              ),
            ),

            const SizedBox(height: 24),

            // Error Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Error Message
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Action Buttons
            if (showRetry || onAction != null)
              Column(
                children: [
                  if (showRetry && onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (showRetry && onRetry != null && onAction != null)
                    const SizedBox(height: 12),
                  if (onAction != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onAction,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(actionText ?? 'Action'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Network Error Widget
class NetworkErrorDisplay extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const NetworkErrorDisplay({
    super.key,
    this.onRetry,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'No Internet Connection',
      message:
          'Please check your internet connection and try again. Make sure you have a stable connection to continue.',
      icon: Icons.wifi_off,
      showRetry: true,
      onRetry: onRetry,
      isFullScreen: isFullScreen,
    );
  }
}

// Server Error Widget
class ServerErrorDisplay extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const ServerErrorDisplay({
    super.key,
    this.onRetry,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'Server Error',
      message:
          'Something went wrong on our end. Our team has been notified and is working to fix the issue. Please try again later.',
      icon: Icons.cloud_off,
      showRetry: true,
      onRetry: onRetry,
      isFullScreen: isFullScreen,
    );
  }
}

// Empty State Widget
class EmptyStateDisplay extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;
  final bool isFullScreen;

  const EmptyStateDisplay({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionText,
    this.onAction,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty State Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (onAction != null) ...[
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(actionText ?? 'Get Started'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isFullScreen) {
      return Scaffold(body: content);
    }

    return content;
  }
}

// Loading Error Widget
class LoadingErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const LoadingErrorDisplay({
    super.key,
    this.message = 'Failed to load content',
    this.onRetry,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'Loading Failed',
      message: message,
      icon: Icons.download_done,
      showRetry: true,
      onRetry: onRetry,
      isFullScreen: isFullScreen,
    );
  }
}

// Permission Error Widget
class PermissionErrorDisplay extends StatelessWidget {
  final String permission;
  final VoidCallback? onGrantPermission;
  final bool isFullScreen;

  const PermissionErrorDisplay({
    super.key,
    required this.permission,
    this.onGrantPermission,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'Permission Required',
      message:
          'This app needs $permission permission to function properly. Please grant the permission in your device settings.',
      icon: Icons.security,
      actionText: 'Grant Permission',
      onAction: onGrantPermission,
      isFullScreen: isFullScreen,
    );
  }
}

// Optimized SnackBar utilities for faster appearance and disappearance
class SnackBarUtils {
  // Success SnackBar - appears quickly and disappears after 1.5 seconds
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.green.shade600,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500), // Reduced from 3 seconds
        animation: const SnackBarAnimation(), // Custom fast animation
      ),
    );
  }

  // Error SnackBar - appears quickly and disappears after 2 seconds
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.red.shade600,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000), // Reduced from 3 seconds
        animation: const SnackBarAnimation(), // Custom fast animation
      ),
    );
  }

  // Info SnackBar - appears quickly and disappears after 1.5 seconds
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.blue.shade600,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
        animation: const SnackBarAnimation(),
      ),
    );
  }

  // Warning SnackBar - appears quickly and disappears after 2 seconds
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.orange.shade600,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
        animation: const SnackBarAnimation(),
      ),
    );
  }
}

// Custom fast animation for SnackBars
class SnackBarAnimation extends Animation<double> {
  const SnackBarAnimation();

  @override
  void addListener(VoidCallback listener) {
    // No-op implementation
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    // No-op implementation
  }

  @override
  void removeListener(VoidCallback listener) {
    // No-op implementation
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    // No-op implementation
  }

  @override
  void dispose() {
    // No-op implementation
  }

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  double get value => 1.0;
}
