// widgets/search_bar_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback? onClear;
  final String hintText;
  final bool showClearButton;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onClear,
    this.hintText = 'Search products...',
    this.showClearButton = true,
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _hasFocus = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = widget.controller.text.isNotEmpty;
    });
  }

  void _handleSearch(String value) {
    if (value.trim().isNotEmpty) {
      widget.onSearch(value.trim());
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: _handleSearch,
          onChanged: (value) {
            if (value.isEmpty) {
              widget.onClear?.call();
            }
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _hasFocus || _hasText
                  ? Colors.green.shade700
                  : Colors.grey.shade500,
              size: 24,
            ),
            suffixIcon: _hasText && widget.showClearButton
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                    tooltip: 'Clear search',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.green.shade700,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
