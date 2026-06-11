import 'package:eclapp/widgets/safe_typeahead_host.dart';
import 'package:eclapp/widgets/typeahead_box_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../utils/app_theme_colors.dart';

/// Typeahead wrapper used on surfaces that navigate away while the keyboard
/// may still be animating (home search, item detail header, etc.).
class SafeTypeAheadField<T> extends StatefulWidget {
  const SafeTypeAheadField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSuggestionSelected,
    this.emptyBuilder,
    this.hideOnEmpty = true,
    this.hideOnLoading = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    required this.boxStyle,
    this.suggestionsController,
    this.hintText = 'Search medicines, products...',
    this.textStyle,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIconBuilder,
    this.borderRadius = 30,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12),
    this.fillColor,
    this.focusNode,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final TextEditingController controller;
  final void Function(String) onSubmitted;
  final Future<List<T>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) itemBuilder;
  final void Function(T) onSuggestionSelected;
  final Widget Function(BuildContext)? emptyBuilder;
  final bool hideOnEmpty;
  final bool hideOnLoading;
  final Duration debounceDuration;
  final TypeAheadBoxStyle boxStyle;
  final SuggestionsController<T>? suggestionsController;
  final String hintText;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Widget? prefixIcon;
  final Widget? Function(TextEditingController controller)? suffixIconBuilder;
  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final Color? fillColor;
  final FocusNode? focusNode;
  final Color? borderColor;
  final double borderWidth;

  @override
  State<SafeTypeAheadField<T>> createState() => _SafeTypeAheadFieldState<T>();
}

class _SafeTypeAheadFieldState<T> extends State<SafeTypeAheadField<T>> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !mounted) return const SizedBox.shrink();

    return SafeTypeAheadHost<T>(
      suggestionsController: widget.suggestionsController,
      focusNode: widget.focusNode,
      builder: (context, suggestionsController) {
        if (_isDisposed || !mounted) return const SizedBox.shrink();

        try {
          final theme = context.appColors;
          final radius = BorderRadius.circular(widget.borderRadius);
          final outlineBorder = widget.borderColor == null
              ? OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none)
              : OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: widget.borderColor!,
                    width: widget.borderWidth,
                  ),
                );
          final focusedBorder = widget.borderColor == null
              ? outlineBorder
              : OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: widget.borderColor!,
                    width: widget.borderWidth + 0.5,
                  ),
                );
          return TypeAheadField<T>(
            controller: widget.controller,
            focusNode: widget.focusNode,
            suggestionsController: suggestionsController,
            offset: widget.boxStyle.offset,
            constraints: widget.boxStyle.constraints,
            decorationBuilder: widget.boxStyle.decorationBuilder,
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: widget.textStyle ??
                    TextStyle(color: theme.inputText, fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: widget.hintStyle ??
                      TextStyle(color: theme.inputHint, fontSize: 15),
                  prefixIcon: widget.prefixIcon ??
                      Icon(Icons.search, color: theme.inputHint),
                  filled: true,
                  fillColor: widget.fillColor ?? theme.fieldBg,
                  suffixIcon:
                      widget.suffixIconBuilder?.call(widget.controller),
                  border: outlineBorder,
                  enabledBorder: outlineBorder,
                  focusedBorder: focusedBorder,
                  contentPadding: widget.contentPadding,
                ),
                onSubmitted: (value) {
                  if (mounted && !_isDisposed) widget.onSubmitted(value);
                },
              );
            },
            suggestionsCallback: (pattern) async {
              if (pattern.isEmpty || !mounted || _isDisposed) return [];
              try {
                return await widget.suggestionsCallback(pattern);
              } catch (_) {
                return [];
              }
            },
            itemBuilder: (context, suggestion) {
              if (!mounted || _isDisposed) return const SizedBox.shrink();
              return widget.itemBuilder(context, suggestion);
            },
            onSelected: (suggestion) {
              if (mounted && !_isDisposed) {
                widget.onSuggestionSelected(suggestion);
              }
            },
            emptyBuilder: widget.emptyBuilder,
            hideOnEmpty: widget.hideOnEmpty,
            hideOnLoading: widget.hideOnLoading,
            debounceDuration: widget.debounceDuration,
          );
        } catch (e, st) {
          debugPrint('SafeTypeAheadField build error: $e\n$st');
          return const SizedBox.shrink();
        }
      },
    );
  }
}
