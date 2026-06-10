import 'package:flutter/material.dart';

/// Styling for a typeahead suggestions panel (v6 `decorationBuilder`).
class TypeAheadBoxStyle {
  const TypeAheadBoxStyle({
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.elevation = 8,
    this.shadowColor,
    this.constraints,
    this.verticalOffset = 0,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double elevation;
  final Color? shadowColor;
  final BoxConstraints? constraints;
  final double verticalOffset;

  Offset get offset => Offset(0, verticalOffset);

  Widget decorationBuilder(BuildContext context, Widget child) {
    final panel = Material(
      type: MaterialType.card,
      elevation: elevation,
      shadowColor: shadowColor ?? Colors.black.withValues(alpha: 0.12),
      borderRadius: borderRadius,
      color: color,
      child: child,
    );

    if (constraints == null) return panel;
    return ConstrainedBox(constraints: constraints!, child: panel);
  }
}
