import 'package:flutter/material.dart';

import 'responsive_utils.dart';

/// Screen-relative sizing from a 390pt-wide design baseline.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Scales a design-pixel value to the current screen width.
  double rs(double designPixels) => ResponsiveUtils.scaled(this, designPixels);

  /// Alias for [rs] — spacing / width.
  double w(double designPixels) => rs(designPixels);

  /// Alias for [rs] — height (same scale as width for consistency).
  double h(double designPixels) => rs(designPixels);

  /// Alias for [rs] — font / icon size.
  double sp(double designPixels) => rs(designPixels);

  bool get isTabletLayout => ResponsiveUtils.isTablet(this);

  bool get isMobileLayout => ResponsiveUtils.isMobile(this);

  int get gridColumns => ResponsiveUtils.getGridColumns(this);
}
