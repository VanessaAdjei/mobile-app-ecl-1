// utils/responsive_utils.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints for different device types
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Design baseline width (iPhone 14 / common Flutter reference).
  static const double designWidth = 390;

  /// When true, the app root centers content with [appContentMaxWidth] (tablets, desktop, web).
  /// Uses [shortestSide] so phone landscape is not treated as a tablet.
  static bool useAppContentFrame(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 600) return false;
    if (size.width < 600) return false;
    return true;
  }

  /// Max width for the main app column on large screens.
  static double appContentMaxWidth(double width) {
    if (width < 600) return width;
    if (width < 900) return math.min(720, width * 0.92);
    if (width < 1200) return math.min(900, width * 0.88);
    return 1000;
  }

  /// Horizontal padding that scales with window width (for manual use in pages).
  static double pageHorizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 8;
    if (w < 600) return 12;
    if (w < 900) return 16;
    return 20;
  }

  /// Scales a dimension (e.g. font, icon) using width vs a design baseline.
  static double widthScale(
    BuildContext context, {
    double baselineWidth = designWidth,
    double minScale = 0.88,
    double maxScale = 1.12,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    return (w / baselineWidth).clamp(minScale, maxScale);
  }

  /// Converts a design-pixel value (baseline [designWidth]) to this screen.
  static double scaled(BuildContext context, double designPixels) =>
      designPixels * widthScale(context);

  /// Product grids — column count from available width.
  static SliverGridDelegate productGridDelegate(
    BuildContext context, {
    double childAspectRatio = 0.72,
  }) {
    final gap = scaled(context, 8);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: getGridColumns(context),
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      childAspectRatio: childAspectRatio,
    );
  }

  /// Wraps a route/page so it respects [appContentMaxWidth] when the app frame is not used
  /// (e.g. modal or nested navigator). Use sparingly; prefer the global [appFrame] wrapper.
  static Widget boundedContent(
    BuildContext context, {
    required Widget child,
  }) {
    if (!useAppContentFrame(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: appContentMaxWidth(MediaQuery.sizeOf(context).width),
        ),
        child: child,
      ),
    );
  }

  /// Scales [ThemeData] text and common control sizes for the current screen.
  static ThemeData responsiveTheme(ThemeData base, BuildContext context) {
    final factor = widthScale(context);
    if ((factor - 1.0).abs() < 0.01) return base;

    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: factor),
      primaryTextTheme: base.primaryTextTheme.apply(fontSizeFactor: factor),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          fontSize: (base.appBarTheme.titleTextStyle?.fontSize ?? 20) * factor,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
          fontSize: (base.inputDecorationTheme.hintStyle?.fontSize ?? 15) *
              factor,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: scaled(context, 14),
          horizontal: scaled(context, 12),
        ),
      ),
    );
  }

  /// Wraps [child] with a screen-scaled [Theme].
  static Widget applyResponsiveTheme(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final scaledTheme = responsiveTheme(theme, context);
    if (identical(theme, scaledTheme)) return child;
    return Theme(data: scaledTheme, child: child);
  }

  /// Root [MaterialApp.builder] — screen-relative MediaQuery + tablet column.
  static Widget appFrame(BuildContext context, Widget? child) {
    final c = child ?? const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    final fullSize = mq.size;
    final widthFactor = widthScale(context);
    final useFrame = useAppContentFrame(context);
    final contentWidth =
        useFrame ? appContentMaxWidth(fullSize.width) : fullSize.width;

    final userTextScale = mq.textScaler.scale(1);
    final scaledMq = mq.copyWith(
      size: Size(contentWidth, fullSize.height),
      textScaler: TextScaler.linear(widthFactor * userTextScale),
    );

    Widget content = MediaQuery(data: scaledMq, child: c);

    if (!useFrame) return content;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: contentWidth,
            height: fullSize.height,
            child: content,
          ),
          const Spacer(),
        ],
      ),
    );
  }

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
