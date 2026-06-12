import 'package:eclapp/widgets/category/subcategory_design.dart';
import 'package:flutter/material.dart';

/// Search field on the main category grid page — tuned for dark mode on [pageBg].
class CategoryPageSearchBar extends StatefulWidget {
  const CategoryPageSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.onTap,
    this.hintText = 'Search category products...',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onTap;
  final String hintText;

  @override
  State<CategoryPageSearchBar> createState() => _CategoryPageSearchBarState();
}

class _CategoryPageSearchBarState extends State<CategoryPageSearchBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant CategoryPageSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChange);
      widget.controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    final next = widget.focusNode.hasFocus;
    if (next != _focused && mounted) {
      setState(() => _focused = next);
    }
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: SubcategoryDesign.categorySearchFieldGradient(context),
          ),
          border: Border.all(
            color: SubcategoryDesign.categorySearchBorder(
              context,
              focused: _focused,
            ),
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: SubcategoryDesign.categorySearchShadow(
            context,
            focused: _focused,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: SubcategoryDesign.categorySearchIconWellBg(context),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: SubcategoryDesign.categorySearchBorder(context)
                      .withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: SubcategoryDesign.categorySearchIconColor(context),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                onTap: widget.onTap,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SubcategoryDesign.categorySearchText(context),
                  height: 1.25,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: SubcategoryDesign.categorySearchHint(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            if (hasText)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: SubcategoryDesign.categorySearchClearIcon(context),
                  size: 18,
                ),
                onPressed: widget.onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                tooltip: 'Clear search',
              ),
          ],
        ),
      ),
    );
  }
}
