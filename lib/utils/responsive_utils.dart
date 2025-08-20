// utils/responsive_utils.dart
import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints for different device types
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Check device type
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  // Get responsive dimensions
  static double getResponsiveValue(
    BuildContext context, {
    required double mobile,
    required double tablet,
    double? desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop ?? tablet;
  }

  // Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  // Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
    }
  }

  // Get responsive font sizes
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    double? desktop,
  }) {
    return getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Get responsive spacing
  static double getResponsiveSpacing(BuildContext context) {
    if (isMobile(context)) return 8.0;
    if (isTablet(context)) return 16.0;
    return 24.0;
  }

  // Get grid columns for different screen sizes
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  // Get card dimensions for different screen sizes
  static Map<String, double> getCardDimensions(BuildContext context) {
    if (isMobile(context)) {
      return {
        'width': 160.0,
        'height': 200.0,
        'imageHeight': 120.0,
        'fontSize': 12.0,
        'padding': 8.0,
      };
    } else if (isTablet(context)) {
      return {
        'width': 200.0,
        'height': 250.0,
        'imageHeight': 150.0,
        'fontSize': 14.0,
        'padding': 12.0,
      };
    } else {
      return {
        'width': 240.0,
        'height': 300.0,
        'imageHeight': 180.0,
        'fontSize': 16.0,
        'padding': 16.0,
      };
    }
  }

  // Get app bar height for different screen sizes
  static double getAppBarHeight(BuildContext context) {
    if (isMobile(context)) return 60.0;
    if (isTablet(context)) return 80.0;
    return 100.0;
  }

  // Get bottom navigation height for different screen sizes
  static double getBottomNavHeight(BuildContext context) {
    if (isMobile(context)) return 70.0;
    if (isTablet(context)) return 85.0;
    return 100.0;
  }
}
