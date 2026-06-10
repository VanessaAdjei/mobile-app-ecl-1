import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

/// Unmounts [TypeAheadField] on route deactivation and drops keyboard focus so
/// metrics callbacks cannot run against a torn-down element tree.
class SafeTypeAheadHost<T> extends StatefulWidget {
  const SafeTypeAheadHost({
    super.key,
    required this.builder,
    this.suggestionsController,
    this.focusNode,
  });

  final Widget Function(
    BuildContext context,
    SuggestionsController<T> suggestionsController,
  ) builder;
  final SuggestionsController<T>? suggestionsController;
  final FocusNode? focusNode;

  @override
  State<SafeTypeAheadHost<T>> createState() => _SafeTypeAheadHostState<T>();
}

class _SafeTypeAheadHostState<T> extends State<SafeTypeAheadHost<T>> {
  late final SuggestionsController<T> _controller;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.suggestionsController ?? SuggestionsController<T>();
  }

  void _tearDownField() {
    _controller.close();
    widget.focusNode?.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void deactivate() {
    _tearDownField();
    _active = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _tearDownField();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active || !mounted) return const SizedBox.shrink();
    return widget.builder(context, _controller);
  }
}
